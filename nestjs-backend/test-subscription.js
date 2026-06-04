// Read-only smoke test for Phase 1 (online-coaching subscription packages).
// Run AFTER deploy: node test-subscription.js
//
// NOTE: deliberately does NOT execute a purchase — that would create a real
// invoice, send an email, and insert a coaching_subscription row. Verify the
// purchase flow manually in staging or via an authenticated client token.

const BASE = 'https://admin-backend-php-production.up.railway.app';
let passed = 0, failed = 0;

function ok(name) { console.log(`✅ ${name}`); passed++; }
function fail(name, reason) { console.log(`❌ ${name}: ${reason}`); failed++; }

async function get(path) {
  const r = await fetch(`${BASE}/${path}`);
  return { status: r.status, data: await r.json().catch(() => null) };
}

async function run() {
  console.log('=== Online Coaching Subscription — Package Seeding Tests ===\n');

  // 1. Coaching tier list
  const coaching = await get('api/client/packages?kind=coaching');
  if (coaching.status !== 200 || !Array.isArray(coaching.data)) {
    fail('GET packages?kind=coaching', `status ${coaching.status}`);
    return summary();
  }
  ok(`GET packages?kind=coaching (${coaching.data.length} tiers)`);

  const monat = coaching.data.find((p) => p.durationMonths === 1);
  const jahr = coaching.data.find((p) => p.durationMonths === 12);

  // 2. Monthly tier — CHF 180 / 4 credits
  if (monat && monat.price === 180 && monat.credits === 4 && monat.kind === 'coaching') {
    ok('Monat: CHF 180 / 4 credits / kind=coaching');
  } else {
    fail('Monat tier', JSON.stringify(monat));
  }

  // 3. Yearly tier — CHF 1680 / 52 credits
  if (jahr && jahr.price === 1680 && jahr.credits === 52 && jahr.kind === 'coaching') {
    ok('Jahr: CHF 1680 / 52 credits / kind=coaching');
  } else {
    fail('Jahr tier', JSON.stringify(jahr));
  }

  // 4. Default packages list must NOT include coaching tiers (preserves credits screen)
  const credits = await get('api/client/packages');
  if (credits.status === 200 && Array.isArray(credits.data)) {
    const leaked = credits.data.filter((p) => p.kind === 'coaching');
    if (leaked.length === 0) ok('Default /packages excludes coaching tiers');
    else fail('Default /packages leak', `${leaked.length} coaching tiers leaked`);
  } else {
    fail('GET packages (default)', `status ${credits.status}`);
  }

  summary();
}

function summary() {
  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===`);
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((e) => { console.error('FATAL:', e); process.exit(1); });
