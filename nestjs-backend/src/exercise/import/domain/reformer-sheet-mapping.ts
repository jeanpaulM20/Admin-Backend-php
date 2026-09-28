/**
 * Erfassungsblatt reformer-repertoire.csv → Katalogeinträge.
 * Reine Zuordnung und Prüfung; Lesen der Datei übernimmt der Adapter.
 */
import {
  CONTRAINDICATION_KEYS, EXERCISE_LEVELS, SPRING_LOAD_MAX, SPRING_LOAD_MIN,
  type ExerciseLevel,
} from '../../domain/exercise-vocabulary';
import type { CatalogEntry } from './catalog-entry';

export const REFORMER_GROUP = 'Reformer Pilates';
export const REFORMER_SOURCE = 'sihl-reformer' as const;

const POSITIONS = new Set(['Rückenlage', 'Bauchlage', 'Sitz', 'Knien', 'Stand', 'Stütz', 'Seitlage']);
const LEVELS: Record<string, ExerciseLevel> = { basic: 'beginner', intermediate: 'intermediate', advanced: 'advanced' };

export interface SheetOutcome {
  entries: CatalogEntry[];
  /** Zeilen, die nicht übernommen wurden, mit Grund. */
  problems: string[];
}

const blank = (v: string | undefined): string | null => (v && v.trim() ? v.trim() : null);

export function mapReformerSheet(rows: Record<string, string>[]): SheetOutcome {
  const entries: CatalogEntry[] = [];
  const problems: string[] = [];
  const seen = new Set<string>();

  rows.forEach((row, index) => {
    const line = index + 2; // Kopfzeile ist Zeile 1
    const nameDe = blank(row.name_de);
    const nameEn = blank(row.name_en);
    if (!nameDe) { problems.push(`Zeile ${line}: name_de fehlt`); return; }
    if (!nameEn) { problems.push(`Zeile ${line} (${nameDe}): name_en fehlt — dient als stabile Kennung`); return; }
    if (seen.has(nameEn)) { problems.push(`Zeile ${line}: name_en „${nameEn}" doppelt`); return; }
    seen.add(nameEn);

    const order = Number(row.order);
    if (!Number.isInteger(order) || order < 1) { problems.push(`Zeile ${line} (${nameDe}): order ist keine Zahl`); return; }

    const level = LEVELS[(row.level ?? '').toLowerCase()] ?? null;
    if (row.level && !level) problems.push(`Zeile ${line} (${nameDe}): level „${row.level}" unbekannt — gilt als leer`);

    const position = blank(row.position);
    if (position && !POSITIONS.has(position)) {
      problems.push(`Zeile ${line} (${nameDe}): position „${position}" nicht im Vokabular — übernommen, bitte prüfen`);
    }

    let springLoad: number | null = null;
    if (blank(row.spring_load)) {
      springLoad = Number(row.spring_load.replace(',', '.'));
      if (!Number.isFinite(springLoad) || springLoad < SPRING_LOAD_MIN || springLoad > SPRING_LOAD_MAX) {
        problems.push(`Zeile ${line} (${nameDe}): spring_load „${row.spring_load}" ausserhalb ${SPRING_LOAD_MIN}–${SPRING_LOAD_MAX}`);
        return;
      }
    }

    // Nur die abgenommene Spalte zählt. Ein Tippfehler in einem Schlüssel ist
    // ein Sicherheitsproblem, kein Schönheitsfehler — die Zeile bleibt draussen.
    const keys = (blank(row.contraindications) ?? '').split(',').map((k) => k.trim()).filter(Boolean);
    const bad = keys.filter((k) => !(CONTRAINDICATION_KEYS as readonly string[]).includes(k));
    if (bad.length) { problems.push(`Zeile ${line} (${nameDe}): unbekannte Kontraindikation ${bad.join(', ')}`); return; }

    const classical = blank(row.springs_classical);
    const springs = blank(row.springs_studio)
      ?? (classical ? `${classical} ${classical === '1' ? 'Feder' : 'Federn'} (klassisch)` : null);

    entries.push({
      source: REFORMER_SOURCE,
      sourceRef: nameEn,
      nameDe,
      nameEn,
      modality: 'pilates_reformer',
      groupName: REFORMER_GROUP,
      equipment: 'reformer',
      level,
      bodyRegion: null,
      primaryMuscleGroup: null,
      movementPattern: null,
      instructionsDe: blank(row.instructions_de),
      cuesDe: blank(row.cues_de),
      isUnilateral: null,
      met: null,
      breathingDe: blank(row.breathing_de),
      tempo: blank(row.tempo),
      contraindications: keys.length ? [...new Set(keys)].join(',') : null,
      reformer: {
        springs,
        springLoad,
        footbar: blank(row.footbar),
        headrest: blank(row.headrest),
        carriageStart: blank(row.carriage_start),
        attachment: blank(row.attachment),
        position,
        classicalOrder: order,
      },
    });
  });

  return { entries, problems };
}
