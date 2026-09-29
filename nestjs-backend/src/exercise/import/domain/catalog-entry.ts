/**
 * Normalisierter Katalogeintrag — die Form, in die jeder Import-Adapter
 * seine Quelle bringt. Domain-Schicht: keine Abhängigkeit nach aussen.
 */
import type { ExerciseLevel, ExerciseSource, Modality } from '../../domain/exercise-vocabulary';

export interface CatalogEntry {
  source: ExerciseSource;
  sourceRef: string;
  nameDe: string;
  nameEn: string | null;
  modality: Modality;
  groupName: string;             // Übungsgruppe im Katalog (get-or-create)
  equipment: string | null;
  level: ExerciseLevel | null;
  bodyRegion: string | null;
  primaryMuscleGroup: string | null;
  movementPattern: string | null;
  instructionsDe: string | null;
  cuesDe: string | null;
  isUnilateral: boolean | null;
  met: number | null;
  // Ausführung (Etappe 5) — optional, RepDB liefert sie nicht
  breathingDe?: string | null;
  tempo?: string | null;
  /** Nur fachlich abgenommene Schlüssel — nie ein automatischer Vorschlag. */
  contraindications?: string | null;
  /** Nur bei modality = pilates_reformer */
  reformer?: ReformerSpec | null;
  /** Illustration der Quelle (absolute Adresse), falls sie eine liefert. */
  imageUrl?: string | null;
}

/** Reformer-Angaben, Spiegel der Tabelle exercise_reformer. */
export interface ReformerSpec {
  springs: string | null;
  springLoad: number | null;
  footbar: string | null;
  headrest: string | null;
  carriageStart: string | null;
  attachment: string | null;
  position: string | null;
  classicalOrder: number | null;
}

/** Was der Importer über einen bestehenden Katalogeintrag wissen muss. */
export interface ExistingExercise {
  id: number;
  name: string;
  primaryMuscleGroup: string | null;
  source: string | null;
  sourceRef: string | null;
  // Felder, die ein Import nur füllt, wenn sie leer sind
  modality: string | null;
  equipment: string | null;
  level: string | null;
  instructionsDe: string | null;
  cuesDe: string | null;
  isUnilateral: boolean | null;
  met: number | null;
  breathingDe?: string | null;
  tempo?: string | null;
  contraindications?: string | null;
  /** Hat der Eintrag schon ein Bild? Nur der Bild-Import fragt danach. */
  hasIcon?: boolean;
}
