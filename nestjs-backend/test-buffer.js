const BASE = 'https://admin-backend-php-production.up.railway.app';
let passed = 0, failed = 0;
function ok(name) { console.log(`✅ ${name}`); passed++; }
function fail(name, reason) { console.log(`❌ ${name}: ${reason}`); failed++; }

async function get(path) {
  const r = await fetch(`${BASE}/${path}`);
  return { status: r.status, data: await r.json().catch(() => null) };
}

async function run() {
  console.log('=== 3-Tier Buffer & Location Tests ===\n');

  // 1. Find a valid client with calendar data
  let clientId = null, calData = null;
  for (const id of [8, 9, 10, 12, 15, 25, 30]) {
    const r = await get(`api/client/calendar/${id}`);
    if (r.status === 200 && r.data?.trainers?.length > 0) {
      clientId = id;
      calData = r.data;
      break;
    }
  }
  if (!clientId) { fail('Find client', 'None found'); return; }
  ok(`Client ${clientId} found`);

  // 2. Check locations have buffer_minutes field
  console.log('\n--- Location Data ---');
  if (calData.locations && calData.locations.length > 0) {
    let allHaveBuffer = true;
    for (const loc of calData.locations) {
      const hasBuffer = typeof loc.buffer_minutes === 'number';
      console.log(`  ${loc.name}: buffer_minutes=${loc.buffer_minutes} (${hasBuffer ? 'OK' : 'MISSING'})`);
      if (!hasBuffer) allHaveBuffer = false;
    }
    if (allHaveBuffer) ok(`All ${calData.locations.length} locations have buffer_minutes`);
    else fail('Locations buffer_minutes', 'Some locations missing buffer_minutes');

    // 3. Check correct values
    const andere = calData.locations.find(l => l.name === 'Andere');
    if (andere) {
      if (andere.buffer_minutes === 60) ok('"Andere" has buffer=60');
      else fail('"Andere" buffer', `expected 60, got ${andere.buffer_minutes}`);
    }

    const sihl = calData.locations.find(l => l.name && l.name.includes('Sihlhölzli'));
    if (sihl) {
      if (sihl.buffer_minutes === 30) ok('"Sihlhölzli" has buffer=30');
      else fail('"Sihlhölzli" buffer', `expected 30, got ${sihl.buffer_minutes}`);
    }

    const allmend = calData.locations.find(l => l.name && l.name.includes('Allmend'));
    if (allmend) {
      if (allmend.buffer_minutes === 30) ok('"Allmend Brunau" has buffer=30');
      else fail('"Allmend" buffer', `expected 30, got ${allmend.buffer_minutes}`);
    }

    const rieter = calData.locations.find(l => l.name && l.name.includes('Rieterpark'));
    if (rieter) {
      if (rieter.buffer_minutes === 30) ok('"Rieterpark" has buffer=30');
      else fail('"Rieterpark" buffer', `expected 30, got ${rieter.buffer_minutes}`);
    }

    // 4. Check expected locations exist
    const expectedNames = ['Sportanlage Sihlhölzli', 'Sportanlage Allmend Brunau', 'Rieterpark', 'Andere'];
    for (const name of expectedNames) {
      const found = calData.locations.find(l => l.name === name);
      if (found) ok(`Location "${name}" exists (id=${found.id})`);
      else fail(`Location "${name}"`, 'NOT FOUND');
    }

    // 5. Old locations should be deactivated (not in active list)
    const oldNames = ['Outdoor', 'Training and Diagnostics', 'Allmend Fluntern'];
    for (const name of oldNames) {
      const found = calData.locations.find(l => l.name === name);
      if (!found) ok(`Old location "${name}" deactivated`);
      else fail(`Old location "${name}"`, 'still active');
    }
  } else {
    fail('Locations', 'No locations returned');
  }

  // 6. Check trainer_bookings have location_id
  console.log('\n--- Trainer Bookings ---');
  if (calData.trainer_bookings && calData.trainer_bookings.length > 0) {
    const withLoc = calData.trainer_bookings.filter(b => b.location_id != null);
    console.log(`  ${withLoc.length}/${calData.trainer_bookings.length} bookings have location_id`);
    ok(`Trainer bookings returned (${calData.trainer_bookings.length})`);
  } else {
    console.log('  No trainer bookings (OK if no trainings scheduled)');
  }

  // Summary
  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===`);
}

run().catch(e => { console.error('FATAL:', e); process.exit(1); });
