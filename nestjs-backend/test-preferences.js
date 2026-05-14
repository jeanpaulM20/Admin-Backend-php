const BASE = 'https://admin-backend-php-production.up.railway.app';
let passed = 0, failed = 0;
function ok(name) { console.log(`✅ ${name}`); passed++; }
function fail(name, reason) { console.log(`❌ ${name}: ${reason}`); failed++; }

async function get(path) {
  const r = await fetch(`${BASE}/${path}`);
  return { status: r.status, data: await r.json().catch(() => null) };
}
async function put(path, body) {
  const r = await fetch(`${BASE}/${path}`, {
    method: 'PUT', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: r.status, data: await r.json().catch(() => null) };
}

async function run() {
  console.log('=== Preference API Tests ===\n');

  const clientId = 8;

  // 1. GET preferences (should return empty/null values initially)
  const r1 = await get(`api/client/preferences/${clientId}`);
  if (r1.status === 200 && r1.data) {
    ok(`GET preferences (status=${r1.status})`);
    if ('trainer_id' in r1.data) ok('Response has trainer_id key');
    else fail('trainer_id key', 'missing');
    if ('training_type_id' in r1.data) ok('Response has training_type_id key');
    else fail('training_type_id key', 'missing');
    if ('location_id' in r1.data) ok('Response has location_id key');
    else fail('location_id key', 'missing');
  } else {
    fail('GET preferences', `status=${r1.status}`);
  }

  // 2. PUT preferences (set trainer)
  const r2 = await put(`api/client/preferences/${clientId}`, { trainer_id: '2' });
  if (r2.status === 200 && r2.data) {
    ok('PUT trainer_id=2');
    if (r2.data.trainer_id === '2') ok('Response confirms trainer_id=2');
    else fail('PUT response trainer_id', `got ${r2.data.trainer_id}`);
  } else {
    fail('PUT preferences', `status=${r2.status}`);
  }

  // 3. GET again — should have trainer_id=2
  const r3 = await get(`api/client/preferences/${clientId}`);
  if (r3.data?.trainer_id === '2') ok('GET after PUT: trainer_id=2 persisted');
  else fail('Persistence', `expected trainer_id=2, got ${r3.data?.trainer_id}`);

  // 4. PUT multiple values
  const r4 = await put(`api/client/preferences/${clientId}`, {
    training_type_id: '5',
    location_id: '3',
  });
  if (r4.status === 200) ok('PUT multiple preferences');
  else fail('PUT multiple', `status=${r4.status}`);

  // 5. GET all — should have all 3 values
  const r5 = await get(`api/client/preferences/${clientId}`);
  if (r5.data?.trainer_id === '2' && r5.data?.training_type_id === '5' && r5.data?.location_id === '3') {
    ok('All 3 preferences persisted correctly');
  } else {
    fail('All persisted', JSON.stringify(r5.data));
  }

  // 6. PUT null to clear a value
  const r6 = await put(`api/client/preferences/${clientId}`, { trainer_id: null });
  if (r6.status === 200) ok('PUT null to clear trainer_id');
  else fail('PUT null', `status=${r6.status}`);

  const r7 = await get(`api/client/preferences/${clientId}`);
  if (r7.data?.trainer_id === null || r7.data?.trainer_id === undefined) {
    ok('trainer_id cleared (null)');
  } else {
    fail('trainer_id cleared', `got ${r7.data?.trainer_id}`);
  }

  // Verify other values still intact
  if (r7.data?.training_type_id === '5' && r7.data?.location_id === '3') {
    ok('Other preferences unaffected by partial clear');
  } else {
    fail('Other prefs intact', JSON.stringify(r7.data));
  }

  // 7. Clean up — clear all
  await put(`api/client/preferences/${clientId}`, {
    trainer_id: null,
    training_type_id: null,
    location_id: null,
  });

  // Summary
  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===`);
}

run().catch(e => { console.error('FATAL:', e); process.exit(1); });
