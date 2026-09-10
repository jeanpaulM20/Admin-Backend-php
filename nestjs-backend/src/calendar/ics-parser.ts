/**
 * Schlanker iCalendar-Leser (RFC 5545) — nur so viel, wie für Sperrzeiten
 * nötig ist: Zeitraum je Termin, Serientermine aufgelöst, alles andere
 * verworfen.
 *
 * Bewusst ohne zusätzliches Paket: gebraucht werden DTSTART/DTEND, RRULE,
 * EXDATE und RECURRENCE-ID. Betreff, Teilnehmer und Notizen liest der Parser
 * gar nicht erst ein — was nicht gelesen wird, kann auch nicht durchsickern.
 */

/** Ein belegter Zeitraum, wie ihn der Abgleich braucht. */
export interface IcsBusy {
  uid: string;
  start: Date;
  end: Date;
  allDay: boolean;
}

/** Zeitzone, in der zeitzonenlose Angaben gelesen werden. */
const FALLBACK_TZ = 'Europe/Zurich';

/** Obergrenze je Serie — schützt vor Endlosserien ohne UNTIL/COUNT. */
const MAX_OCCURRENCES = 2000;

interface CivilDate {
  y: number; mo: number; d: number; h: number; mi: number; s: number;
  tz: string | null;   // null = UTC
  dateOnly: boolean;
}

// ── Zeitzonen ────────────────────────────────────────────────────────────────

/** Versatz einer Zone zu UTC an einem Zeitpunkt, in Millisekunden. */
function zoneOffset(instant: number, tz: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: tz, hour12: false,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  }).formatToParts(new Date(instant));
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value ?? '0');
  const asUtc = Date.UTC(get('year'), get('month') - 1, get('day'),
                         get('hour') % 24, get('minute'), get('second'));
  return asUtc - instant;
}

/**
 * Wanduhrzeit einer Zone in einen echten Zeitpunkt umrechnen.
 * Zwei Durchgänge, weil der Versatz selbst vom Ergebnis abhängt — an den
 * Umstellungstagen liegt der erste Schätzwert sonst eine Stunde daneben.
 */
function civilToInstant(c: CivilDate): Date {
  const naive = Date.UTC(c.y, c.mo - 1, c.d, c.h, c.mi, c.s);
  if (!c.tz) return new Date(naive);
  const first = zoneOffset(naive, c.tz);
  let ts = naive - first;
  const second = zoneOffset(ts, c.tz);
  if (second !== first) ts = naive - second;
  return new Date(ts);
}

/**
 * Wanduhrzeit einer Zone als echten Zeitpunkt — auch ausserhalb des Parsers
 * gebraucht, etwa um eine Buchung (Datum + Uhrzeit lokal) mit den in UTC
 * gespeicherten Fremdterminen zu vergleichen.
 */
export function wallClockToInstant(
  y: number, mo: number, d: number, h: number, mi: number,
  tz: string = FALLBACK_TZ,
): Date {
  return civilToInstant({ y, mo, d, h, mi, s: 0, tz, dateOnly: false });
}

// ── Zerlegen ─────────────────────────────────────────────────────────────────

/** Fortsetzungszeilen (Zeilenumbruch + Leerzeichen) wieder zusammenfügen. */
function unfold(text: string): string[] {
  return text
    .replace(/\r\n[ \t]/g, '')
    .replace(/\n[ \t]/g, '')
    .replace(/\r\n/g, '\n')
    .split('\n');
}

interface RawProperty {
  name: string;
  params: Record<string, string>;
  value: string;
}

function parseLine(line: string): RawProperty | null {
  const colon = line.indexOf(':');
  if (colon < 0) return null;
  const head = line.slice(0, colon);
  const value = line.slice(colon + 1).trim();
  const [name, ...paramParts] = head.split(';');
  const params: Record<string, string> = {};
  for (const part of paramParts) {
    const eq = part.indexOf('=');
    if (eq > 0) params[part.slice(0, eq).toUpperCase()] = part.slice(eq + 1).replace(/^"|"$/g, '');
  }
  return { name: name.toUpperCase(), params, value };
}

