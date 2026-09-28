import {
  admitsLevel, arrangeByOrder, buildReformerProgram, evenlySpaced, reformerPromptBlock,
  reformerRowDetails, reformerSlot, springCarryOvers, type ReformerCandidate,
} from '../domain/reformer-program';
import { admitsExercise, SECTION_LABELS } from '../domain/plan-modality';

const c = (id: number, name: string, order: number, level: string | null = 'beginner', extra: Partial<ReformerCandidate> = {}): ReformerCandidate => ({
  id, name, sourceRef: null, level, breathing: null, tempo: null,
  reformer: { springs: `${5 - (order % 4)} Federn (klassisch)`, springLoad: 3, footbar: 'hoch', headrest: 'oben', carriageStart: 'geschlossen', attachment: 'keines', position: 'Rückenlage', classicalOrder: order },
  ...extra,
});

/** Verkleinertes Repertoire in der Reihenfolge des Erfassungsblatts. */
const POOL: ReformerCandidate[] = [
  c(1, 'Footwork Zehen', 1), c(2, 'Footwork Fersen', 3), c(3, 'Hundert', 5),
  c(4, 'Überkopf', 6, 'advanced'), c(5, 'Koordination', 7, 'intermediate'),
  c(6, 'Short Box runder Rücken', 19), c(7, 'Elefant', 27), c(8, 'Stomach Massage rund', 29),
  c(9, 'Short Spine Massage', 34, 'intermediate'),
  c(10, 'Beinkreise', 44), c(11, 'Frösche', 45), c(12, 'Knee Stretch rund', 46),
  c(13, 'Laufen', 49), c(14, 'Beckenheben', 50), c(15, 'Seitspagat', 53, 'intermediate'),
  c(16, 'Studio-Eigene Übung', 99, null),
];

describe('Reformer-Modalität', () => {
  it('lässt nur das Repertoire zu — keine Aushilfe aus dem Bestand', () => {
    expect(admitsExercise('pilates_reformer', { modality: 'pilates_reformer', group: 'Reformer Pilates' })).toBe(true);
    expect(admitsExercise('pilates_reformer', { modality: null, group: 'Mobilität & Aktive Beweglichkeit' })).toBe(false);
    expect(admitsExercise('pilates_reformer', { modality: 'pilates_mat', group: null })).toBe(false);
    expect(SECTION_LABELS.pilates_reformer.sonsomo).toBe('Footwork & Hundred');
  });

  it('Level: Basic sieht nur Basic, Advanced alles, ohne Angabe immer', () => {
    expect(admitsLevel('beginner', 'beginner')).toBe(true);
    expect(admitsLevel('beginner', 'intermediate')).toBe(false);
    expect(admitsLevel('intermediate', 'advanced')).toBe(false);
    expect(admitsLevel('advanced', 'advanced')).toBe(true);
    expect(admitsLevel('beginner', null)).toBe(true);
  });
});

describe('Abschnitte und Reihenfolge', () => {
  it('ordnet nach Namen den vier Slots zu, Unbekanntes in die Serie', () => {
    expect(reformerSlot({ name: 'Footwork Zehen', sourceRef: null })).toBe('sonsomo');
    expect(reformerSlot({ name: 'Hundert', sourceRef: 'Hundred' })).toBe('sonsomo');
    expect(reformerSlot({ name: 'Frösche', sourceRef: 'Frogs' })).toBe('core');
    expect(reformerSlot({ name: 'Laufen', sourceRef: 'Running' })).toBe('mobility');
    expect(reformerSlot({ name: 'Liegestütz vorne', sourceRef: null })).toBe('mobility');
    expect(reformerSlot({ name: 'Short Spine Massage', sourceRef: null })).toBe('main');   // mitten in der Serie
    expect(reformerSlot({ name: 'Studio-Eigene Übung', sourceRef: null })).toBe('main');
  });

  it('sortiert klassisch, entfernt Doppelte und hält die Gesamtordnung über alle Slots', () => {
    const shuffled = [POOL[13], POOL[7], POOL[0], POOL[10], POOL[7], POOL[2], POOL[5]];
    const p = arrangeByOrder(shuffled);
    const orders = [...p.sonsomo, ...p.main, ...p.core, ...p.mobility].map((x) => x.reformer!.classicalOrder);
    expect(orders).toEqual([1, 5, 19, 29, 45, 50]);
  });

  it('verteilt gleichmässig über die Serie', () => {
    expect(evenlySpaced([1, 2, 3, 4, 5, 6, 7], 3)).toEqual([1, 4, 7]);
    expect(evenlySpaced([1, 2], 5)).toEqual([1, 2]);
    expect(evenlySpaced([], 2)).toEqual([]);
  });
});

