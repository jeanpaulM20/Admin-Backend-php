/**
 * Buchungsregeln der Kunden-App — reine Fachlogik ohne Datenbank, Framework
 * oder Konfiguration. Zeiten sind Minuten seit Mitternacht (Zürcher Ortszeit),
 * Daten "YYYY-MM-DD".
 */

/** Ein Training dauert immer 60 Minuten. */
export const SLOT_MINUTES = 60;
/** Buchen und kostenlos absagen bis spätestens 12 Stunden vorher. */
export const MIN_ADVANCE_HOURS = 12;
/** Puffer, wenn ein Standort keinen eigenen Wert hat. */
export const DEFAULT_BUFFER_MINUTES = 30;

/** "YYYY-MM-DD" und ein Tag, den es im Kalender gibt. */
export function isIsoDay(value: unknown): value is string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [y, m, d] = value.split('-').map(Number);
  const t = new Date(Date.UTC(y, m - 1, d));
  return t.getUTCFullYear() === y && t.getUTCMonth() === m - 1 && t.getUTCDate() === d;
}

/** "HH:mm" oder "HH:mm:ss" → Minuten seit Mitternacht; sonst null. */
export function parseClock(value: unknown): number | null {
  if (typeof value !== 'string') return null;
  const m = /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/.exec(value.trim());
  if (!m) return null;
  const h = Number(m[1]);
  const mi = Number(m[2]);
  if (h > 23 || mi > 59) return null;
  return h * 60 + mi;
}

export interface AvailabilityWindow {
  from: string;
  to: string;
  locationId: number | null;
  trainingTypeId: number | null;
}

/**
 * Verfügbarkeitsfenster, in das die Buchung ganz hineinpasst. Ohne passendes
 * Fenster (auch: gar keine Verfügbarkeit an dem Tag) ist nicht buchbar. Ein
 * Fenster mit Standort passt nur zu diesem Standort.
 */
export function matchingWindow(
  windows: AvailabilityWindow[],
  start: number,
  end: number,
  locationId: number | null,
): AvailabilityWindow | null {
  for (const w of windows) {
    const from = parseClock(w.from);
    const to = parseClock(w.to);
    if (from == null || to == null) continue;
    if (start < from || end > to) continue;
    if (w.locationId != null && locationId != null && w.locationId !== locationId) continue;
    return w;
  }
  return null;
}

export interface ExistingBooking {
  start: number;
  end: number;
  locationId: number | null;
}

/** Puffer zwischen zwei Terminen: gleicher Standort 0, sonst der grössere Standort-Puffer. */
export function bufferBetween(
  a: number | null,
  b: number | null,
  buffers: ReadonlyMap<number, number>,
): number {
  if (a != null && b != null && a === b) return 0;
  const bufA = a != null ? buffers.get(a) ?? DEFAULT_BUFFER_MINUTES : DEFAULT_BUFFER_MINUTES;
  const bufB = b != null ? buffers.get(b) ?? DEFAULT_BUFFER_MINUTES : DEFAULT_BUFFER_MINUTES;
  return Math.max(bufA, bufB);
}

/** Erster Termin des Trainers, der mit Puffer kollidiert, samt Puffer; sonst null. */
export function trainerConflict(
  request: ExistingBooking,
  existing: ExistingBooking[],
  buffers: ReadonlyMap<number, number>,
): { booking: ExistingBooking; buffer: number } | null {
  for (const b of existing) {
    const buffer = bufferBetween(request.locationId, b.locationId, buffers);
    if (request.start < b.end + buffer && b.start < request.end + buffer) {
      return { booking: b, buffer };
    }
  }
  return null;
}

/** Überschneidung zweier Zeiträume ohne Puffer. */
export function overlaps(a: { start: number; end: number }, b: { start: number; end: number }): boolean {
  return a.start < b.end && b.start < a.end;
}

export interface LocalSegment {
  date: string;
  startMin: number;
  endMin: number;
}

/**
 * Zerlegt einen belegten Zeitraum (echte Zeitpunkte) in Tagesstücke in der
 * Ortszeit `tz` — so lässt er sich wie eine Buchung (Datum + Uhrzeit) zeigen.
 * Ein Stück, das bis Mitternacht reicht, endet bei 1440.
 */
export function toLocalSegments(startsAt: Date, endsAt: Date, tz: string): LocalSegment[] {
  if (!(endsAt.getTime() > startsAt.getTime())) return [];
  const s = wallClock(startsAt, tz);
  const e = wallClock(endsAt, tz);
  const segments: LocalSegment[] = [];
  let day = Date.UTC(s.y, s.mo - 1, s.d);
  const lastDay = Date.UTC(e.y, e.mo - 1, e.d);
  for (; day <= lastDay; day += 86_400_000) {
    const startMin = day === Date.UTC(s.y, s.mo - 1, s.d) ? s.min : 0;
    const endMin = day === lastDay ? e.min : 1440;
    if (endMin > startMin) segments.push({ date: new Date(day).toISOString().slice(0, 10), startMin, endMin });
  }
  return segments;
}

function wallClock(at: Date, tz: string): { y: number; mo: number; d: number; min: number } {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(at);
  const p = (type: string) => Number(parts.find((x) => x.type === type)?.value);
  return { y: p('year'), mo: p('month'), d: p('day'), min: p('hour') * 60 + p('minute') };
}

/** "HH:mm" aus Minuten seit Mitternacht. */
export function formatClock(min: number): string {
  return `${String(Math.floor(min / 60)).padStart(2, '0')}:${String(min % 60).padStart(2, '0')}`;
}
