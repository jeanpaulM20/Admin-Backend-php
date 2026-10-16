import { formatHms, parseIsoDurationSeconds } from '../domain/iso-duration';
import { decodeState, encodeState, signedPlatform } from '../domain/oauth-state';
import { isExpired, memberId } from '../domain/polar-connection';
import { elevationGain, sportLabel, startUtcMs, toWorkoutDraft } from '../domain/workout-mapping';

describe('ISO-Dauer', () => {
  it.each([
    ['PT2H44M', 9840],
    ['PT210.026S', 210.026],
    ['PT1H2M3S', 3723],
    ['P1DT1H', 90000],
    ['PT0S', 0],
  ])('%s → %s s', (text, secs) => expect(parseIsoDurationSeconds(text)).toBeCloseTo(secs));

  it.each(['', 'P', 'PT', '2H', 'PT1X', null, 42])('ungültig: %p', (v) =>
    expect(parseIsoDurationSeconds(v)).toBeNull());

  it('formatiert HH:MM:SS', () => {
    expect(formatHms(3723)).toBe('01:02:03');
    expect(formatHms(59.6)).toBe('00:01:00');
  });
});

describe('OAuth-state', () => {
  const key = Buffer.alloc(32, 7);
  const now = 1_700_000_000_000;
  const payload = { clientId: 42, platform: 'ios' as const, expiresAt: now + 60_000, nonce: 'abc' };

  it('Rundreise mit gültiger Signatur', () => {
    expect(decodeState(encodeState(payload, key), key, now)).toEqual(payload);
  });

  it('lehnt anderen Schlüssel ab', () => {
    expect(decodeState(encodeState(payload, key), Buffer.alloc(32, 8), now)).toBeNull();
  });

  it('lehnt manipulierte Client-ID ab', () => {
    const [, sig] = encodeState(payload, key).split('.');
    const forged = Buffer.from(JSON.stringify({ c: 1, p: 'ios', e: now + 60_000, n: 'abc' })).toString('base64url');
    expect(decodeState(`${forged}.${sig}`, key, now)).toBeNull();
  });

  it('lehnt abgelaufenen state ab', () => {
    expect(decodeState(encodeState(payload, key), key, now + 61_000)).toBeNull();
  });

  it('Plattform auch aus abgelaufenem, echt signiertem state', () => {
    expect(signedPlatform(encodeState(payload, key), key)).toBe('ios');
    expect(signedPlatform(encodeState(payload, key), Buffer.alloc(32, 8))).toBeNull();
    expect(signedPlatform('gefälscht', key)).toBeNull();
  });

  it.each([undefined, '', 'x', 'a.b.c'])('lehnt Unsinn ab: %p', (s) =>
    expect(decodeState(s, key, now)).toBeNull());
});

describe('Verbindung', () => {
  const now = new Date('2026-10-15T12:00:00Z');
  it('ohne Ablauf nie abgelaufen', () => expect(isExpired({ expiresAt: null }, now)).toBe(false));
  it('kurz vor Ablauf schon abgelaufen', () =>
    expect(isExpired({ expiresAt: new Date('2026-10-15T12:03:00Z') }, now)).toBe(true));
  it('weit vor Ablauf gültig', () =>
    expect(isExpired({ expiresAt: new Date('2027-10-15T12:00:00Z') }, now)).toBe(false));
  it('member-id enthält Client und Polar-User', () => expect(memberId(7, '9911')).toBe('sihl-7-9911'));
});

describe('Polar-Training → Training', () => {
  it('Startzeit: lokale Zeit minus Offset = UTC', () => {
    expect(new Date(startUtcMs({ start_time: '2026-10-14T08:00:00', start_time_utc_offset: 120 })!).toISOString())
      .toBe('2026-10-14T06:00:00.000Z');
    expect(startUtcMs({ start_time: 'gestern' })).toBeNull();
  });

  it('Sportart wie in der App benannt', () => {
    expect(sportLabel({ sport: 'RUNNING' })).toBe('Joggen');
    expect(sportLabel({ sport: 'CYCLING', detailed_sport_info: 'MOUNTAIN_BIKING' })).toBe('Mountainbike');
    expect(sportLabel({ sport: 'OTHER_INDOOR' })).toBe('Other indoor');
    expect(sportLabel({})).toBe('Training');
  });

  it('Höhengewinn mit Hysterese', () => {
    expect(elevationGain([100, 101, 100, 101, 100])).toBe(0);
    expect(elevationGain([100, 105, 103, 110, null, 108])).toBe(12); // 5 + 7 — kleiner Zwischenabstieg zählt mit
    expect(elevationGain([])).toBeNull();
  });

  it('übernimmt Zusammenfassung, HF-Serie und Route', () => {
    const draft = toWorkoutDraft({
      id: 'ABC',
      start_time: '2026-10-14T08:00:00',
      start_time_utc_offset: 120,
      duration: 'PT45M30S',
      calories: 512.4,
      distance: 7012.6,
      heart_rate: { average: 148, maximum: 171 },
      sport: 'RUNNING',
      samples: [
        { 'sample-type': '0', 'recording-rate': 5, data: '120,,0,130,300,140' },
        { 'sample-type': '3', 'recording-rate': 10, data: '400,405,410' },
      ],
      route: [
        { latitude: 47.36, longitude: 8.53, time: 'PT0S' },
        { latitude: 47.361, longitude: 8.531, time: 'PT10S' },
        { latitude: 0, longitude: 0, time: 'PT20S' },
        { latitude: 47.362, longitude: 8.532 },
      ],
    })!;

    expect(draft).toMatchObject({
      date: '2026-10-14 06:00:00',
      trainingType: 'Joggen',
      duration: '00:45:30',
      heartRate: 148,
      kcal: 512,
      distanceMeters: 7013,
      elevationGain: 10,
    });
    // Leere/ungültige Werte fallen raus, die Zeitachse bleibt (5-s-Raster)
    expect(draft.hrSeries).toEqual([
      { t: '2026-10-14T06:00:00Z', v: 120 },
      { t: '2026-10-14T06:00:15Z', v: 130 },
      { t: '2026-10-14T06:00:25Z', v: 140 },
    ]);
    expect(draft.gpsTrack).toEqual([
      { t: '2026-10-14T06:00:00Z', lat: 47.36, lon: 8.53, ele: 400, acc: null },
      { t: '2026-10-14T06:00:10Z', lat: 47.361, lon: 8.531, ele: 405, acc: null },
    ]);
  });

  it('ohne Samples: Durchschnittspuls aus der Zusammenfassung, leere Serien', () => {
    const draft = toWorkoutDraft({ id: 'X', start_time: '2026-10-14T08:00:00', heart_rate: { average: 99 } })!;
    expect(draft).toMatchObject({ heartRate: 99, duration: null, kcal: null, hrSeries: [], gpsTrack: [] });
  });

  it('ohne Startzeit nicht übernehmbar', () => {
    expect(toWorkoutDraft({ id: 'X', duration: 'PT1H' })).toBeNull();
  });
});
