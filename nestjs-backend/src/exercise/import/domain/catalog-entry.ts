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
}
