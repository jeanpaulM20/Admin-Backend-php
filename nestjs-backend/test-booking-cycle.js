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
  console.log('=== Full Booking Cycle Test ===\n');

  // Find client with trainer + availability
  let clientId = null, calData = null;
  for (const id of [8, 9, 10, 12, 15, 25, 30]) {
    const r = await get(`api/client/calendar/${id}`);
    if (r.status === 200 && r.data?.trainers?.length > 0 && r.data?.availability?.length > 0) {
      clientId = id;
      calData = r.data;
      break;
    }
  }
  if (!clientId) { fail('Find client with availability', 'None found'); return; }
  ok(`Client ${clientId}: ${calData.trainers.length} trainers, ${calData.availability.length} avail slots`);

  // Find a future availability slot (at least 2 days out for 12h rule)
  const in3days = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const in4days = new Date(Date.now() + 4 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  const in5days = new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  let slot = null;
  for (const d of [in3days, in4days, in5days]) {
    slot = calData.availability.find(a => a.date === d);
    if (slot) break;
  }

  if (!slot) {
    // Try any future availability
    const today = new Date().toISOString().slice(0, 10);
    slot = calData.availability.find(a => a.date > today);
  }

  if (!slot) { console.log('⏭️  No future availability found, skipping cycle'); return; }
  ok(`Found slot: ${slot.date} ${slot.from}-${slot.to} trainer=${slot.trainer_id}`);

  // Check credits
  const creditsBefore = calData.credits;
  console.log(`Credits before: ${creditsBefore}`);

  if (creditsBefore <= 0) {
    console.log('⏭️  No credits - cannot test booking cycle (need manual credit setup)');
    console.log('\nTo test the full cycle, add a credit pack for this client in the admin panel.');

    // Still test that booking fails without credits
    const noCreditsRes = await post(`api/client/appointment/${clientId}`, {
      trainer_id: slot.trainer_id,
      training_type_id: calData.training_types[0]?.id,
      date: slot.date,
      starttime: slot.from,
      location_id: slot.location_id || calData.locations[0]?.id,
    });
    if (noCreditsRes.status === 400 && noCreditsRes.data?.message?.includes('Credit')) {
      ok('No credits → 400 with credit message');
    } else {
      fail('No credits rejection', `${noCreditsRes.status}: ${noCreditsRes.data?.message}`);
    }
  } else {
    // Full booking cycle
    const trainerId = slot.trainer_id;
    const typeId = calData.training_types[0]?.id;
    const locId = slot.location_id || calData.locations[0]?.id;
    const bookDate = slot.date;
    const bookTime = slot.from;

    console.log(`\nBooking: ${bookDate} ${bookTime} trainer=${trainerId} type=${typeId} loc=${locId}`);

    // Book
    const bookRes = await post(`api/client/appointment/${clientId}`, {
      trainer_id: trainerId, training_type_id: typeId,
      date: bookDate, starttime: bookTime, location_id: locId,
    });

    if (bookRes.status >= 200 && bookRes.status < 300) {
      ok(`Booking created (id=${bookRes.data?.id})`);
      const apptId = bookRes.data?.id;

      // Verify duration
      if (bookRes.data?.duration === 60) ok('Duration = 60 min');
      else fail('Duration', `got ${bookRes.data?.duration}`);

      // Check credit deducted
      const calAfterBook = await get(`api/client/calendar/${clientId}`);
      if (calAfterBook.data?.credits === creditsBefore - 1) {
        ok(`Credit deducted: ${creditsBefore} → ${calAfterBook.data.credits}`);
      } else {
        fail('Credit deducted', `expected ${creditsBefore - 1}, got ${calAfterBook.data?.credits}`);
      }

      // Double booking test
      const doubleRes = await post(`api/client/appointment/${clientId}`, {
        trainer_id: trainerId, training_type_id: typeId,
        date: bookDate, starttime: bookTime, location_id: locId,
      });
      if (doubleRes.status === 400) ok('Double booking prevented (client overlap)');
      else fail('Double booking', `got ${doubleRes.status}: ${doubleRes.data?.message}`);

      // Trainer conflict test (different client same trainer same time)
      // We can't test this easily without another client, but at least the double booking proves overlap detection

      // Cancel (timely, > 12h)
      if (apptId) {
        const cancelRes = await del(`api/client/appointment/${clientId}/${apptId}`);
        if (cancelRes.status === 200 && cancelRes.data?.success) {
          ok('Cancel succeeded');

          if (cancelRes.data?.creditRefunded === true) ok('creditRefunded = true');
          else fail('creditRefunded flag', JSON.stringify(cancelRes.data));

          if (cancelRes.data?.lateCancellation === false) ok('lateCancellation = false');
          else fail('lateCancellation flag', JSON.stringify(cancelRes.data));

          // Check credit refunded
          const calAfterCancel = await get(`api/client/calendar/${clientId}`);
          if (calAfterCancel.data?.credits === creditsBefore) {
            ok(`Credit refunded: ${creditsBefore - 1} → ${calAfterCancel.data.credits}`);
          } else {
            fail('Credit refunded', `expected ${creditsBefore}, got ${calAfterCancel.data?.credits}`);
          }

          // Double cancel test
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

  // Test trainer bookings contain data
  console.log('\n--- Trainer Bookings ---');
  if (calData.trainer_bookings.length > 0) {
    const tb = calData.trainer_bookings[0];
    if (tb.trainer_id && tb.date && tb.starttime && typeof tb.duration === 'number') {
      ok(`Trainer booking structure valid (${calData.trainer_bookings.length} bookings)`);
    } else {
      fail('Trainer booking structure', JSON.stringify(tb));
    }
  } else {
    console.log('ℹ️  No trainer bookings to validate');
  }

  // Test location data
  console.log('\n--- Locations ---');
  if (calData.locations.length > 0) {
    const loc = calData.locations[0];
    if (loc.id && loc.name) ok(`Location structure valid (${calData.locations.length} locations)`);
    else fail('Location structure', JSON.stringify(loc));
  }

  // Summary
  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===`);
}

run().catch(e => { console.error('FATAL:', e); process.exit(1); });
