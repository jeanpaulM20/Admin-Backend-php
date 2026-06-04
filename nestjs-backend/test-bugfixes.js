// Verifies the two QA bug fixes at the API level. Needs only a TRAINER token:
//   node test-bugfixes.js <TRAINER_TOKEN>
//
// Bug 1: GET /api/training-plan with a trainer token and NO client_id must
//        return [] (no cross-client data leak).
// Bug 2: publish/unpublish endpoints flip a plan's status.
// Non-destructive: restores the plan's original status.

const BASE = 'https://admin-backend-php-production.up.railway.app';
const TRAINER = process.argv[2] || process.env.TRAINER_TOKEN || '';

let passed = 0, failed = 0;
const ok = (n) => { console.log(`✅ ${n}`); passed++; };
const fail = (n, r) => { console.log(`❌ ${n}: ${r}`); failed++; };

async function req(method, path, body) {
  const r = await fetch(`${BASE}/${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', 'x-auth-token': TRAINER },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: r.status, data: await r.json().catch(() => null) };
}

async function run() {
  if (!TRAINER) { console.error('Usage: node test-bugfixes.js <TRAINER_TOKEN>'); process.exitCode = 2; return; }
  console.log('=== QA Bug-Fix Verification (trainer token) ===\n');

  // — Bug 1: no client_id → must be [] —
  const all = await req('GET', 'api/training-plan');
  if (all.status === 200 && Array.isArray(all.data) && all.data.length === 0) {
    ok('Bug 1: GET /api/training-plan (no client_id) → [] (no leak)');
  } else if (all.status === 200 && Array.isArray(all.data)) {
    fail('Bug 1', `expected [], got ${all.data.length} plans (LEAK STILL PRESENT)`);
  } else {
    fail('Bug 1', `status ${all.status}`);
  }

  // — find a client with plans (scoped path works) —
  let clientId = null, plans = null;
  for (let id = 1; id <= 40; id++) {
    const r = await req('GET', `api/training-plan?client_id=${id}`);
    if (r.status === 200 && Array.isArray(r.data) && r.data.length > 0) {
      clientId = id; plans = r.data; break;
    }
  }
  if (!clientId) { fail('Find a client with plans', 'none in client_id 1..40'); return summary(); }
  ok(`Scoped path: client ${clientId} has ${plans.length} plans (status visible: ${plans[0].status})`);

  // — Bug 2: publish → status published → restore —
  const plan = plans[0];
  const original = plan.status ?? 'draft';
  const pub = await req('POST', `api/training-plan/${plan.id}/publish`);
  if (pub.status === 200 || pub.status === 201) {
    const after = await req('GET', `api/training-plan/${plan.id}`);
    if (after.data?.status === 'published') ok(`Bug 2: publish set status=published (plan #${plan.id})`);
    else fail('Bug 2 publish', `status is ${after.data?.status}`);
    if (after.data?.publishedAt) ok('Bug 2: published_at is set'); else fail('published_at', 'null');
  } else {
    fail('Bug 2 publish call', `status ${pub.status}`);
  }

  // — restore —
  if (original !== 'published') {
    const un = await req('POST', `api/training-plan/${plan.id}/unpublish`);
    const back = await req('GET', `api/training-plan/${plan.id}`);
    if (back.data?.status === 'draft') ok(`Restored plan #${plan.id} to draft (unpublish works)`);
    else fail('Restore', `status ${un.status}, now ${back.data?.status}`);
  } else {
    console.log(`   ↩️  Plan #${plan.id} was already published — left as is`);
  }

  summary();
}

function summary() {
  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===`);
  process.exitCode = failed > 0 ? 1 : 0;
}

run().catch((e) => { console.error('FATAL:', e); process.exitCode = 1; });
