/**
 * Comprehensive API Test Suite
 * Tests all NestJS endpoints as the Flutter trainer & client apps would call them.
 * Run: node test-api.js
 */
const https = require('https');

const BASE = 'https://admin-backend-php-production.up.railway.app';
const TRAINER_TOKEN = 'b7ad15d9955954cece0a54ed3588c104'; // trainer id=2

let passed = 0, failed = 0, warnings = 0;

function fetch(path, token = TRAINER_TOKEN) {
  return new Promise((resolve, reject) => {
    const url = new URL(BASE + path);
    https.get({
      hostname: url.hostname,
      path: url.pathname + url.search,
      headers: { 'x-auth-token': token, 'Accept': 'application/json' },
    }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch { resolve({ status: res.statusCode, body: data }); }
      });
    }).on('error', reject);
  });
}

function assert(condition, msg) {
  if (condition) { passed++; }
  else { failed++; console.log('  ❌ FAIL: ' + msg); }
}

function warn(msg) { warnings++; console.log('  ⚠️  WARN: ' + msg); }

// ─── Test Helpers ───────────────────────────────────────
function hasKeys(obj, keys, label) {
  for (const k of keys) {
    assert(k in obj, `${label}: missing key "${k}" — got keys: ${Object.keys(obj).join(', ')}`);
  }
}

// ─── TESTS ──────────────────────────────────────────────

async function testAuth() {
  console.log('\n══ 1. AUTH ══');

  // Trainer login
  const r = await new Promise((resolve, reject) => {
    const body = JSON.stringify({ passcode: 's1hl' });
    const url = new URL(BASE + '/api/auth/login');
    const req = https.request({
      hostname: url.hostname, path: url.pathname, method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': body.length },
    }, (res) => {
      let d = ''; res.on('data', c => d += c);
      res.on('end', () => { try { resolve({ status: res.statusCode, body: JSON.parse(d) }); } catch { resolve({ status: res.statusCode, body: d }); } });
    });
    req.on('error', reject);
    req.write(body); req.end();
  });
  assert(r.status === 200 || r.status === 201, `Login status ${r.status}`);
  assert(r.body.token, 'Login returns token');
  console.log(`  ✅ Trainer login → token=${r.body.token?.substring(0, 12)}...`);

  // Unauthenticated request
  const r2 = await fetch('/api/client', '');
  assert(r2.status === 401, `Unauth returns 401, got ${r2.status}`);
  console.log(`  ✅ Unauthenticated → ${r2.status}`);
}

async function testClients() {
  console.log('\n══ 2. CLIENTS ══');
  const r = await fetch('/api/client');
  assert(r.status === 200, `GET /api/client → ${r.status}`);
  assert(Array.isArray(r.body), 'Returns array');
  assert(r.body.length > 0, `Has clients: ${r.body.length}`);
  console.log(`  ✅ ${r.body.length} clients`);

  // Check field names Flutter expects
  const c = r.body[0];
  hasKeys(c, ['id', 'firstname', 'lastname', 'email', 'picture'], 'Client');
  console.log(`  ✅ Client keys OK: id, firstname, lastname, email, picture`);

  // Single client
  const r2 = await fetch('/api/client/' + c.id);
  assert(r2.status === 200, `GET /api/client/${c.id} → ${r2.status}`);
  console.log(`  ✅ Single client ${c.id}: ${r2.body.firstname} ${r2.body.lastname}`);

  return r.body;
}

async function testTrainings(clients) {
  console.log('\n══ 3. TRAININGS ══');
  let totalTrainings = 0, clientsWithTrainings = 0, errors = 0;

  for (const c of clients) {
    const r = await fetch(`/api/training?client_id=${c.id}`);
    if (r.status !== 200) { errors++; continue; }
    if (!Array.isArray(r.body)) { errors++; continue; }
    totalTrainings += r.body.length;
    if (r.body.length > 0) clientsWithTrainings++;
  }

  assert(errors === 0, `${errors} errors`);
  console.log(`  ✅ ${clients.length} clients tested, ${errors} errors`);
  console.log(`  ✅ ${totalTrainings} trainings total, ${clientsWithTrainings} clients have trainings`);

  // Check training response format (find a client with trainings)
  for (const c of clients) {
    const r = await fetch(`/api/training?client_id=${c.id}`);
    if (r.body.length > 0) {
      const t = r.body[0];
      hasKeys(t, ['id', 'date', 'duration', 'status', 'training_type', 'type_name'], 'Training');
      assert(typeof t.training_type === 'string' || t.training_type === null,
        `training_type is string/null, got ${typeof t.training_type}: ${t.training_type}`);
      console.log(`  ✅ Training format OK — type="${t.training_type}", abbr="${t.type_abbr}"`);

      // Check exercisesets loaded
      assert('exercisesets' in t, 'Training has exercisesets');
      console.log(`  ✅ Training ${t.id} has ${t.exercisesets?.length ?? 0} exercise sets`);
      break;
    }
  }
}

