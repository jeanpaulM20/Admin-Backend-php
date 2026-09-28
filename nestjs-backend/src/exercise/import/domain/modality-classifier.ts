import type { Modality } from '../../domain/exercise-vocabulary';

/**
 * Kategorie, Tags und Name einer Fremdquelle → unsere Modalität.
 * Plyometrie bleibt bei Athletik — dort liegt der bestehende Katalog.
 */
export function classifyModality(input: {
  category: string | null;
  tags: readonly string[];
  nameEn: string | null;
  nameDe: string | null;
}): Modality {
  const name = `${input.nameEn ?? ''} ${input.nameDe ?? ''}`.toLowerCase();
  if (name.includes('pilates')) return 'pilates_mat';
  switch ((input.category ?? '').toLowerCase()) {
    case 'cardio':       return 'cardio';
    case 'plyometrics':  return 'athletik';
    case 'stretching':
    case 'strength':
    case 'olympic':
    default:             return 'fitness';
  }
}

/** Grobe Katalog-Gruppe; bestehende Gruppennamen werden bewusst wiederverwendet. */
export function classifyGroup(input: {
  category: string | null;
  equipment: string | null;
  isBodyweight: boolean;
  modality: Modality;
}): string {
  const eq = (input.equipment ?? '').toLowerCase();
  if (input.modality === 'pilates_mat') return 'Pilates Matte';
  if (input.modality === 'cardio') return 'Ausdauer & Intervalltraining';
  if ((input.category ?? '').toLowerCase() === 'plyometrics') return 'Plyometrie & Reaktivkraft';
  if ((input.category ?? '').toLowerCase() === 'stretching') return 'Mobilität & Aktive Beweglichkeit';
  if (eq.includes('kettlebell')) return 'Kettlebell-Training';
  if (eq === 'rings' || eq === 'suspension_trainer') return 'Ring- & Suspension-Training';
  if (eq === 'cable') return 'Kabelzug';
  if (/machine|leg_press|hack_squat|leg_curl|leg_extension|pec_deck|smith|glute_ham|sled/.test(eq)) return 'Gerätetraining';
  if (/barbell|dumbbell|ez_bar|trap_bar|plates|flat_bench/.test(eq)) return 'Freie Gewichte';
  if (/band/.test(eq)) return 'Widerstandsbänder';
  if (input.isBodyweight || eq === '' || eq === 'pull_up_bar' || eq === 'dip_station') {
    return 'Eigenkörpergewicht / Calisthenics';
  }
  return 'Gerätetraining';
}