/** "20260910T170000Z", "20260910T170000" (mit TZID) oder "20260910". */
function parseDateValue(prop: RawProperty): CivilDate | null {
  const raw = prop.value.trim();
  const dateOnly = prop.params['VALUE'] === 'DATE' || /^\d{8}$/.test(raw);
  const m = raw.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/);
  if (!m) return null;
  const [, y, mo, d, h, mi, s, z] = m;
  return {
    y: +y, mo: +mo, d: +d,
    h: h ? +h : 0, mi: mi ? +mi : 0, s: s ? +s : 0,
    // Ohne TZID und ohne "Z" ist die Zeit „schwebend" — sie gilt in der Zone
    // des Betrachters, für uns also in der Studio-Zone.
    tz: z ? null : (prop.params['TZID'] ?? FALLBACK_TZ),
    dateOnly,
  };
}

/** DURATION nach RFC 5545 ("PT1H30M", "P1D") in Millisekunden. */
function parseDuration(value: string): number | null {
  const m = value.trim().match(/^P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/);
  if (!m) return null;
  const [, w, d, h, mi, s] = m.map((x) => (x ? Number(x) : 0)) as unknown as number[];
  const ms = ((w || 0) * 7 + (d || 0)) * 86_400_000
    + (h || 0) * 3_600_000 + (mi || 0) * 60_000 + (s || 0) * 1000;
  return ms > 0 ? ms : null;
}

// ── Serientermine ────────────────────────────────────────────────────────────

interface RRule {
  freq: string;
  interval: number;
  count: number | null;
  until: Date | null;
  byDay: string[];
}

function parseRRule(value: string): RRule | null {
  const parts: Record<string, string> = {};
  for (const piece of value.split(';')) {
    const eq = piece.indexOf('=');
    if (eq > 0) parts[piece.slice(0, eq).toUpperCase()] = piece.slice(eq + 1);
  }
  if (!parts['FREQ']) return null;
  let until: Date | null = null;
  if (parts['UNTIL']) {
    const civil = parseDateValue({ name: 'UNTIL', params: {}, value: parts['UNTIL'] });
    until = civil ? civilToInstant(civil) : null;
  }
  return {
    freq: parts['FREQ'].toUpperCase(),
    interval: Math.max(1, Number(parts['INTERVAL'] ?? 1) || 1),
    count: parts['COUNT'] ? Number(parts['COUNT']) : null,
    until,
    byDay: (parts['BYDAY'] ?? '').split(',').map((x) => x.trim()).filter(Boolean),
  };
}

const WEEKDAY_CODES = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];

/**
 * Serie im Zeitfenster auflösen. Gerechnet wird auf der Wanduhr der
 * Ursprungszone: 17:00 bleibt 17:00, auch über die Zeitumstellung hinweg.
 */
function expand(start: CivilDate, rule: RRule, windowEnd: Date): CivilDate[] {
  const out: CivilDate[] = [];
  const stepDays = (base: CivilDate, days: number): CivilDate => {
    const shifted = new Date(Date.UTC(base.y, base.mo - 1, base.d + days));
    return {
      ...base,
      y: shifted.getUTCFullYear(), mo: shifted.getUTCMonth() + 1, d: shifted.getUTCDate(),
    };
  };

  const wanted = rule.byDay
    .map((code) => WEEKDAY_CODES.indexOf(code.slice(-2)))
    .filter((i) => i >= 0);

  let cursor: CivilDate = { ...start };
  let guard = 0;

  while (out.length < (rule.count ?? MAX_OCCURRENCES) && guard++ < MAX_OCCURRENCES * 2) {
    let candidates: CivilDate[] = [cursor];

    if (rule.freq === 'WEEKLY' && wanted.length) {
      // Wochentage der laufenden Woche, ab Montag gerechnet.
      const weekday = new Date(Date.UTC(cursor.y, cursor.mo - 1, cursor.d)).getUTCDay();
      candidates = wanted.map((target) => stepDays(cursor, (target - weekday + 7) % 7));
    }

    for (const candidate of candidates.sort(
      (a, b) => Date.UTC(a.y, a.mo - 1, a.d) - Date.UTC(b.y, b.mo - 1, b.d),
    )) {
      const instant = civilToInstant(candidate);
      if (instant < civilToInstant(start)) continue;
      if (rule.until && instant > rule.until) return out;
      if (instant > windowEnd) return out;
      out.push(candidate);
      if (rule.count && out.length >= rule.count) return out;
    }

    switch (rule.freq) {
      case 'DAILY':   cursor = stepDays(cursor, rule.interval); break;
      case 'WEEKLY':  cursor = stepDays(cursor, 7 * rule.interval); break;
      case 'MONTHLY': cursor = { ...cursor, mo: cursor.mo + rule.interval }; break;
      case 'YEARLY':  cursor = { ...cursor, y: cursor.y + rule.interval }; break;
      default: return out;   // unbekannte Frequenz: nur der Ersttermin
    }
    // Monats-/Jahresschritte können über den Jahreswechsel laufen.
    if (cursor.mo > 12) {
      cursor = { ...cursor, y: cursor.y + Math.floor((cursor.mo - 1) / 12), mo: ((cursor.mo - 1) % 12) + 1 };
    }
    if (civilToInstant(cursor) > windowEnd) return out;
  }
  return out;
}