async function testFiles(clients) {
  console.log('\n══ 4. FILES (Dateien) ══');

  // Trainer endpoint: GET /api/file
  const rAll = await fetch('/api/file');
  assert(rAll.status === 200, `GET /api/file → ${rAll.status}`);
  assert(Array.isArray(rAll.body), 'Returns array');
  console.log(`  ✅ Total files: ${rAll.body.length}`);

  // Check format
  if (rAll.body.length > 0) {
    const f = rAll.body[0];
    hasKeys(f, ['id', 'name', 'date', 'file', 'client_id'], 'File (trainer)');
    assert(typeof f.file === 'string' && f.file.startsWith('http'), `file URL valid: ${f.file?.substring(0, 50)}`);
    console.log(`  ✅ File format OK: id=${f.id}, name="${f.name}"`);
  }

  // Per-client test
  let totalFiles = 0, clientsWithFiles = 0, errors = 0;
  for (const c of clients) {
    const r = await fetch(`/api/file?client_id=${c.id}`);
    if (r.status !== 200) { errors++; continue; }
    totalFiles += r.body.length;
    if (r.body.length > 0) clientsWithFiles++;
  }
  assert(errors === 0, `${errors} errors in per-client file test`);
  console.log(`  ✅ Per-client: ${totalFiles} files across ${clientsWithFiles} clients, ${errors} errors`);

  // Client app endpoint: GET /api/client/files/:clientId
  const rClient = await fetch('/api/client/files/23');
  assert(rClient.status === 200, `GET /api/client/files/23 → ${rClient.status}`);
  assert(Array.isArray(rClient.body), 'Returns array');
  console.log(`  ✅ Client endpoint /api/client/files/23: ${rClient.body.length} files`);

  if (rClient.body.length > 0) {
    const f = rClient.body[0];
    hasKeys(f, ['id', 'name', 'date', 'file'], 'File (client)');
    console.log(`  ✅ Client file format OK`);
  }
}

async function testReviews(clients) {
  console.log('\n══ 5. REVIEWS ══');
  let totalReviews = 0, clientsWithReviews = 0, errors = 0;

  for (const c of clients) {
    const r = await fetch(`/api/review?client_id=${c.id}`);
    if (r.status !== 200) { errors++; continue; }
    totalReviews += r.body.length;
    if (r.body.length > 0) clientsWithReviews++;
  }
  assert(errors === 0, `${errors} errors`);
  console.log(`  ✅ ${totalReviews} reviews, ${clientsWithReviews} clients have reviews`);

  // Check format
  for (const c of clients) {
    const r = await fetch(`/api/review?client_id=${c.id}`);
    if (r.body.length > 0) {
      const rev = r.body[0];
      hasKeys(rev, ['id', 'heart_rate', 'training_type', 'training_id', 'duration', 'kcal'], 'Review');
      console.log(`  ✅ Review format OK — keys: ${Object.keys(rev).join(', ')}`);

      // Check single review with detail
      const rDetail = await fetch(`/api/review/${rev.id}`);
      assert(rDetail.status === 200, `GET /api/review/${rev.id} → ${rDetail.status}`);
      if (rDetail.body.training) {
        console.log(`  ✅ Review detail has training relation`);
      }
      break;
    }
  }
}

async function testFeedback(clients) {
  console.log('\n══ 6. FEEDBACK (Chat) ══');
  let total = 0, clientsWithFb = 0, errors = 0;

  for (const c of clients) {
    const r = await fetch(`/api/feedback?client_id=${c.id}`);
    if (r.status !== 200) { errors++; continue; }
    total += r.body.length;
    if (r.body.length > 0) clientsWithFb++;
  }
  assert(errors === 0, `${errors} errors`);
  console.log(`  ✅ ${total} feedback messages, ${clientsWithFb} clients have chat`);

  // Check format
  for (const c of clients) {
    const r = await fetch(`/api/feedback?client_id=${c.id}`);
    if (r.body.length > 0) {
      const fb = r.body[0];
      hasKeys(fb, ['id', 'client_id', 'message'], 'Feedback');
      console.log(`  ✅ Feedback format OK`);
      break;
    }
  }
}

async function testAvailability() {
  console.log('\n══ 7. AVAILABILITY ══');
  const r = await fetch('/api/trainer-availability');
  assert(r.status === 200, `GET /api/trainer-availability → ${r.status}`);
  assert(Array.isArray(r.body) && r.body.length > 0, `Has slots: ${r.body.length}`);
  console.log(`  ✅ ${r.body.length} availability slots`);

  if (r.body.length > 0) {
    const a = r.body[0];
    hasKeys(a, ['id', 'date', 'from', 'to'], 'Availability');
    // Flutter model accepts both trainerId and trainer_id
    assert('trainerId' in a || 'trainer_id' in a, 'Has trainerId or trainer_id');
    console.log(`  ✅ Slot format OK — keys: ${Object.keys(a).join(', ')}`);
  }
}

