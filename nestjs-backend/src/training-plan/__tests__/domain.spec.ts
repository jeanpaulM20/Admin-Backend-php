import { admitsExercise, filterCatalogByModality, SECTION_LABELS } from '../domain/plan-modality';
import { deriveConstraintKeys, excludeContraindicated } from '../domain/contraindication-filter';
import { fitnessPromptBlock, STRENGTH_SCHEMES } from '../domain/strength-periodization';

describe('Modalität', () => {
  const legacy = { modality: null, group: 'Plyometrie & Reaktivkraft' };
  const mobility = { modality: null, group: 'Mobilität & Aktive Beweglichkeit' };
  const machine = { modality: 'fitness', group: 'Gerätetraining' };
  const cardio = { modality: 'cardio', group: 'Ausdauer & Intervalltraining' };
  const pilates = { modality: 'pilates_mat', group: 'Pilates Matte' };

  it('Athletik sieht den Bestand und Cardio, aber keine Geräte', () => {
    expect(admitsExercise('athletik', legacy)).toBe(true);
    expect(admitsExercise('athletik', cardio)).toBe(true);
    expect(admitsExercise('athletik', machine)).toBe(false);
    expect(admitsExercise('athletik', pilates)).toBe(false);
  });

  it('Fitness sieht Geräte, Cardio und die Mobilitätsgruppen des Bestands', () => {
    expect(admitsExercise('fitness', machine)).toBe(true);
    expect(admitsExercise('fitness', cardio)).toBe(true);
    expect(admitsExercise('fitness', mobility)).toBe(true);
    expect(admitsExercise('fitness', legacy)).toBe(false);   // Plyometrie gehört nicht ins Gerätetraining
    expect(admitsExercise('fitness', pilates)).toBe(false);
  });

  it('filtert eine Liste und beschriftet die Abschnitte', () => {
    expect(filterCatalogByModality([legacy, machine, cardio], 'fitness')).toEqual([machine, cardio]);
    expect(SECTION_LABELS.fitness.sonsomo).toBe('Aufwärmen');
    expect(SECTION_LABELS.athletik.sonsomo).toBe('Sonsomo');
  });
});

describe('Kontraindikationen', () => {
  const none = { injuryType: null, injuryBodypart: null, musculoskeletal: null, comments: null,
                 heartCirculatory: false, systolic: null, diastolic: null };

  it('leitet Schlüssel aus Verletzung, Kommentar und Messwerten ab', () => {
    expect([...deriveConstraintKeys({ ...none, injuryType: 'Bandscheibenvorfall', injuryBodypart: 'LWS' })])
      .toEqual(['lumbar_flexion_load']);
    expect(deriveConstraintKeys({ ...none, comments: 'Seit März schwanger' }).has('prone')).toBe(true);
    expect(deriveConstraintKeys({ ...none, systolic: 150, diastolic: 80 }).has('inversion')).toBe(true);
    expect(deriveConstraintKeys({ ...none, heartCirculatory: true }).has('inversion')).toBe(true);
    expect(deriveConstraintKeys(none).size).toBe(0);
  });

  it('entfernt nur Übungen mit kollidierendem Schlüssel, unmarkierte bleiben', () => {
    const catalog = [
      { name: 'Roll Over', contraindications: 'lumbar_flexion_load,inversion' },
      { name: 'Plank', contraindications: null },
      { name: 'Kniebeuge', contraindications: 'knee_deep_flexion' },
    ];
    const out = excludeContraindicated(catalog, new Set(['lumbar_flexion_load'] as const));
    expect(out.admitted.map((e) => e.name)).toEqual(['Plank', 'Kniebeuge']);
    expect(out.excluded).toEqual([{ name: 'Roll Over', reason: 'lumbar_flexion_load' }]);
  });

  it('lässt ohne Befunde alles durch', () => {
    const out = excludeContraindicated([{ name: 'x', contraindications: 'inversion' }], new Set());
    expect(out.admitted).toHaveLength(1);
  });
});

describe('Kraft-Periodisierung', () => {
  it('kennt drei Schemata mit steigender Wiederholungszahl', () => {
    expect(STRENGTH_SCHEMES.maxkraft.reps).toBe('3–6');
    expect(STRENGTH_SCHEMES.hypertrophie.reps).toBe('8–12');
    expect(STRENGTH_SCHEMES.kraftausdauer.reps).toBe('15–25');
  });

  it('der Prompt-Block ersetzt die Athletik-Struktur und nennt das Schema', () => {
    const block = fitnessPromptBlock('hypertrophie', 45);
    expect(block).toContain('ERSETZT');
    expect(block).toContain('Hypertrophie');
    expect(block).toContain('"main" = HAUPTTEIL: 4-5');
    expect(fitnessPromptBlock('maxkraft', null)).toContain('4–6 Übungen');
  });
});