describe('Deterministisches Programm', () => {
  it('Basic, 30 Minuten: Footwork zuerst, Umfang nach Dauer, kein Advanced', () => {
    const p = buildReformerProgram(POOL, 'beginner', 30);
    expect(p.sonsomo.map((x) => x.name)).toEqual(['Footwork Zehen', 'Footwork Fersen', 'Hundert']);
    expect(p.main).toHaveLength(4);
    expect(p.core.map((x) => x.name)).toEqual(['Beinkreise', 'Frösche']);
    expect(p.mobility.map((x) => x.name)).toEqual(['Laufen']);
    const all = [...p.sonsomo, ...p.main, ...p.core, ...p.mobility];
    expect(all.some((x) => x.level === 'advanced' || x.level === 'intermediate')).toBe(false);
    expect(all.some((x) => x.name === 'Studio-Eigene Übung')).toBe(true);   // ohne Level zulässig
  });

  it('Advanced, 60 Minuten: nimmt, was da ist, ohne zu wiederholen', () => {
    const p = buildReformerProgram(POOL, 'advanced', 60);
    const ids = [...p.sonsomo, ...p.main, ...p.core, ...p.mobility].map((x) => x.id);
    expect(new Set(ids).size).toBe(ids.length);
    expect(p.main.map((x) => x.name)).toContain('Überkopf');
  });
});

describe('Zeile aus dem Repertoire', () => {
  it('setzt Gerät, Aufbau, Federn, Atmung, Tempo und Wiederholungen', () => {
    const d = reformerRowDetails(c(1, 'Footwork Zehen', 1, 'beginner', {
      breathing: '5 ein / 5 aus', tempo: '2-0-2-0',
      reformer: { springs: '1 rot + 1 blau', springLoad: 4, footbar: 'hoch', headrest: 'oben', carriageStart: 'geschlossen', attachment: 'keines', position: 'Rückenlage', classicalOrder: 1 },
    }));
    expect(d).toEqual({
      device: 'Reformer', position: 'Fussstange hoch · Kopfstütze oben · Rückenlage',
      sets: '10', springs: '1 rot + 1 blau', breathing: '5 ein / 5 aus', tempo: '2-0-2-0',
    });
    const box = reformerRowDetails(c(6, 'Short Box runder Rücken', 19, 'beginner', {
      reformer: { springs: null, springLoad: null, footbar: null, headrest: null, carriageStart: null, attachment: 'Short Box', position: 'Sitz', classicalOrder: 19 },
    }));
    expect(box.device).toBe('Reformer · Short Box');
    expect(box.position).toBe('Sitz');
    expect(box.sets).toBe('5–8');
  });
});

describe('Federn aus dem Vorplan', () => {
  it('übernimmt die Einstellung des Trainers und gibt ab sechs Terminen einen Hinweis', () => {
    const previous = [
      { exerciseId: 1, springs: '1 rot + 1 gelb', dates: ['1.9.', '3.9.', '5.9.', '8.9.', '10.9.', '12.9.', '', ''] },
      { exerciseId: 3, springs: '2 rot', dates: ['1.9.', '', '', '', '', '', '', ''] },
      { exerciseId: 7, springs: '', dates: ['1.9.', '3.9.', '5.9.', '8.9.', '10.9.', '12.9.', '', ''] },
      { exerciseId: 99, springs: '3 rot', dates: [] },
    ];
    const chosen = [POOL[0], POOL[2], POOL[6]];
    const result = springCarryOvers(previous, chosen);
    expect(result.map((r) => r.exerciseId)).toEqual([1, 3]);           // 7 ohne Federn, 99 nicht im Plan
    expect(result[0].springs).toBe('1 rot + 1 gelb');
    expect(result[0].hint).toContain('6× absolviert');
    expect(result[1].hint).toBeNull();
  });
});

describe('Prompt', () => {
  it('verbietet neue Übungen und nennt Level und Umfang', () => {
    const block = reformerPromptBlock('intermediate', 45);
    expect(block).toContain('exercise_id: null ist verboten');
    expect(block).toContain('Intermediate');
    expect(block).toContain('Footwork & Hundred: 5');
  });
});
