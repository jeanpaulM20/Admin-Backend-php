/**
 * Konfiguration des Katalog-Imports — ausschliesslich hier gelesen und in
 * die Adapter hineingereicht (Composition Root). Kein anderes Modul greift
 * dafür auf process.env zu.
 */
import * as fs from 'fs';
import * as path from 'path';

export interface CatalogImportConfig {
  repDbUrl: string;
  /** Wurzel der RepDB-Bildpfade (images/flat/…); leer = keine Bilder. */
  repDbImageBase: string | null;
  /** Erfassungsblatt des Studios; liegt im Repo unter data/. */
  reformerSheetPath: string;
}

export function readCatalogImportConfig(env: NodeJS.ProcessEnv = process.env): CatalogImportConfig {
  return {
    repDbUrl:
      env.REPDB_SOURCE_URL ??
      'https://raw.githubusercontent.com/RepDB/exercise-dataset/main/exercises.json',
    repDbImageBase:
      env.REPDB_IMAGE_BASE ?? 'https://raw.githubusercontent.com/RepDB/exercise-dataset/main',
    reformerSheetPath: env.REFORMER_SHEET_PATH ?? defaultSheetPath(),
  };
}

/**
 * Im Repo liegt das Blatt unter data/, im Deploy-Image nur unter dist/data/
 * (der Build kopiert es dorthin, das Docker-Image enthält nur dist/).
 */
function defaultSheetPath(): string {
  const candidates = ['data', path.join('dist', 'data')].map((dir) =>
    path.resolve(process.cwd(), dir, 'reformer-repertoire.csv'),
  );
  return candidates.find((p) => fs.existsSync(p)) ?? candidates[0];
}
