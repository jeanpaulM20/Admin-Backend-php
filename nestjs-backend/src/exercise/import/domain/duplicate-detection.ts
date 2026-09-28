import { normalizeName, similarity } from './text-normalizer';
import type { CatalogEntry, ExistingExercise } from './catalog-entry';

/**
 * Findet zu einem Importeintrag den bestehenden Katalogeintrag, falls es
 * ihn gibt. Regel aus dem Konzept: Treffer über normalisierten Namen ODER
 * hohe Namensähnlichkeit bei gleicher Muskelgruppe. Bestehende Einträge
 * gewinnen immer — der Import füllt nur leere Felder.
 */
export const SIMILARITY_THRESHOLD = 0.8;

export function findExisting(
  entry: CatalogEntry,
  existing: readonly ExistingExercise[],
): ExistingExercise | null {
  // 1) Schon einmal importiert: Herkunft + Fremd-ID sind eindeutig.
  const byRef = existing.find((e) => e.source === entry.source && e.sourceRef === entry.sourceRef);
  if (byRef) return byRef;

  // 2) Gleicher Name (deutsch oder englisch), normalisiert.
  const names = [entry.nameDe, entry.nameEn].filter((n): n is string => !!n).map(normalizeName);
  const byName = existing.find((e) => names.includes(normalizeName(e.name)));
  if (byName) return byName;

  // 3) Ähnlicher Name UND gleiche Muskelgruppe — sonst wären „Kniebeuge"
  //    und „Kniebeuge einbeinig" verschiedene Übungen mit gleichem Muskel.
  if (!entry.primaryMuscleGroup) return null;
  const muscle = normalizeName(entry.primaryMuscleGroup);
  return (
    existing.find((e) => {
      if (!e.primaryMuscleGroup || normalizeName(e.primaryMuscleGroup) !== muscle) return false;
      return [entry.nameDe, entry.nameEn].some((n) => n && similarity(n, e.name) >= SIMILARITY_THRESHOLD);
    }) ?? null
  );
}

/** Felder, die auf dem Bestand leer sind und aus dem Import gefüllt werden dürfen. */
export function fillableFields(
  entry: CatalogEntry,
  existing: ExistingExercise,
): Partial<ExistingExercise> {
  const patch: Partial<ExistingExercise> = {};
  const take = <K extends keyof ExistingExercise & keyof CatalogEntry>(key: K) => {
    const current = existing[key];
    const incoming = entry[key] as ExistingExercise[K] | null;
    if ((current == null || current === '') && incoming != null && incoming !== '') {
      patch[key] = incoming;
    }
  };
  take('modality'); take('equipment'); take('level');
  take('instructionsDe'); take('cuesDe'); take('isUnilateral'); take('met');
  if (!existing.source) {
    patch.source = entry.source;
    patch.sourceRef = entry.sourceRef;
  }
  return patch;
}