async function testLocations() {
  console.log('\n══ 8. LOCATIONS ══');
  const r = await fetch('/api/location');
  assert(r.status === 200, `GET /api/location → ${r.status}`);
  assert(Array.isArray(r.body), 'Returns array');
  console.log(`  ✅ ${r.body.length} locations`);

  if (r.body.length > 0) {
    const l = r.body[0];
    hasKeys(l, ['id', 'name'], 'Location');
    console.log(`  ✅ Locations: ${r.body.map(l => l.name).join(', ')}`);
  }
}

async function testTrainingPlans() {
  console.log('\n══ 9. TRAINING PLANS ══');
  const r = await fetch('/api/training-plan');
  assert(r.status === 200, `GET /api/training-plan → ${r.status}`);
  console.log(`  ✅ ${r.body.length} training plans`);
}

async function testMetrics(clients) {
  console.log('\n══ 10. METRICS ══');
  let total = 0, errors = 0;
  for (const c of clients) {
    const r = await fetch(`/api/metric?client_id=${c.id}`);
    if (r.status !== 200) { errors++; continue; }
    total += r.body.length;
  }
  assert(errors === 0, `${errors} errors`);
  console.log(`  ✅ ${total} metrics, ${errors} errors`);
}

async function testPerformanceTests(clients) {
  console.log('\n══ 11. PERFORMANCE TESTS ══');
  let total = 0, errors = 0;
  for (const c of clients) {
    const r = await fetch(`/api/performance_test?client_id=${c.id}`);
    if (r.status !== 200) { errors++; continue; }
    total += r.body.length;
  }
  assert(errors === 0, `${errors} errors`);
  console.log(`  ✅ ${total} performance tests, ${errors} errors`);
}

async function testAnamnese(clients) {
  console.log('\n══ 12. ANAMNESE ══');
  let okCount = 0, errors = 0;
  for (const c of clients.slice(0, 20)) {
    const r = await fetch(`/api/anamnese/${c.id}`);
    if (r.status === 200) okCount++;
    else errors++;
  }
  assert(errors === 0, `${errors} errors`);
  console.log(`  ✅ ${okCount}/20 clients OK, ${errors} errors`);
}

async function testExercises() {
  console.log('\n══ 13. EXERCISES ══');
  const r = await fetch('/api/exercise');
  assert(r.status === 200, `GET /api/exercise → ${r.status}`);
  console.log(`  ✅ ${Array.isArray(r.body) ? r.body.length : 'N/A'} exercises`);
}

async function testClientApp() {
  console.log('\n══ 14. CLIENT APP ENDPOINTS ══');

  // Client login
  const loginR = await new Promise((resolve, reject) => {
    const body = JSON.stringify({ email: 'test@test.com', passcode: '0000' });
    const url = new URL(BASE + '/api/client/token');
    const req = https.request({
      hostname: url.hostname, path: url.pathname, method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': body.length },
    }, (res) => {
      let d = ''; res.on('data', c => d += c);
      res.on('end', () => { try { resolve({ status: res.statusCode, body: JSON.parse(d) }); } catch { resolve({ status: res.statusCode, body: d }); } });
    });
    req.on('error', reject);
    req.write(body); req.end();
  });
  console.log(`  Client login (invalid creds) → ${loginR.status} (expected 401/400)`);
  assert(loginR.status === 401 || loginR.status === 400 || loginR.status === 404,
    `Invalid login rejected: ${loginR.status}`);

  // Client files endpoint
  const f = await fetch('/api/client/files/23');
  assert(f.status === 200, `GET /api/client/files/23 → ${f.status}`);
  console.log(`  ✅ Client files: ${f.body.length} files for client 23`);

  // Client invoices endpoint
  const inv = await fetch('/api/client/invoices/23');
  console.log(`  Client invoices → ${inv.status}`);
}

// ─── MAIN ───────────────────────────────────────────────
async function main() {
  console.log('╔══════════════════════════════════════════════╗');
  console.log('║   SIHL TRAINING API — AUTOMATED TEST SUITE  ║');
  console.log('║   ' + BASE.replace('https://', '') + '   ║');
  console.log('╚══════════════════════════════════════════════╝');
  console.log(`Timestamp: ${new Date().toISOString()}`);

  await testAuth();
  const allClients = await testClients();

  // Use all clients for thorough testing
  console.log(`\n🔄 Testing all ${allClients.length} clients across all endpoints...`);

  await testTrainings(allClients);
  await testFiles(allClients);
  await testReviews(allClients);
  await testFeedback(allClients);
  await testAvailability();
  await testLocations();
  await testTrainingPlans();
  await testMetrics(allClients);
  await testPerformanceTests(allClients);
  await testAnamnese(allClients);
  await testExercises();
  await testClientApp();

  console.log('\n╔══════════════════════════════════════════════╗');
  console.log(`║  ✅ PASSED: ${String(passed).padStart(4)}                              ║`);
  console.log(`║  ❌ FAILED: ${String(failed).padStart(4)}                              ║`);
  console.log(`║  ⚠️  WARNS:  ${String(warnings).padStart(4)}                              ║`);
  console.log('╚══════════════════════════════════════════════╝');

  if (failed > 0) process.exit(1);
}

main().catch(e => { console.error('FATAL:', e); process.exit(1); });
