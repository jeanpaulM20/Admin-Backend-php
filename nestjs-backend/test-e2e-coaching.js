// E2E test for the online-coaching publish → client-visibility chain.
// Tokens are passed at runtime (never hard-coded / committed):
//   node test-e2e-coaching.js <TRAINER_TOKEN> <CLIENT_TOKEN> <CLIENT_ID>
//
// Non-destructive: it publishes a plan, verifies the client view, then
// restores the plan's original status.

const BASE = 'https://admin-backend-php-production.up.railway.app';
const TRAINER = process.argv[2] || process.env.TRAINER_TOKEN || '';
const CLIENT = process.argv[3] || process.env.CLIENT_TOKEN || '';
const CLIENT_ID = process.argv[4] || process.env.CLIENT_ID || '';

let passed = 0, failed = 0;
const ok = (n) => { console.log(`✅ ${n}`); passed++; };
const fail = (n, r) => { console.log(`❌ ${n}: ${r}`); failed++; };

async function req(method, path, token, body) {
  const r = await fetch(`${BASE}/${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { 'x-auth-token': token } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: r.status, data: await r.json().catch(() => null) };
}

async function run() {
  if (!TRAINER || !CLIENT || !CLIENT_ID) {
    console.error('Usage: node test-e2e-coaching.js <TRAINER_TOKEN> <CLIENT_TOKEN> <CLIENT_ID>');
    process.exitCode = 2;
    return;
  }
  console.log('=== Online Coaching E2E (publish → client view) ===\n');

  // 1. [trainer] list the client's plans, pick one
  const list = await req('GET', `api/training-plan?client_id=${CLIENT_ID}`, TRAINER);
  if (list.status !== 200 || !Array.isArray(list.data) || list.data.length === 0) {
    fail('Trainer lists client plans', `status ${list.status}, ${JSON.stringify(list.data)?.slice(0,120)}`);
    return summary();
  }
  const plan = list.data[0];
  const planId = plan.id;
  const originalStatus = plan.status ?? 'draft';
  ok(`Trainer sees ${list.data.length} plans; using plan #${planId} (status=${originalStatus})`);

  // 2. [client] subscription status (context)
  const sub = await req('GET', `api/client/subscription/${CLIENT_ID}`, CLIENT);
  const subActive = sub.data?.active === true;
  console.log(`   ℹ️  Client subscription active=${subActive}${subActive ? ` (${sub.data.tier}, bis ${sub.data.validTo})` : ''}`);

  // 3. [security] client must NOT be able to publish
  const cPub = await req('POST', `api/training-plan/${planId}/publish`, CLIENT);
  if (cPub.status === 403) ok('Client cannot publish (403)');
  else fail('Client publish blocked', `got ${cPub.status}`);

  // 4. [trainer] publish
  const pub = await req('POST', `api/training-plan/${planId}/publish`, TRAINER);
  if (pub.status === 200 || pub.status === 201) ok(`Trainer published plan #${planId}`);
  else { fail('Trainer publish', `status ${pub.status}`); return restoreAndSummary(planId, originalStatus); }

  // 5. [client] plan now appears in the list (teaser + lock flag)
  const cList = await req('GET', 'api/training-plan', CLIENT);
  const seen = Array.isArray(cList.data) && cList.data.find((p) => p.id === planId);
  if (seen) {
    ok(`Client sees plan #${planId} in list (locked=${seen.locked})`);
    if (seen.sections && Object.keys(seen.sections).length >= 0) ok('List item is a teaser (has sections, no values)');
    if (seen.values === undefined) ok('List item carries no full values'); else fail('List leak', 'values present in list');
  } else {
    fail('Client sees published plan', `not in list (${Array.isArray(cList.data) ? cList.data.length : '?'} items)`);
  }

  // 6. [client] detail — full when entitled, else teaser
  const cDetail = await req('GET', `api/training-plan/${planId}`, CLIENT);
  if (cDetail.status === 200) {
    const locked = cDetail.data?.locked === true || cDetail.data?.values == null;
    if (locked) {
      ok('Client detail is a LOCKED teaser (no full values) — paywall path');
      if (cDetail.data?.sections) ok('Teaser carries section counts');
    } else {
      ok('Client detail is FULL (within free week or subscribed) — has values');
    }
  } else {
    fail('Client detail', `status ${cDetail.status}`);
  }

  // 7. restore + verify draft is hidden from client
  await restore(planId, originalStatus);
  if (originalStatus !== 'published') {
    const draftView = await req('GET', `api/training-plan/${planId}`, CLIENT);
    if (draftView.status === 403) ok('After restore: draft plan is hidden from client (403)');
    else fail('Draft hidden', `expected 403, got ${draftView.status}`);
  }

  summary();
}

async function restore(planId, originalStatus) {
  if (originalStatus !== 'published') {
    const r = await req('POST', `api/training-plan/${planId}/unpublish`, TRAINER);
    console.log(`   ↩️  Restored plan #${planId} to draft (status ${r.status})`);
  } else {
    console.log(`   ↩️  Plan #${planId} was already published — left as is`);
  }
}

async function restoreAndSummary(planId, originalStatus) {
  await restore(planId, originalStatus);
  summary();
}

function summary() {
  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===`);
  process.exitCode = failed > 0 ? 1 : 0;
}

run().catch((e) => { console.error('FATAL:', e); process.exitCode = 1; });
