/**
 * Reformer-Programme: was der Code entscheidet, entscheidet nicht das Modell
 * (Konzept, Abschnitt 7). Reihenfolge, Abschnitt, Federn, Fussstange,
 * Kopfstütze, Atmung und Tempo kommen aus dem Repertoire; das Modell wählt
 * nur, WELCHE Übungen zum Kunden passen — und der Rückfall ohne Modell ist
 * ein vollständiges, sinnvolles Programm.
 */
import type { ExerciseLevel } from '../../exercise/domain/exercise-vocabulary';
import type { PlanSection } from './plan-modality';

export type ReformerLevel = ExerciseLevel;
export const REFORMER_LEVELS: readonly ReformerLevel[] = ['beginner', 'intermediate', 'advanced'];

export interface ReformerSpecView {
  springs: string | null;
  springLoad: number | null;
  footbar: string | null;
  headrest: string | null;
  carriageStart: string | null;
  attachment: string | null;
  position: string | null;
  classicalOrder: number | null;
}

/** Was diese Regeln von einem Katalogeintrag brauchen. */
export interface ReformerCandidate {
  id: number;
  name: string;
  /** Englische Kennung aus dem Erfassungsblatt (name_en), falls vorhanden. */
  sourceRef: string | null;
  level: string | null;
  breathing: string | null;
  tempo: string | null;
  reformer: ReformerSpecView | null;
}

export type ReformerProgram = Record<PlanSection, ReformerCandidate[]>;

const SECTIONS: readonly PlanSection[] = ['sonsomo', 'main', 'core', 'mobility'];

// ── Level ────────────────────────────────────────────────────────────────

const LEVEL_RANK: Record<ReformerLevel, number> = { beginner: 0, intermediate: 1, advanced: 2 };

/** Übungen ohne Level (eigene Erfassung ohne Angabe) bleiben zulässig. */
export function admitsLevel(clientLevel: ReformerLevel, exerciseLevel: string | null): boolean {
  if (!exerciseLevel) return true;
  const rank = LEVEL_RANK[exerciseLevel as ReformerLevel];
  return rank === undefined ? true : rank <= LEVEL_RANK[clientLevel];
}

// ── Abschnitt ────────────────────────────────────────────────────────────

/**
 * Vier Slots, die die klassische Reihenfolge lückenlos abbilden:
 * Footwork und Hundred eröffnen, Gurte und Knee Stretch stehen am Ende der
 * Serie, Running, Pelvic Lift, Push-ups und Spagat schliessen ab. Alles
 * andere ist „Serie". Erkannt wird über den Namen (deutsch oder name_en),
 * damit eine im Studio angehängte Übung ohne Regelpflege in der Serie landet.
 */
const SLOT_RULES: { section: PlanSection; pattern: RegExp }[] = [
  { section: 'sonsomo',  pattern: /footwork|hundert|hundred/i },
  { section: 'mobility', pattern: /\blaufen\b|running|beckenheben|pelvic lift|liegest[üu]tz|push ?up|spagat|splits/i },
  { section: 'core',     pattern: /knee stretch|beinkreise|leg circles|fr[öo]sche|frogs|long spine/i },
];

export function reformerSlot(candidate: Pick<ReformerCandidate, 'name' | 'sourceRef'>): PlanSection {
  const haystack = `${candidate.name} ${candidate.sourceRef ?? ''}`;
  return SLOT_RULES.find((r) => r.pattern.test(haystack))?.section ?? 'main';
}

const byClassicalOrder = (a: ReformerCandidate, b: ReformerCandidate) =>
  (a.reformer?.classicalOrder ?? Number.MAX_SAFE_INTEGER) - (b.reformer?.classicalOrder ?? Number.MAX_SAFE_INTEGER)
  || a.name.localeCompare(b.name, 'de');

/** Kandidaten auf die vier Slots verteilen und je Slot klassisch sortieren. */
export function arrangeByOrder(candidates: readonly ReformerCandidate[]): ReformerProgram {
  const program: ReformerProgram = { sonsomo: [], main: [], core: [], mobility: [] };
  const seen = new Set<number>();
  for (const c of candidates) {
    if (seen.has(c.id)) continue;   // das Modell wiederholt sich gern
    seen.add(c.id);
    program[reformerSlot(c)].push(c);
  }
  for (const s of SECTIONS) program[s].sort(byClassicalOrder);
  return program;
}

