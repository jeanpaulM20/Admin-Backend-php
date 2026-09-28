/**
 * Fachvokabular des Übungskatalogs — reine Typen und Konstanten.
 *
 * Domain-Schicht: kein TypeORM, kein Nest, keine Konfiguration. Entities,
 * Import-Adapter und Generator lesen von hier, nie umgekehrt.
 * Siehe KONZEPT-PROGRAMM-GENERATOR.md, Abschnitt 4.
 */

/** Trainingswelt, in die eine Übung oder ein Plan gehört. */
export type Modality =
  | 'athletik'          // Bestand: Propriozeption, Plyometrie, Kettlebell …
  | 'fitness'           // klassisches Gerätetraining
  | 'cardio'
  | 'pilates_mat'
  | 'pilates_reformer';

export const MODALITIES: readonly Modality[] = [
  'athletik', 'fitness', 'cardio', 'pilates_mat', 'pilates_reformer',
];

export type ExerciseLevel = 'beginner' | 'intermediate' | 'advanced';

export const EXERCISE_LEVELS: readonly ExerciseLevel[] = ['beginner', 'intermediate', 'advanced'];

/** Woher ein Katalogeintrag stammt — nötig, um Importe später neu abzugleichen. */
export type ExerciseSource = 'sihl' | 'repdb' | 'free-exercise-db';

/**
 * Kontraindikations-Schlüssel an der Übung. Der Generator filtert Übungen mit
 * einem Schlüssel heraus, der zum Befund des Kunden passt — VOR dem Prompt.
 * Gespeichert als kommagetrennte Liste in `exercise.contraindications`.
 */
export type ContraindicationKey =
  | 'lumbar_flexion_load'   // Flexion der LWS unter Last (Bandscheibe, Osteoporose)
  | 'spinal_flexion'        // jede belastete Wirbelsäulenflexion (Osteoporose)
  | 'inversion'             // Kopf unter Herz (Herz-Kreislauf, Bluthochdruck)
  | 'prone'                 // Bauchlage (Schwangerschaft)
  | 'supine_late_pregnancy' // Rückenlage ab 2. Trimester
  | 'shoulder_overhead'     // Überkopf-Zug/-Druck (Schulterproblematik)
  | 'knee_deep_flexion'     // tiefe Kniebeugung (Knie)
  | 'high_impact';          // Sprünge (Gelenke, Schwangerschaft)

export const CONTRAINDICATION_KEYS: readonly ContraindicationKey[] = [
  'lumbar_flexion_load', 'spinal_flexion', 'inversion', 'prone',
  'supine_late_pregnancy', 'shoulder_overhead', 'knee_deep_flexion', 'high_impact',
];

export function parseContraindications(raw: string | null | undefined): ContraindicationKey[] {
  if (!raw) return [];
  return raw
    .split(',')
    .map((k) => k.trim())
    .filter((k): k is ContraindicationKey => (CONTRAINDICATION_KEYS as readonly string[]).includes(k));
}

export function serializeContraindications(keys: readonly ContraindicationKey[]): string | null {
  return keys.length ? [...new Set(keys)].join(',') : null;
}

/** Reformer: Fussbrett, Kopfstütze, Schlitten, Zusatz — das Vokabular der Übungsangaben. */
export type ReformerFootbar = 'hoch' | 'tief' | 'unten';
export type ReformerHeadrest = 'oben' | 'flach';
export type ReformerCarriage = 'geschlossen' | 'offen';
export type ReformerAttachment =
  | 'keines' | 'lange Gurte' | 'kurze Gurte' | 'Box quer' | 'Box längs' | 'Jumpboard';
export type ReformerPosition = 'Rückenlage' | 'Bauchlage' | 'Sitz' | 'Knien' | 'Stand' | 'Stütz' | 'Seitlage';

/**
 * Normierte Federlast 0–5. Die Farbe ist Anzeige (hersteller­abhängig),
 * die Zahl ist das, womit die Progression rechnet.
 */
export const SPRING_LOAD_MIN = 0;
export const SPRING_LOAD_MAX = 5;
