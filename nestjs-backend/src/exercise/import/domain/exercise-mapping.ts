import type { ExerciseLevel } from '../../domain/exercise-vocabulary';
import { EXERCISE_LEVELS } from '../../domain/exercise-vocabulary';
import type { CatalogEntry } from './catalog-entry';
import { classifyGroup, classifyModality } from './modality-classifier';

/** Rohform eines RepDB-Eintrags — nur die Felder, die wir lesen. */
export interface RepDbRecord {
  id: string;
  name_en?: string; name_de?: string;
  category?: string;
  force_type?: string; mechanic?: string;
  difficulty?: string;
  equipment?: string;
  body_part?: string;
  primary_muscles?: string[];
  tags?: string[];
  is_unilateral?: boolean;
  is_bodyweight?: boolean;
  instructions_de?: string[] | string;
  tips_de?: string[] | string;
  met?: number | string;
}

/** RepDB body_part → unsere Körperregion (Vokabular aus exercise.entity.ts). */
const BODY_REGION: Record<string, string> = {
  upper_legs: 'LowerBody', lower_legs: 'LowerBody',
  back: 'UpperBody', chest: 'UpperBody', upper_arms: 'UpperBody', lower_arms: 'UpperBody',
  shoulders: 'Shoulder', core: 'Core', full_body: 'FullBody',
};

/** Häufigste Muskeln auf die deutschen Bezeichnungen des Bestands. */
const MUSCLE_DE: Record<string, string> = {
  gluteus_maximus: 'Gesäss', gluteus_medius: 'Gesäss',
  quadriceps: 'Quadriceps', hamstrings: 'Hamstrings', adductors: 'Adduktoren',
  gastrocnemius: 'Wade', soleus: 'Wade', hip_flexors: 'Hüftbeuger',
  pectoralis_major: 'Brust', latissimus_dorsi: 'Latissimus',
  trapezius: 'Oberer Rücken', rhomboids: 'Oberer Rücken', erector_spinae: 'Rückenstrecker',
  anterior_deltoid: 'Schulter', lateral_deltoid: 'Schulter', posterior_deltoid: 'Schulter',
  triceps_brachii: 'Trizeps', biceps_brachii: 'Bizeps',
  forearm_flexors: 'Unterarm', forearm_extensors: 'Unterarm',
  rectus_abdominis: 'Bauch', obliques: 'Schräge Bauchmuskeln', transverse_abdominis: 'Tiefe Bauchmuskeln',
};

/** Bewegungsmuster aus Name und Kraftrichtung — Vokabular aus exercise.entity.ts. */
function movementPattern(nameEn: string, forceType: string | undefined, category: string | undefined): string | null {
  const n = nameEn.toLowerCase();
  if ((category ?? '') === 'plyometrics' || /\bjump|hop|bound/.test(n)) return 'Plyo';
  if (/sprint/.test(n)) return 'Sprint';
  if (/carry|farmer|suitcase walk/.test(n)) return 'Carry';
  if (/twist|rotation|woodchop|chop|russian/.test(n)) return 'Rotation';
  if (/squat|lunge|step[- ]up|split/.test(n)) return 'Squat';
  if (/deadlift|hip thrust|good morning|rdl|hinge|glute bridge|swing|hyperextension|back extension/.test(n)) return 'Hinge';
  switch ((forceType ?? '').toLowerCase()) {
    case 'push':   return 'Push';
    case 'pull':   return 'Pull';
    case 'static': return 'Static';
    default:       return null;
  }
}

function joinSteps(value: string[] | string | undefined): string | null {
  if (!value) return null;
  const parts = Array.isArray(value) ? value : [value];
  const text = parts.map((s) => String(s).trim()).filter(Boolean).join('\n');
  return text || null;
}

function toLevel(value: string | undefined): ExerciseLevel | null {
  const v = (value ?? '').toLowerCase();
  return (EXERCISE_LEVELS as readonly string[]).includes(v) ? (v as ExerciseLevel) : null;
}

/** Einen RepDB-Datensatz in unseren Katalogeintrag überführen. */
export function mapRepDb(record: RepDbRecord): CatalogEntry | null {
  const nameDe = (record.name_de ?? '').trim();
  const nameEn = (record.name_en ?? '').trim() || null;
  if (!record.id || !nameDe) return null;

  const modality = classifyModality({
    category: record.category ?? null,
    tags: record.tags ?? [],
    nameEn,
    nameDe,
  });
  const equipment = (record.equipment ?? '').trim() || null;
  const muscleKey = record.primary_muscles?.[0] ?? null;
  const met = record.met == null ? null : Number(record.met);

  return {
    source: 'repdb',
    sourceRef: record.id,
    nameDe,
    nameEn,
    modality,
    groupName: classifyGroup({
      category: record.category ?? null,
      equipment,
      isBodyweight: !!record.is_bodyweight,
      modality,
    }),
    equipment,
    level: toLevel(record.difficulty),
    bodyRegion: record.body_part ? (BODY_REGION[record.body_part] ?? null) : null,
    primaryMuscleGroup: muscleKey ? (MUSCLE_DE[muscleKey] ?? humanize(muscleKey)) : null,
    movementPattern: movementPattern(nameEn ?? nameDe, record.force_type, record.category),
    instructionsDe: joinSteps(record.instructions_de),
    cuesDe: joinSteps(record.tips_de),
    isUnilateral: record.is_unilateral == null ? null : !!record.is_unilateral,
    met: met != null && Number.isFinite(met) && met > 0 ? met : null,
  };
}

function humanize(key: string): string {
  return key.replace(/_/g, ' ').replace(/^\w/, (c) => c.toUpperCase());
}
