/**
 * Modalität eines Trainingsplans — welche Übungen ihm offenstehen und wie
 * seine vier Abschnitte heissen. Reine Fachlogik (Konzept, Abschnitt 5).
 */
import type { Modality } from '../../exercise/domain/exercise-vocabulary';

/** Modalitäten, die der Generator bedient. Matten-Pilates ist noch offen (Konzept, Entscheidung 3). */
export type PlanModality = 'athletik' | 'fitness' | 'pilates_reformer';
export const PLAN_MODALITIES: readonly PlanModality[] = ['athletik', 'fitness', 'pilates_reformer'];

export type PlanSection = 'sonsomo' | 'main' | 'core' | 'mobility';

/** Beschriftung der vier technischen Abschnitte je Modalität. */
export const SECTION_LABELS: Record<PlanModality, Record<PlanSection, string>> = {
  athletik: { sonsomo: 'Sonsomo', main: 'Haupttraining', core: 'Core', mobility: 'Mobilität' },
  fitness:  { sonsomo: 'Aufwärmen', main: 'Hauptteil', core: 'Core', mobility: 'Ausklang' },
  // Die vier Slots folgen der klassischen Reihenfolge lückenlos — darum diese
  // Beschriftung und nicht „Zug & Arme / Core" aus dem Konzept: Reihenfolge
  // schlägt Benennung (Konzept, Abschnitt 7). Zuordnung: reformer-program.ts.
  pilates_reformer: { sonsomo: 'Footwork & Hundred', main: 'Serie', core: 'Gurte & Knee Stretch', mobility: 'Abschluss' },
};

/** Minimale Sicht auf einen Katalogeintrag, die diese Regel braucht. */
export interface ModalityCandidate {
  modality: string | null;
  group: string | null;
}

/** Bestandsgruppen, die als Aufwärmen/Ausklang in jeden Plan passen. */
const UNIVERSAL_GROUPS = new Set([
  'Mobilität & Aktive Beweglichkeit',
  'Propriozeption',
  'Fußmuskulatur & Barfuß-Training',
]);

/**
 * Darf eine Übung in einem Plan dieser Modalität vorkommen?
 *
 * Bestand ohne Modalität (die ursprünglichen 148) gilt als Athletik. Ein
 * Fitness-Plan zieht aus Gerätetraining und Cardio, dazu die Mobilitäts- und
 * Propriozeptionsgruppen des Bestands für Aufwärmen und Ausklang — sonst
 * bliebe ein Fitness-Plan ohne brauchbares Warm-up.
 */
export function admitsExercise(planModality: PlanModality, exercise: ModalityCandidate): boolean {
  const m = (exercise.modality ?? 'athletik') as Modality | 'athletik';
  switch (planModality) {
    case 'athletik':
      return m === 'athletik' || m === 'cardio';
    case 'fitness':
      return m === 'fitness' || m === 'cardio'
        || (m === 'athletik' && !!exercise.group && UNIVERSAL_GROUPS.has(exercise.group));
    case 'pilates_reformer':
      // Nur das Repertoire selbst: eine Reformer-Übung ohne Federangabe ist
      // nicht definiert, also gibt es hier keine Aushilfe aus dem Bestand.
      return m === 'pilates_reformer';
  }
}

export function filterCatalogByModality<T extends ModalityCandidate>(
  catalog: readonly T[],
  planModality: PlanModality,
): T[] {
  return catalog.filter((e) => admitsExercise(planModality, e));
}
