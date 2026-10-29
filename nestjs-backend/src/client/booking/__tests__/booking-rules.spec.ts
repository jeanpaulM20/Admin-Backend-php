import {
  isIsoDay, parseClock, matchingWindow, bufferBetween, trainerConflict,
  overlaps, toLocalSegments, formatClock,
} from '../domain/booking-rules';

const TZ = 'Europe/Zurich';

describe('isIsoDay', () => {
  it('akzeptiert echte Tage', () => {
    expect(isIsoDay('2026-10-29')).toBe(true);
    expect(isIsoDay('2028-02-29')).toBe(true);
  });
  it('lehnt kaputte Daten ab', () => {
    for (const v of ['2026-13-01', '2026-02-30', '2026-1-5', '29.10.2026', '', null, 20261029]) {
      expect(isIsoDay(v)).toBe(false);
    }
  });
});

describe('parseClock', () => {
  it('liest HH:mm und HH:mm:ss', () => {
    expect(parseClock('09:30')).toBe(570);
    expect(parseClock('18:00:00')).toBe(1080);
  });
  it('lehnt ungültige Zeiten ab', () => {
    for (const v of ['24:00', '10:60', '10', 'abc', '', undefined]) expect(parseClock(v)).toBeNull();
  });
});

describe('matchingWindow', () => {
  const w = [{ from: '08:00:00', to: '12:00:00', locationId: 2, trainingTypeId: 1 }];
  it('ohne Verfügbarkeit ist nichts buchbar', () => {
    expect(matchingWindow([], 600, 660, 2)).toBeNull();
  });
  it('Buchung muss ganz ins Fenster passen', () => {
    expect(matchingWindow(w, 480, 540, 2)).toBe(w[0]);
    expect(matchingWindow(w, 660, 720, 2)).toBe(w[0]);
    expect(matchingWindow(w, 690, 750, 2)).toBeNull();
    expect(matchingWindow(w, 450, 510, 2)).toBeNull();
  });
  it('Fenster mit Standort passt nur zu diesem Standort', () => {
    expect(matchingWindow(w, 600, 660, 7)).toBeNull();
    expect(matchingWindow([{ ...w[0], locationId: null }], 600, 660, 7)).not.toBeNull();
  });
});

describe('Puffer und Trainer-Konflikte', () => {
  const buffers = new Map([[2, 30], [3, 60], [7, 30]]);
  it('gleicher Standort 0, anderer der grössere Puffer', () => {
    expect(bufferBetween(2, 2, buffers)).toBe(0);
    expect(bufferBetween(2, 7, buffers)).toBe(30);
    expect(bufferBetween(2, 3, buffers)).toBe(60);
    expect(bufferBetween(null, null, buffers)).toBe(30);
  });
  it('direkt anschliessend am gleichen Ort ist frei, an anderem Ort nicht', () => {
    const existing = [{ start: 600, end: 660, locationId: 2 }];
    expect(trainerConflict({ start: 660, end: 720, locationId: 2 }, existing, buffers)).toBeNull();
    expect(trainerConflict({ start: 660, end: 720, locationId: 7 }, existing, buffers)?.buffer).toBe(30);
    expect(trainerConflict({ start: 690, end: 750, locationId: 7 }, existing, buffers)).toBeNull();
  });
  it('overlaps ohne Puffer', () => {
    expect(overlaps({ start: 600, end: 660 }, { start: 659, end: 700 })).toBe(true);
    expect(overlaps({ start: 600, end: 660 }, { start: 660, end: 700 })).toBe(false);
  });
});

describe('toLocalSegments', () => {
  it('rechnet UTC in Zürcher Ortszeit um (Winterzeit)', () => {
    expect(toLocalSegments(new Date('2026-11-05T09:00:00Z'), new Date('2026-11-05T10:30:00Z'), TZ))
      .toEqual([{ date: '2026-11-05', startMin: 600, endMin: 690 }]);
  });
  it('rechnet UTC in Zürcher Ortszeit um (Sommerzeit)', () => {
    expect(toLocalSegments(new Date('2026-07-01T08:00:00Z'), new Date('2026-07-01T09:00:00Z'), TZ))
      .toEqual([{ date: '2026-07-01', startMin: 600, endMin: 660 }]);
  });
  it('teilt mehrtägige Termine pro Tag', () => {
    expect(toLocalSegments(new Date('2026-11-05T21:00:00Z'), new Date('2026-11-07T07:00:00Z'), TZ)).toEqual([
      { date: '2026-11-05', startMin: 1320, endMin: 1440 },
      { date: '2026-11-06', startMin: 0, endMin: 1440 },
      { date: '2026-11-07', startMin: 0, endMin: 480 },
    ]);
  });
  it('ganztägig (lokale Mitternacht bis Mitternacht) ergibt einen Tag', () => {
    expect(toLocalSegments(new Date('2026-11-04T23:00:00Z'), new Date('2026-11-05T23:00:00Z'), TZ))
      .toEqual([{ date: '2026-11-05', startMin: 0, endMin: 1440 }]);
  });
  it('leerer oder verkehrter Zeitraum ergibt nichts', () => {
    const t = new Date('2026-11-05T09:00:00Z');
    expect(toLocalSegments(t, t, TZ)).toEqual([]);
  });
  it('formatClock', () => expect(formatClock(545)).toBe('09:05'));
});
