import { parseDelimited } from '../domain/delimited-text';
import { mapReformerSheet } from '../domain/reformer-sheet-mapping';
import { findExisting, masterFields } from '../domain/duplicate-detection';
import { ImportCatalogUseCase } from '../application/import-catalog.usecase';
import type { CatalogEntry, ExistingExercise } from '../domain/catalog-entry';

const HEADER = 'order;name_de;name_en;series;level;position;attachment;footbar;headrest;carriage_start;springs_classical;spring_load;springs_studio;breathing_de;tempo;cues_de;instructions_de;contraindications_vorschlag;contraindications;notes';

describe('parseDelimited', () => {
  it('liest BOM, CRLF, Anführungszeichen und Zeilenumbrüche im Feld', () => {
    const text = '﻿a;b\r\n1;"x;y"\r\n2;"Zeile 1\nZeile 2"\r\n3;"mit ""Zitat"""\r\n';
    const rows = parseDelimited(text, ';');
    expect(rows).toEqual([
      { a: '1', b: 'x;y' },
      { a: '2', b: 'Zeile 1\nZeile 2' },
      { a: '3', b: 'mit "Zitat"' },
    ]);
  });

  it('überspringt leere Zeilen', () => {
    expect(parseDelimited('a;b\n\n1;2\n', ';')).toEqual([{ a: '1', b: '2' }]);
  });
});

describe('mapReformerSheet', () => {
  const row = (over: Partial<Record<string, string>> = {}) => ({
    order: '1', name_de: 'Hundert', name_en: 'Hundred', series: '', level: 'basic',
    position: 'Rückenlage', attachment: 'kurze Gurte', footbar: 'unten', headrest: 'oben',
    carriage_start: 'geschlossen', springs_classical: '4', spring_load: '4.0', springs_studio: '',
    breathing_de: '5 ein / 5 aus', tempo: '', cues_de: 'Rippen schliessen', instructions_de: 'Schritt 1\nSchritt 2',
    contraindications_vorschlag: 'lumbar_flexion_load', contraindications: '', notes: '', ...over,
  });

  it('überführt eine Zeile in Eintrag plus Reformer-Angaben', () => {
    const { entries, problems } = mapReformerSheet([row()]);
    expect(problems).toEqual([]);
    const e = entries[0];
    expect(e.source).toBe('sihl-reformer');
    expect(e.sourceRef).toBe('Hundred');
    expect(e.modality).toBe('pilates_reformer');
    expect(e.level).toBe('beginner');
    expect(e.breathingDe).toBe('5 ein / 5 aus');
    expect(e.reformer).toEqual({
      springs: '4 Federn (klassisch)', springLoad: 4, footbar: 'unten', headrest: 'oben',
      carriageStart: 'geschlossen', attachment: 'kurze Gurte', position: 'Rückenlage', classicalOrder: 1,
    });
  });

  it('nimmt nur die abgenommene Kontraindikationsspalte, nie den Vorschlag', () => {
    const { entries } = mapReformerSheet([row()]);
    expect(entries[0].contraindications).toBeNull();
    const { entries: e2 } = mapReformerSheet([row({ contraindications: 'inversion, lumbar_flexion_load' })]);
    expect(e2[0].contraindications).toBe('inversion,lumbar_flexion_load');
  });

  it('bevorzugt die Studio-Federfarbe vor der klassischen Zahl', () => {
    const { entries } = mapReformerSheet([row({ springs_studio: '1 rot + 1 blau' })]);
    expect(entries[0].reformer?.springs).toBe('1 rot + 1 blau');
    const { entries: one } = mapReformerSheet([row({ springs_classical: '1', spring_load: '1' })]);
    expect(one[0].reformer?.springs).toBe('1 Feder (klassisch)');
  });

  it('lässt Zeilen mit unbekanntem Schlüssel oder ungültiger Federlast draussen', () => {
    const { entries, problems } = mapReformerSheet([
      row({ contraindications: 'inverson' }),
      row({ order: '2', name_en: 'Frogs', spring_load: '7' }),
      row({ order: '3', name_en: 'Leg Circles', spring_load: '2,5' }),
    ]);
    expect(entries.map((e) => e.nameEn)).toEqual(['Leg Circles']);
    expect(entries[0].reformer?.springLoad).toBe(2.5);
    expect(problems).toHaveLength(2);
    expect(problems[0]).toContain('inverson');
    expect(problems[1]).toContain('spring_load');
  });

  it('meldet doppelte Kennungen und fehlende Namen', () => {
    const { problems } = mapReformerSheet([row(), row({ order: '2' }), row({ order: '3', name_de: '' })]);
    expect(problems.some((p) => p.includes('doppelt'))).toBe(true);
    expect(problems.some((p) => p.includes('name_de fehlt'))).toBe(true);
  });
});