// ── Umfang ───────────────────────────────────────────────────────────────

export type ReformerDuration = 30 | 45 | 60;
export const REFORMER_DURATION_COUNTS: Record<ReformerDuration, Record<PlanSection, number>> = {
  30: { sonsomo: 3, main: 4, core: 2, mobility: 1 },
  45: { sonsomo: 5, main: 6, core: 3, mobility: 2 },
  60: { sonsomo: 5, main: 9, core: 4, mobility: 2 },
};
export const DEFAULT_REFORMER_DURATION: ReformerDuration = 45;

/** n Elemente gleichmässig über die Liste verteilt — deckt die Serie ab statt nur ihren Anfang. */
export function evenlySpaced<T>(list: readonly T[], n: number): T[] {
  if (n <= 0 || list.length === 0) return [];
  if (n >= list.length) return [...list];
  if (n === 1) return [list[0]];
  const picks: T[] = [];
  for (let i = 0; i < n; i++) picks.push(list[Math.round((i * (list.length - 1)) / (n - 1))]);
  return picks;
}

/**
 * Deterministisches Programm — der Rückfall ohne Modell und die Messlatte
 * für dessen Auswahl. Footwork, Gurte und Abschluss vom Anfang des Slots,
 * die Serie gleichmässig über ihre Länge, damit ein kurzer Plan nicht nur
 * aus Overhead und Coordination besteht.
 */
export function buildReformerProgram(
  pool: readonly ReformerCandidate[],
  level: ReformerLevel,
  duration: ReformerDuration | null,
): ReformerProgram {
  const admitted = pool.filter((c) => admitsLevel(level, c.level));
  const full = arrangeByOrder(admitted);
  const counts = REFORMER_DURATION_COUNTS[duration ?? DEFAULT_REFORMER_DURATION];
  return {
    sonsomo: full.sonsomo.slice(0, counts.sonsomo),
    main: evenlySpaced(full.main, counts.main),
    core: full.core.slice(0, counts.core),
    mobility: full.mobility.slice(0, counts.mobility),
  };
}

// ── Zeile ────────────────────────────────────────────────────────────────

export interface ReformerRowDetails {
  device: string;
  position: string;
  sets: string;
  springs: string;
  breathing: string;
  tempo: string;
}

function defaultSets(candidate: ReformerCandidate): string {
  const n = `${candidate.name} ${candidate.sourceRef ?? ''}`;
  if (/footwork/i.test(n)) return '10';
  if (/hundert|hundred/i.test(n)) return '10 Atemzyklen';
  if (/\blaufen\b|running/i.test(n)) return '20';
  if (/spagat|splits|seitw|side to side/i.test(n)) return '3 je Seite';
  return '5–8';
}

/** Angaben der Zeile aus dem Repertoire — nichts davon rät das Modell. */
export function reformerRowDetails(candidate: ReformerCandidate): ReformerRowDetails {
  const r = candidate.reformer;
  const attachment = r?.attachment && r.attachment !== 'keines' ? r.attachment : null;
  const setup = [
    r?.footbar ? `Fussstange ${r.footbar}` : null,
    r?.headrest ? `Kopfstütze ${r.headrest}` : null,
    r?.position ?? null,
  ].filter((x): x is string => !!x);
  return {
    device: attachment ? `Reformer · ${attachment}` : 'Reformer',
    position: setup.join(' · '),
    sets: defaultSets(candidate),
    springs: r?.springs ?? '',
    breathing: candidate.breathing ?? '',
    tempo: candidate.tempo ?? '',
  };
}

// ── Federprogression ─────────────────────────────────────────────────────

export interface PreviousPlanRow {
  exerciseId: number | null;
  springs: string;
  /** Termin-Spalten des Vorplans; gefüllt = absolviert. */
  dates: readonly string[];
}

