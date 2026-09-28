/**
 * Konfiguration des Katalog-Imports — ausschliesslich hier gelesen und in
 * die Adapter hineingereicht (Composition Root). Kein anderes Modul greift
 * dafür auf process.env zu.
 */
export interface CatalogImportConfig {
  repDbUrl: string;
}

export function readCatalogImportConfig(env: NodeJS.ProcessEnv = process.env): CatalogImportConfig {
  return {
    repDbUrl:
      env.REPDB_SOURCE_URL ??
      'https://raw.githubusercontent.com/RepDB/exercise-dataset/main/exercises.json',
  };
}
