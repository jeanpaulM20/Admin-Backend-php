/**
 * Kontraindikationen: aus den Anamnese-Signalen Schlüssel ableiten und den
 * Katalog VOR dem Prompt bereinigen. Ein Modell, das eine gesperrte Übung
 * nicht kennt, kann sie nicht vorschlagen (Konzept, Abschnitt 6).
 */
import type { ContraindicationKey } from '../../exercise/domain/exercise-vocabulary';
import { parseContraindications } from '../../exercise/domain/exercise-vocabulary';

/** Die Anamnese-Signale, die hier zählen — bewusst ohne Datenbanktypen. */
export interface ConstraintSignals {
  injuryType: string | null;
  injuryBodypart: string | null;
  musculoskeletal: string | null;
  comments: string | null;
  heartCirculatory: boolean;
  /** Blutdruck systolisch/diastolisch, falls gemessen */
  systolic: number | null;
  diastolic: number | null;
}

interface Rule { pattern: RegExp; keys: ContraindicationKey[] }

/** Freitext-Signale → Schlüssel. Gross-/Kleinschreibung spielt keine Rolle. */
const TEXT_RULES: Rule[] = [
  { pattern: /bandscheib|lws|lendenwirbel|ischias|hexenschuss/i, keys: ['lumbar_flexion_load'] },
  { pattern: /osteoporo/i, keys: ['spinal_flexion', 'lumbar_flexion_load', 'high_impact'] },
  { pattern: /schwanger/i, keys: ['prone', 'supine_late_pregnancy', 'high_impact', 'inversion'] },
  { pattern: /schulter|impingement|rotator|supraspinatus/i, keys: ['shoulder_overhead'] },
  { pattern: /knie|patella|meniskus|kreuzband|jumpers/i, keys: ['knee_deep_flexion', 'high_impact'] },
  { pattern: /achilles|sprunggelenk|fuss|fuß/i, keys: ['high_impact'] },
  { pattern: /bluthochdruck|hypertonie|glaukom/i, keys: ['inversion'] },
];

export function deriveConstraintKeys(signals: ConstraintSignals): Set<ContraindicationKey> {
  const keys = new Set<ContraindicationKey>();
  const text = [signals.injuryType, signals.injuryBodypart, signals.musculoskeletal, signals.comments]
    .filter((t): t is string => !!t)
    .join(' ');
  for (const rule of TEXT_RULES) {
    if (rule.pattern.test(text)) rule.keys.forEach((k) => keys.add(k));
  }
  if (signals.heartCirculatory) keys.add('inversion');
  if ((signals.systolic ?? 0) > 140 || (signals.diastolic ?? 0) > 90) keys.add('inversion');
  return keys;
}

export interface ContraindicationCandidate {
  name: string;
  contraindications: string | null;
}

export interface FilterOutcome<T> {
  admitted: T[];
  excluded: { name: string; reason: ContraindicationKey }[];
}

/**
 * Entfernt Übungen, deren Schlüssel mit den Befunden des Kunden kollidieren.
 * Übungen ohne Schlüssel bleiben — die fachliche Zuordnung liegt beim Studio,
 * nicht bei einem automatischen Verdacht.
 */
export function excludeContraindicated<T extends ContraindicationCandidate>(
  catalog: readonly T[],
  constraints: ReadonlySet<ContraindicationKey>,
): FilterOutcome<T> {
  if (constraints.size === 0) return { admitted: [...catalog], excluded: [] };
  const admitted: T[] = [];
  const excluded: FilterOutcome<T>['excluded'] = [];
  for (const exercise of catalog) {
    const hit = parseContraindications(exercise.contraindications).find((k) => constraints.has(k));
    if (hit) excluded.push({ name: exercise.name, reason: hit });
    else admitted.push(exercise);
  }
  return { admitted, excluded };
}