export interface SpringCarryOver {
  exerciseId: number;
  /** Was der Trainer im Vorplan eingestellt hatte — hat Vorrang vor dem Katalog. */
  springs: string;
  completedSessions: number;
  /** Nur gesetzt, wenn der Vorplan oft genug absolviert wurde. */
  hint: string | null;
}

/** Ab so vielen absolvierten Terminen ist eine Stufe schwerer eine Prüfung wert. */
export const PROGRESSION_THRESHOLD = 6;

/**
 * Kontinuität schlägt Katalog: hatte der Trainer die Federn im Vorplan
 * angepasst, gilt seine Einstellung. Ob eine Stufe schwerer dran ist,
 * bleibt sein Entscheid — der Code liefert nur den Hinweis mit Zahl.
 * (Leichtere Federn sind bei Stabilitätsübungen die Steigerung; ein
 * Automatismus in eine Richtung wäre fachlich falsch.)
 */
export function springCarryOvers(
  previous: readonly PreviousPlanRow[],
  chosen: readonly ReformerCandidate[],
): SpringCarryOver[] {
  const chosenIds = new Set(chosen.map((c) => c.id));
  const result: SpringCarryOver[] = [];
  for (const row of previous) {
    if (row.exerciseId == null || !chosenIds.has(row.exerciseId) || !row.springs.trim()) continue;
    const completed = row.dates.filter((d) => d.trim() !== '').length;
    const name = chosen.find((c) => c.id === row.exerciseId)?.name ?? `#${row.exerciseId}`;
    result.push({
      exerciseId: row.exerciseId,
      springs: row.springs.trim(),
      completedSessions: completed,
      hint: completed >= PROGRESSION_THRESHOLD
        ? `${name}: Vorplan ${completed}× absolviert mit ${row.springs.trim()} — eine Stufe schwerer prüfen`
        : null,
    });
  }
  return result;
}

// ── Prompt ───────────────────────────────────────────────────────────────

const LEVEL_LABEL: Record<ReformerLevel, string> = {
  beginner: 'Basic', intermediate: 'Intermediate', advanced: 'Advanced',
};

/** Ersetzt die Athletik-Regeln 4 und 5 des Systemprompts für Reformer-Pläne. */
export function reformerPromptBlock(level: ReformerLevel, duration: ReformerDuration | null): string {
  const c = REFORMER_DURATION_COUNTS[duration ?? DEFAULT_REFORMER_DURATION];
  return `MODALITÄT: REFORMER PILATES (klassisches Repertoire)
Die Regeln 4 und 5 oben gelten für Athletik-Pläne und sind für diesen Plan ERSETZT durch:
- Wähle AUSSCHLIESSLICH Übungen aus dem Katalog und gib immer die exercise_id an. KEINE neuen Übungen (exercise_id: null ist verboten) — eine Reformer-Übung ohne Federangabe ist nicht definiert.
- Level des Kunden: ${LEVEL_LABEL[level]}. Der Katalog enthält nur zulässige Übungen (id|name|level|order|federn).
- Umfang: "sonsomo" = Footwork & Hundred: ${c.sonsomo} Übungen · "main" = Serie: ${c.main} · "core" = Gurte & Knee Stretch: ${c.core} · "mobility" = Abschluss: ${c.mobility}.
- Die Reihenfolge und die Zuordnung zum Abschnitt legt anschliessend der Code nach der klassischen Ordnung fest; die Federn, Fussstange, Kopfstütze, Atmung und Tempo kommen aus dem Repertoire. Lass "device", "position", "weight" leer; "sets" darfst du weglassen.
- Schwächen aus dem Leistungstest nur berücksichtigen, soweit das Repertoire sie abdeckt — keine Fitness- oder Athletik-Übungen einfügen.
- Abwechslung gegenüber den letzten Plänen ist erwünscht, die Eröffnung mit Footwork ist Pflicht.
- In "reasoning": warum diese Auswahl für diesen Kunden (Befunde, Ziele, Beruf), worauf beim Unterrichten zu achten ist (Betonung, Cues), und was wegen der Anamnese bewusst weggelassen wurde.`;
}