describe('Master-Quelle', () => {
  const existing: ExistingExercise = {
    id: 9, name: 'Hundert', primaryMuscleGroup: null, source: 'sihl-reformer', sourceRef: 'Hundred',
    modality: 'pilates_reformer', equipment: 'reformer', level: 'beginner',
    instructionsDe: 'alt', cuesDe: null, isUnilateral: null, met: null,
    breathingDe: null, tempo: null, contraindications: null,
  };
  const entry = mapReformerSheet([{ order: '1', name_de: 'Hundert', name_en: 'Hundred', level: 'basic',
    instructions_de: 'neu', cues_de: 'Cue', spring_load: '3' } as any]).entries[0];

  it('überschreibt gesetzte Felder, lässt leere in Ruhe', () => {
    const patch = masterFields(entry, existing);
    expect(patch.instructionsDe).toBe('neu');   // Blatt gewinnt
    expect(patch.cuesDe).toBe('Cue');            // vorher leer
    expect(patch).not.toHaveProperty('breathingDe'); // im Blatt leer → unangetastet
  });

  it('der Use Case schreibt Reformer-Angaben bei jedem Lauf neu', async () => {
    const upsert = jest.fn(async () => undefined);
    const repo = {
      listExisting: async () => [{ ...existing, instructionsDe: 'neu', cuesDe: 'Cue' }],
      ensureGroup: async () => 1, insert: jest.fn(async () => 1), patch: jest.fn(async () => undefined),
      upsertReformer: upsert,
    };
    const source = { name: 'sheet', overwrites: true, load: async () => ({ entries: [entry], problems: ['Zeile 5: x'] }) };
    const report = await new ImportCatalogUseCase(source, repo).execute({ dryRun: false });
    expect(report.updated).toBe(1);                 // nichts am Eintrag, aber Federn erneuert
    expect(upsert).toHaveBeenCalledWith(9, expect.objectContaining({ springLoad: 3, classicalOrder: 1 }));
    expect(report.problems).toEqual(['Zeile 5: x']);
    expect(repo.insert).not.toHaveBeenCalled();
  });

  // Produktionsfund: Reformer-„Laufen" traf per Name das Cardio-„Laufen" (RepDB, id 663).
  it('legt Reformer-Laufen nicht mit Cardio-Laufen zusammen', async () => {
    const cardio: ExistingExercise = {
      ...existing, id: 663, name: 'Laufen', source: 'repdb', sourceRef: 'running',
      modality: 'cardio', equipment: null, instructionsDe: null,
    };
    const laufen = mapReformerSheet([{ order: '30', name_de: 'Laufen', name_en: 'Running', level: 'basic' } as any]).entries[0];
    expect(findExisting(laufen, [cardio])).toBeNull();          // Modalitätsgrenze, selbst ohne Master-Regel

    const repo = {
      listExisting: async () => [cardio], ensureGroup: async () => 1,
      insert: jest.fn(async () => 2), patch: jest.fn(async () => undefined), upsertReformer: jest.fn(async () => undefined),
    };
    const source = { name: 'sheet', overwrites: true, load: async () => ({ entries: [laufen], problems: [] }) };
    const report = await new ImportCatalogUseCase(source, repo).execute({ dryRun: false });
    expect(report.inserted).toBe(1);
    expect(repo.patch).not.toHaveBeenCalled();
  });

  it('der Probelauf ruft nichts Schreibendes auf', async () => {
    const repo = {
      listExisting: async () => [] as ExistingExercise[], ensureGroup: jest.fn(async () => 1),
      insert: jest.fn(async () => 1), patch: jest.fn(async () => undefined), upsertReformer: jest.fn(async () => undefined),
    };
    const source = { name: 'sheet', overwrites: true, load: async () => ({ entries: [entry] as CatalogEntry[], problems: [] }) };
    const report = await new ImportCatalogUseCase(source, repo).execute({ dryRun: true });
    expect(report.inserted).toBe(1);
    expect(repo.insert).not.toHaveBeenCalled();
    expect(repo.upsertReformer).not.toHaveBeenCalled();
  });
});
