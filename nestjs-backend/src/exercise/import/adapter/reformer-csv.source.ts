import { promises as fs } from 'fs';
import type { CatalogSource, SourceLoad } from '../application/ports';
import { parseDelimited } from '../domain/delimited-text';
import { mapReformerSheet } from '../domain/reformer-sheet-mapping';

/**
 * Das Erfassungsblatt des Studios (data/reformer-repertoire.csv) als Quelle.
 * Es ist die Wahrheit über das Repertoire — darum überschreibt es den
 * Bestand. Der Pfad kommt von aussen (Composition Root).
 */
export class ReformerCsvSource implements CatalogSource {
  readonly name = 'reformer-sheet';
  readonly overwrites = true;

  constructor(private readonly path: string) {}

  async load(): Promise<SourceLoad> {
    let text: string;
    try {
      text = await fs.readFile(this.path, 'utf8');
    } catch {
      throw new Error(`Erfassungsblatt nicht gefunden: ${this.path}`);
    }
    return mapReformerSheet(parseDelimited(text, ';'));
  }
}
