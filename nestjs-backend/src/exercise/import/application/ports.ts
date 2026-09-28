import type { CatalogEntry, ExistingExercise } from '../domain/catalog-entry';

/** Eine Fremdquelle liefert normalisierte Einträge — woher, ist ihre Sache. */
export interface CatalogSource {
  readonly name: string;
  load(): Promise<CatalogEntry[]>;
}

/** Was der Use Case vom Katalog braucht — nicht mehr. */
export interface ExerciseCatalogRepository {
  listExisting(): Promise<ExistingExercise[]>;
  ensureGroup(name: string): Promise<number>;
  insert(entry: CatalogEntry, groupId: number): Promise<number>;
  patch(id: number, fields: Partial<ExistingExercise>): Promise<void>;
}

export interface ImportReport {
  source: string;
  dryRun: boolean;
  total: number;
  inserted: number;
  updated: number;
  unchanged: number;
  skipped: number;
  groups: string[];
  samples: { inserted: string[]; updated: string[] };
}
