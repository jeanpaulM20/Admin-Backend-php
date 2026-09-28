import type { CatalogSource, SourceLoad } from '../application/ports';
import type { CatalogEntry } from '../domain/catalog-entry';
import { mapRepDb, type RepDbRecord } from '../domain/exercise-mapping';

/**
 * RepDB (repdb.co) als Quelle — 601 Übungen mit deutschen Anleitungen.
 * Lizenz: frei für den Einsatz in Apps, sichtbarer Attributionslink nötig.
 * Die Adresse kommt von aussen (Composition Root), nicht aus process.env.
 */
export class RepDbSource implements CatalogSource {
  readonly name = 'repdb';
  /** Fremdquelle: der Bestand gewinnt. */
  readonly overwrites = false;

  constructor(private readonly url: string, private readonly fetchImpl: typeof fetch = fetch) {}

  async load(): Promise<SourceLoad> {
    const response = await this.fetchImpl(this.url, {
      headers: { Accept: 'application/json', 'User-Agent': 'SihlMove-Katalog/1.0' },
    });
    if (!response.ok) throw new Error(`RepDB antwortet ${response.status}`);
    const json = (await response.json()) as unknown;
    const records = Array.isArray(json)
      ? (json as RepDbRecord[])
      : ((json as { exercises?: RepDbRecord[] }).exercises ?? []);
    const entries = records.map(mapRepDb).filter((e): e is CatalogEntry => e !== null);
    return { entries, problems: [] };
  }
}
