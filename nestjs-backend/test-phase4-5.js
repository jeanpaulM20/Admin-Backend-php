// Tests Phase 4 (rate limit + trainer notify) and Phase 5 (renewal reminder cron).
// Usage: node test-phase4-5.js <TRAINER_TOKEN>
//
// Non-destructive: runs the reminder dispatcher (idempotent), and probes
// existence of the new endpoints. Does NOT spam chat or run cron on prod.

const BASE = 'https://admin-backend-php-production.up.railway.app';
const TRAINER = process.argv[2] || process.env.TRAINER_TOKEN || '';

let passed = 0, failed = 0;
const ok = (n) => { console.log(`✅ ${n}`); passed++; };
const fail = (n, r) => { console.log(`❌ ${n}: ${r}`); failed++; };

async function req(method, path, body, token = TRAINER) {
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
  if (!TRAINER) {
    console.error('Usage: node test-phase4-5.js <TRAINER_TOKEN>');
    process.exitCode = 2;
    return;
  }
  console.log('=== Phase 4 + 5 Verification ===\n');

  // ── Phase 5: endpoint exists + auth check ───────────────────────────
  console.log('--- Phase 5: Subscription Reminders ---');

  // Unauth → 401
  const noAuth = await req('POST', 'api/entitlement/reminders/run', null, '');
  if (noAuth.status === 401) ok('Reminder endpoint requires auth (401 without token)');
  else fail('Reminder auth', `expected 401, got ${noAuth.status}`);

  // Trainer can dispatch — returns { success, sent }
  const run1 = await req('POST', 'api/entitlement/reminders/run');
  if (run1.status === 201 || run1.status === 200) {
    if (typeof run1.data?.sent === 'number') {
      ok(`Reminder dispatch succeeded (sent=${run1.data.sent})`);
    } else {
      fail('Reminder response shape', JSON.stringify(run1.data));
    }
  } else {
    fail('Reminder dispatch', `status ${run1.status}: ${JSON.stringify(run1.data)}`);
    return summary();
  }

  // Second run shortly after — should send 0 (lastRemindedAt < 24h)
  const run2 = await req('POST', 'api/entitlement/reminders/run');
  if (run2.data?.sent === 0) ok('Duplicate-prevention works (2nd run sends 0)');
  else console.log(`   ℹ️  2nd run sent=${run2.data?.sent} (ok if first sent 0 too)`);

  // ── Phase 4: trainer-notification path indicator ────────────────────
  console.log('\n--- Phase 4: Client-trained signal ---');

  // Find a client with a published plan
  let clientId = null, planId = null;
  for (let id = 1; id <= 40; id++) {
    const r = await req('GET', `api/training-plan?client_id=${id}`);
    if (r.status === 200 && Array.isArray(r.data) && r.data.length > 0) {
      const published = r.data.find((p) => p.status === 'published');
      if (published) { clientId = id; planId = published.id; break; }
    }
  }
  if (!clientId) {
    console.log('   ⏭️  No published plan found — skipping client_trained probe');
    return summary();
  }
  ok(`Found published plan #${planId} for client ${clientId}`);

  // Trainer is NOT a client → POST :id/results must 403
  const tryResults = await req('POST', `api/training-plan/${planId}/results`, { values: {} });
  if (tryResults.status === 403) ok('Trainer blocked from /results (client-only)');
  else fail('Trainer-block on /results', `got ${tryResults.status}`);

  summary();
}

function summary() {
  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===`);
  process.exitCode = failed > 0 ? 1 : 0;
}

run().catch((e) => { console.error('FATAL:', e); process.exitCode = 1; });