// ── Öffentliche Schnittstelle ────────────────────────────────────────────────

/**
 * Liest belegte Zeiträume aus einem ICS-Text, aufgelöst und auf das
 * Zeitfenster [from, to] beschnitten.
 */
export function parseIcsBusy(text: string, from: Date, to: Date): IcsBusy[] {
  const lines = unfold(text);
  const result: IcsBusy[] = [];
  /** Einzeln geänderte Termine einer Serie — verdrängen ihre Ursprungszeit. */
  const overrides = new Set<string>();
  const events: RawProperty[][] = [];

  let current: RawProperty[] | null = null;
  for (const line of lines) {
    if (line.startsWith('BEGIN:VEVENT')) { current = []; continue; }
    if (line.startsWith('END:VEVENT')) { if (current) events.push(current); current = null; continue; }
    if (!current) continue;
    const prop = parseLine(line);
    if (prop) current.push(prop);
  }

  // Erster Durchgang: geänderte Einzeltermine merken.
  for (const event of events) {
    const uid = event.find((p) => p.name === 'UID')?.value ?? '';
    const recurrenceId = event.find((p) => p.name === 'RECURRENCE-ID');
    if (uid && recurrenceId) {
      const civil = parseDateValue(recurrenceId);
      if (civil) overrides.add(`${uid}@${civilToInstant(civil).getTime()}`);
    }
  }

  for (const event of events) {
    const get = (name: string) => event.find((p) => p.name === name);

    // Abgesagte Termine und ausdrücklich als „frei" markierte Zeiten
    // belegen nichts.
    if (get('STATUS')?.value.toUpperCase() === 'CANCELLED') continue;
    if (get('TRANSP')?.value.toUpperCase() === 'TRANSPARENT') continue;

    const dtstart = get('DTSTART');
    if (!dtstart) continue;
    const start = parseDateValue(dtstart);
    if (!start) continue;

    const uid = get('UID')?.value ?? `${dtstart.value}-${result.length}`;
    const startInstant = civilToInstant(start);

    // Dauer aus DTEND oder DURATION; ohne beides: ganztägig 24 h, sonst 1 h.
    let lengthMs: number;
    const dtend = get('DTEND');
    const duration = get('DURATION');
    if (dtend) {
      const end = parseDateValue(dtend);
      lengthMs = end ? civilToInstant(end).getTime() - startInstant.getTime() : 3_600_000;
    } else if (duration) {
      lengthMs = parseDuration(duration.value) ?? 3_600_000;
    } else {
      lengthMs = start.dateOnly ? 86_400_000 : 3_600_000;
    }
    if (lengthMs <= 0) lengthMs = start.dateOnly ? 86_400_000 : 3_600_000;

    const excluded = new Set<number>();
    for (const prop of event.filter((p) => p.name === 'EXDATE')) {
      for (const piece of prop.value.split(',')) {
        const civil = parseDateValue({ ...prop, value: piece });
        if (civil) excluded.add(civilToInstant(civil).getTime());
      }
    }

    const rruleProp = get('RRULE');
    const rule = rruleProp ? parseRRule(rruleProp.value) : null;
    const occurrences = rule ? expand(start, rule, to) : [start];

    for (const occurrence of occurrences) {
      const occStart = civilToInstant(occurrence);
      const key = occStart.getTime();
      if (excluded.has(key)) continue;
      // Ein geänderter Einzeltermin steht als eigener VEVENT im Feed; die
      // ursprüngliche Zeit darf dann nicht zusätzlich blockieren.
      if (!get('RECURRENCE-ID') && overrides.has(`${uid}@${key}`)) continue;

      const occEnd = new Date(key + lengthMs);
      if (occEnd <= from || occStart >= to) continue;

      result.push({ uid, start: occStart, end: occEnd, allDay: start.dateOnly });
    }
  }

  return result.sort((a, b) => a.start.getTime() - b.start.getTime());
}
