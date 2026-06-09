const BASE = 'https://admin-backend-php-production.up.railway.app';
let passed = 0, failed = 0;

function ok(name) { console.log(`✅ ${name}`); passed++; }
function fail(name, reason) { console.log(`❌ ${name}: ${reason}`); failed++; }

async function get(path) {
  const r = await fetch(`${BASE}/${path}`);
  return { status: r.status, data: await r.json().catch(() => null) };
}
async function post(path, body) {
  const r = await fetch(`${BASE}/${path}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: r.status, data: await r.json().catch(() => null) };
}
async function del(path) {
  const r = await fetch(`${BASE}/${path}`, { method: 'DELETE' });
  return { status: r.status, data: await r.json().catch(() => null) };
}

async function run() {
  console.log('=== Credit & Booking Architecture Tests ===\n');

  // 1. Find valid client
  let clientId = null;
  for (const id of [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) {
    const r = await get(`api/client/calendar/${id}`);
    if (r.status === 200 && r.data && r.data.trainers?.length > 0) {
      clientId = id;
      break;
    }
  }
  if (!clientId) { fail('Find client', 'No valid client found'); return; }
  ok(`Find client (id=${clientId})`);

  // 2. Calendar data structure
  const cal = await get(`api/client/calendar/${clientId}`);
  const cd = cal.data;

  if (typeof cd.credits === 'number') ok('Calendar returns credits field');
  else fail('Calendar credits field', typeof cd.credits);

  if (Array.isArray(cd.trainers) && cd.trainers.length > 0) ok(`Calendar returns trainers (${cd.trainers.length})`);
  else fail('Calendar trainers', 'empty or missing');

  if (Array.isArray(cd.training_types) && cd.training_types.length > 0) ok(`Calendar returns training_types (${cd.training_types.length})`);
  else fail('Calendar training_types', 'empty or missing');

  if (Array.isArray(cd.trainer_bookings)) ok(`Calendar returns trainer_bookings (${cd.trainer_bookings.length})`);
  else fail('Calendar trainer_bookings', 'missing');

  if (Array.isArray(cd.locations)) ok(`Calendar returns locations (${cd.locations.length})`);
  else fail('Calendar locations', 'missing');

  if (Array.isArray(cd.availability)) ok(`Calendar returns availability (${cd.availability.length})`);
  else fail('Calendar availability', 'missing');

  if (Array.isArray(cd.appointments)) ok(`Calendar returns appointments (${cd.appointments.length})`);
  else fail('Calendar appointments', 'missing');

  // 3. Credits endpoint
  const creds = await get(`api/client/credits/${clientId}`);
  if (creds.status === 200 && Array.isArray(creds.data)) ok(`Credits endpoint (${creds.data.length} packs)`);
  else fail('Credits endpoint', creds.status);

  // 3b. Verify credits calculation (non-expired, active packs only)
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  let calculatedCredits = 0;
  for (const p of creds.data) {
    if (p.expires) {
      const exp = new Date(p.expires);
      exp.setHours(23, 59, 59, 999);
      if (exp < now) continue; // expired
    }
    if (p.startdate) {
      const sd = new Date(p.startdate);
      sd.setHours(0, 0, 0, 0);
      if (sd > now) continue; // not yet active
    }
    calculatedCredits += (p.remaining ?? (p.paid - p.attended));
  }
  if (calculatedCredits === cd.credits) ok(`Credits match: calendar=${cd.credits}, calculated=${calculatedCredits}`);
  else fail(`Credits match`, `calendar=${cd.credits}, calculated=${calculatedCredits}`);

  // 3c. Each pack has correct remaining
  let packCalcOk = true;
  for (const p of creds.data) {
    if (p.remaining !== (p.paid - p.attended)) {
      packCalcOk = false;
      fail(`Pack #${p.id} remaining`, `expected ${p.paid - p.attended}, got ${p.remaining}`);
    }
  }
  if (packCalcOk) ok('All packs: remaining = paid - attended');

  // 4. Profile credits match
  const profile = await get(`api/client/profile/${clientId}`);
  if (profile.status === 200) {
    if (profile.data.credits === cd.credits) ok(`Profile credits match calendar (${profile.data.credits})`);
    else fail('Profile credits match', `profile=${profile.data.credits}, calendar=${cd.credits}`);
  } else fail('Profile endpoint', profile.status);

  // 5. Start/dashboard
  const start = await get(`api/client/start/${clientId}`);
  if (start.status === 200 && typeof start.data.credits === 'number') ok(`Start endpoint (credits=${start.data.credits})`);
  else fail('Start endpoint', start.status);

  // 6. Booking validation tests
  console.log('\n--- Booking Validation ---');
  const trainerId = cd.trainers[0]?.id;
  const typeId = cd.training_types[0]?.id;
  const locId = cd.locations[0]?.id;

  // 6a. Missing fields
  const r1 = await post(`api/client/appointment/${clientId}`, {});
  if (r1.status === 400) ok('Missing fields → 400');
  else fail('Missing fields', `got ${r1.status}`);

  // 6b. Past date
  const r2 = await post(`api/client/appointment/${clientId}`, {
    trainer_id: trainerId, training_type_id: typeId, date: '2020-01-01', starttime: '10:00',
  });
  if (r2.status === 400) ok('Past date → 400');
  else fail('Past date', `got ${r2.status}: ${JSON.stringify(r2.data)}`);

  // 6c. Less than 12h advance (try booking 2 hours from now)
  const soon = new Date(Date.now() + 2 * 60 * 60 * 1000);
  const soonDate = soon.toISOString().slice(0, 10);
  const soonTime = `${String(soon.getHours()).padStart(2, '0')}:${String(soon.getMinutes()).padStart(2, '0')}`;
  const r3 = await post(`api/client/appointment/${clientId}`, {
    trainer_id: trainerId, training_type_id: typeId,
    date: soonDate, starttime: soonTime, location_id: locId,
  });
  if (r3.status === 400 && r3.data?.message?.includes('12')) ok('< 12h advance → 400');
  else fail('< 12h advance', `got ${r3.status}: ${r3.data?.message}`);

  // 6d. Invalid time format
  const futureDate = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const r4 = await post(`api/client/appointment/${clientId}`, {
    trainer_id: trainerId, training_type_id: typeId,
    date: futureDate, starttime: 'abc',
  });
  if (r4.status === 400) ok('Invalid time format → 400');
  else fail('Invalid time format', `got ${r4.status}`);

  // 7. Full booking + cancel cycle (only if credits > 0 and availability)
  console.log('\n--- Booking Cycle ---');
  if (cd.credits <= 0) {
    console.log('⏭️  Skipping booking cycle: no credits available');
  } else {
    // Find availability 3 days from now
    const bookDay = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000);
    const bookDateStr = bookDay.toISOString().slice(0, 10);
    const avail = cd.availability.filter(a => a.date === bookDateStr);

    if (avail.length === 0) {
      console.log(`⏭️  Skipping booking cycle: no availability on ${bookDateStr}`);
    } else {
      const slot = avail[0];
      const bookTime = slot.from || '10:00';
      const bookTrainer = slot.trainer_id || trainerId;
      const bookLoc = slot.location_id || locId;

      console.log(`Booking: ${bookDateStr} ${bookTime} trainer=${bookTrainer} loc=${bookLoc}`);

      // Get credits before
      const credsBefore = await get(`api/client/credits/${clientId}`);
      const totalBefore = credsBefore.data.reduce((s, p) => {
        if (p.expires) { const e = new Date(p.expires); e.setHours(23,59,59,999); if (e < now) return s; }
        if (p.startdate) { const sd = new Date(p.startdate); sd.setHours(0,0,0,0); if (sd > now) return s; }
        return s + p.remaining;
      }, 0);

      // Book
      const bookRes = await post(`api/client/appointment/${clientId}`, {
        trainer_id: bookTrainer, training_type_id: typeId,
        date: bookDateStr, starttime: bookTime, location_id: bookLoc,
      });

      if (bookRes.status === 200 || bookRes.status === 201) {
        ok(`Booking created (id=${bookRes.data?.id})`);

        // Check duration is 60
        if (bookRes.data?.duration === 60) ok('Duration is 60 min');
        else fail('Duration', `got ${bookRes.data?.duration}`);

        // Check credit deducted
        const credsAfterBook = await get(`api/client/credits/${clientId}`);
        const totalAfterBook = credsAfterBook.data.reduce((s, p) => {
          if (p.expires) { const e = new Date(p.expires); e.setHours(23,59,59,999); if (e < now) return s; }
          if (p.startdate) { const sd = new Date(p.startdate); sd.setHours(0,0,0,0); if (sd > now) return s; }
          return s + p.remaining;
        }, 0);

        if (totalAfterBook === totalBefore - 1) ok(`Credit deducted: ${totalBefore} → ${totalAfterBook}`);
        else fail('Credit deducted', `before=${totalBefore}, after=${totalAfterBook}`);

        // Try double booking same time → should fail
        const doubleRes = await post(`api/client/appointment/${clientId}`, {
          trainer_id: bookTrainer, training_type_id: typeId,
          date: bookDateStr, starttime: bookTime, location_id: bookLoc,
        });
        if (doubleRes.status === 400) ok('Double booking prevented');
        else fail('Double booking', `got ${doubleRes.status}`);

        // Cancel (>= 12h, so credit should be refunded)
        const apptId = bookRes.data?.id;
        if (apptId) {
          const cancelRes = await del(`api/client/appointment/${clientId}/${apptId}`);
          if (cancelRes.status === 200 && cancelRes.data?.success) {
            ok('Cancel succeeded');
            if (cancelRes.data?.creditRefunded === true) ok('creditRefunded=true (timely cancel)');
            else fail('creditRefunded flag', JSON.stringify(cancelRes.data));
            if (cancelRes.data?.lateCancellation === false) ok('lateCancellation=false');
            else fail('lateCancellation flag', JSON.stringify(cancelRes.data));

            // Check credit refunded
            const credsAfterCancel = await get(`api/client/credits/${clientId}`);
            const totalAfterCancel = credsAfterCancel.data.reduce((s, p) => {
              if (p.expires) { const e = new Date(p.expires); e.setHours(23,59,59,999); if (e < now) return s; }
              if (p.startdate) { const sd = new Date(p.startdate); sd.setHours(0,0,0,0); if (sd > now) return s; }
              return s + p.remaining;
            }, 0);
            if (totalAfterCancel === totalBefore) ok(`Credit refunded: ${totalAfterBook} → ${totalAfterCancel}`);
            else fail('Credit refunded', `expected ${totalBefore}, got ${totalAfterCancel}`);

            // Try cancel again → should fail
            const cancelAgain = await del(`api/client/appointment/${clientId}/${apptId}`);
            if (cancelAgain.status === 400) ok('Double cancel prevented');
            else fail('Double cancel', `got ${cancelAgain.status}`);
          } else {
            fail('Cancel', `${cancelRes.status}: ${JSON.stringify(cancelRes.data)}`);
          }
        }
      } else {
        fail('Booking', `${bookRes.status}: ${bookRes.data?.message}`);
      }
    }
  }

  // Summary
  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===`);
  process.exit(failed > 0 ? 1 : 0);
}

run().catch(e => { console.error('FATAL:', e); process.exit(1); });
