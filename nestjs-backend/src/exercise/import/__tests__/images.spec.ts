import { ImportCatalogImagesUseCase } from '../application/import-catalog-images.usecase';
import { mapRepDb, repDbImageUrl } from '../domain/exercise-mapping';
import { imageMime, isImage } from '../adapter/http-image-fetcher';
import type { CatalogEntry, ExistingExercise } from '../domain/catalog-entry';

const BASE = 'https://example.test/repdb';

describe('RepDB-Bildadresse', () => {
  it('nimmt die Endposition, bei Dehnungen main, ohne Basis nichts', () => {
    const rec = { id: 'x', name_en: 'X', images: { flat: { start: 'images/flat/x-start.webp', peak: 'images/flat/x-peak.webp' } } };
    expect(repDbImageUrl(rec, BASE + '/')).toBe(`${BASE}/images/flat/x-peak.webp`);
    expect(repDbImageUrl({ id: 'y', images: { flat: { main: '/images/flat/y.webp' } } }, BASE)).toBe(`${BASE}/images/flat/y.webp`);
    expect(repDbImageUrl(rec, null)).toBeNull();
    expect(repDbImageUrl({ id: 'z' }, BASE)).toBeNull();
    expect(mapRepDb({ id: 'x', name_en: 'X', name_de: 'X', category: 'strength' }, BASE)?.imageUrl).toBeNull();
  });
});

describe('Bildtyp aus den Bytes', () => {
  const webp = new Uint8Array([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38]);
  const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
  it('erkennt WebP und PNG, lehnt Text ab', () => {
    expect(isImage(webp)).toBe(true);
    expect(isImage(png)).toBe(true);
    expect(isImage(new TextEncoder().encode('<html>404</html>'))).toBe(false);
    expect(imageMime(webp)).toBe('image/webp');
    expect(imageMime(png)).toBe('image/png');
  });
});

describe('Bild-Import', () => {
  const entry = (ref: string, url: string | null): CatalogEntry => ({
    source: 'repdb', sourceRef: ref, nameDe: ref, nameEn: ref, modality: 'fitness', groupName: 'G',
    equipment: null, level: null, bodyRegion: null, primaryMuscleGroup: null, movementPattern: null,
    instructionsDe: null, cuesDe: null, isUnilateral: null, met: null, imageUrl: url,
  });
  const existing = (id: number, ref: string, hasIcon: boolean): ExistingExercise => ({
    id, name: ref, primaryMuscleGroup: null, source: 'repdb', sourceRef: ref, modality: 'fitness',
    equipment: null, level: null, instructionsDe: null, cuesDe: null, isUnilateral: null, met: null, hasIcon,
  });
  const entries = [entry('a', 'u/a'), entry('b', 'u/b'), entry('c', 'u/c'), entry('d', null), entry('e', 'u/e')];
  const source = { name: 'repdb', overwrites: false, load: async () => ({ entries, problems: [] }) };
  const makeRepo = () => ({
    listExisting: async () => [existing(1, 'a', false), existing(2, 'b', true), existing(3, 'c', false), existing(4, 'd', false)],
    ensureGroup: jest.fn(), insert: jest.fn(), patch: jest.fn(), upsertReformer: jest.fn(),
    saveIcon: jest.fn(async () => undefined),
  });

  it('holt nur für zugeordnete Einträge ohne Bild; vorhandene Bilder bleiben; Fehler zählen', async () => {
    const repo = makeRepo();
    const fetcher = { fetch: jest.fn(async (url: string) => (url === 'u/c' ? null : new Uint8Array([1, 2, 3]))) };
    const report = await new ImportCatalogImagesUseCase(source, repo, fetcher).execute({ dryRun: false });
    expect(report).toMatchObject({ withImage: 4, matched: 3, alreadyHasIcon: 1, fetched: 1, failed: 1 });
    expect(repo.saveIcon).toHaveBeenCalledTimes(1);
    expect(repo.saveIcon).toHaveBeenCalledWith(1, new Uint8Array([1, 2, 3]));
    expect(report.samples.failed).toEqual(['c']);
  });

  it('Probelauf zählt, ohne zu holen oder zu schreiben; limit begrenzt', async () => {
    const repo = makeRepo();
    const fetcher = { fetch: jest.fn(async () => new Uint8Array([1])) };
    const dry = await new ImportCatalogImagesUseCase(source, repo, fetcher).execute({ dryRun: true });
    expect(dry.fetched).toBe(2);
    expect(fetcher.fetch).not.toHaveBeenCalled();
    expect(repo.saveIcon).not.toHaveBeenCalled();
    const limited = await new ImportCatalogImagesUseCase(source, repo, fetcher).execute({ dryRun: false, limit: 1 });
    expect(limited.fetched).toBe(1);
    expect(fetcher.fetch).toHaveBeenCalledTimes(1);
  });
});
