import { mapRepDb } from '../domain/exercise-mapping';
import { findExisting, fillableFields } from '../domain/duplicate-detection';
import { ImportCatalogUseCase } from '../application/import-catalog.usecase';
import type { CatalogEntry, ExistingExercise } from '../domain/catalog-entry';

const record = {
  id: 'barbell-back-squat',
  name_en: 'Barbell Back Squat', name_de: 'Kniebeuge mit Langhantel',
  category: 'strength', force_type: 'push', mechanic: 'compound', difficulty: 'intermediate',
  equipment: 'barbell', body_part: 'upper_legs', primary_muscles: ['quadriceps', 'gluteus_maximus'],
  tags: ['leg_day'], is_unilateral: false, is_bodyweight: false,
  instructions_de: ['Stange auf dem Trapez ablegen.', 'Tief in die Hocke gehen.'],
  tips_de: ['Knie folgen den Zehen.'], met: '6.0',
};

describe('mapRepDb', () => {
  it('überführt einen RepDB-Datensatz vollständig', () => {
    const e = mapRepDb(record)!;
    expect(e.source).toBe('repdb');
    expect(e.sourceRef).toBe('barbell-back-squat');
    expect(e.modality).toBe('fitness');
    expect(e.groupName).toBe('Freie Gewichte');
    expect(e.level).toBe('intermediate');
    expect(e.bodyRegion).toBe('LowerBody');
    expect(e.primaryMuscleGroup).toBe('Quadriceps');
    expect(e.movementPattern).toBe('Squat');            // aus dem Namen, nicht aus force_type=push
    expect(e.instructionsDe).toBe('Stange auf dem Trapez ablegen.\nTief in die Hocke gehen.');
    expect(e.cuesDe).toBe('Knie folgen den Zehen.');
    expect(e.met).toBe(6);
  });

  it('erkennt Pilates am Namen und Cardio an der Kategorie', () => {
    expect(mapRepDb({ ...record, id: 'p', name_en: 'Pilates Roll Up', name_de: 'Pilates Roll Up' })!.modality).toBe('pilates_mat');
    expect(mapRepDb({ ...record, id: 'c', category: 'cardio', equipment: 'rower' })!.modality).toBe('cardio');
    expect(mapRepDb({ ...record, id: 'l', equipment: 'leg_press' })!.groupName).toBe('Gerätetraining');
  });

  it('verwirft Datensätze ohne deutschen Namen', () => {
    expect(mapRepDb({ ...record, name_de: '' })).toBeNull();
  });
});

const existing = (over: Partial<ExistingExercise> = {}): ExistingExercise => ({
  id: 1, name: 'Kniebeuge', primaryMuscleGroup: 'Quadriceps',
  source: null, sourceRef: null, modality: null, equipment: null, level: null,
  instructionsDe: null, cuesDe: null, isUnilateral: null, met: null, ...over,
});

describe('findExisting', () => {
  const entry = mapRepDb(record)!;

  it('findet den Bestand über Herkunft + Fremd-ID', () => {
    const hit = existing({ name: 'irgendwas', source: 'repdb', sourceRef: 'barbell-back-squat' });
    expect(findExisting(entry, [hit])).toBe(hit);
  });

  it('findet den Bestand über den normalisierten Namen', () => {
    const hit = existing({ name: 'Kniebeuge mit Langhantel' });
    expect(findExisting(entry, [hit])).toBe(hit);
  });

  it('nimmt ähnliche Namen nur bei gleicher Muskelgruppe', () => {
    const sameMuscle = existing({ name: 'Langhantel Kniebeuge', primaryMuscleGroup: 'Quadriceps' });
    const otherMuscle = existing({ name: 'Langhantel Kniebeuge', primaryMuscleGroup: 'Brust' });
    expect(findExisting(entry, [sameMuscle])).toBe(sameMuscle);
    expect(findExisting(entry, [otherMuscle])).toBeNull();
  });

  it('füllt nur leere Felder, der Bestand gewinnt', () => {
    const hit = existing({ level: 'advanced', equipment: null });
    const patch = fillableFields(entry, hit);
    expect(patch.level).toBeUndefined();          // bestand bleibt „advanced"
    expect(patch.equipment).toBe('barbell');      // leer → gefüllt
    expect(patch.source).toBe('repdb');
  });
});

describe('ImportCatalogUseCase', () => {
  const entries: CatalogEntry[] = [mapRepDb(record)!, mapRepDb({ ...record, id: 'dup', name_en: 'Back Squat' })!];

  it('ist idempotent: der zweite Lauf ändert nichts mehr', async () => {
    const store: ExistingExercise[] = [];
    const repo = {
      listExisting: async () => store.map((e) => ({ ...e })),
      ensureGroup: async () => 7,
      insert: async (e: CatalogEntry) => {
        store.push(existing({ id: store.length + 1, name: e.nameDe, source: e.source, sourceRef: e.sourceRef,
          modality: e.modality, equipment: e.equipment, level: e.level, instructionsDe: e.instructionsDe,
          cuesDe: e.cuesDe, isUnilateral: e.isUnilateral, met: e.met, primaryMuscleGroup: e.primaryMuscleGroup }));
        return store.length;
      },
      patch: async () => undefined,
      upsertReformer: async () => undefined, saveIcon: jest.fn(),
    };
    const source = { name: 'test', overwrites: false, load: async () => ({ entries, problems: [] }) };

    const first = await new ImportCatalogUseCase(source, repo).execute({ dryRun: false });
    expect(first.inserted).toBe(1);              // „Back Squat" ist eine Dublette der Kniebeuge
    expect(first.unchanged).toBe(1);

    const second = await new ImportCatalogUseCase(source, repo).execute({ dryRun: false });
    expect(second.inserted).toBe(0);
    expect(second.updated).toBe(0);
    expect(second.unchanged).toBe(2);
  });

  it('schreibt im Probelauf nichts', async () => {
    const insert = jest.fn(async () => 1);
    const repo = { listExisting: async () => [], ensureGroup: async () => 1, insert, patch: jest.fn(), upsertReformer: jest.fn(), saveIcon: jest.fn(), };
    const source = { name: 't', overwrites: false, load: async () => ({ entries, problems: [] }) };
    const report = await new ImportCatalogUseCase(source, repo).execute({ dryRun: true });
    expect(report.inserted).toBe(1);
    expect(insert).not.toHaveBeenCalled();
  });
});
