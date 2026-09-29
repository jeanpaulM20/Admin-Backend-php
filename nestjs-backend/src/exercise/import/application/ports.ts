import type { CatalogEntry, ExistingExercise, ReformerSpec } from '../domain/catalog-entry';

export interface SourceLoad {
  entries: CatalogEntry[];
  /** Zeilen, die die Quelle nicht übernehmen konnte, mit Grund. */
  problems: string[];
}

/** Eine Quelle liefert normalisierte Einträge — woher, ist ihre Sache. */
export interface CatalogSource {
  readonly name: string;
  /**
   * false: Fremdquelle — der Bestand gewinnt, es werden nur leere Felder
   *        gefüllt (RepDB).
   * true:  die Quelle ist die Wahrheit — gesetzte Felder überschreiben den
   *        Bestand (das Erfassungsblatt des Studios).
   */
  readonly overwrites: boolean;
  load(): Promise<SourceLoad>;
}

/** Was der Use Case vom Katalog braucht — nicht mehr. */
export interface ExerciseCatalogRepository {
  listExisting(): Promise<ExistingExercise[]>;
  ensureGroup(name: string): Promise<number>;
  insert(entry: CatalogEntry, groupId: number): Promise<number>;
  patch(id: number, fields: Partial<ExistingExercise>): Promise<void>;
  /** Reformer-Angaben anlegen oder ersetzen — die Tabelle hängt am Eintrag. */
  upsertReformer(exerciseId: number, spec: ReformerSpec): Promise<void>;
  /** Bild ablegen (PNG oder WebP, Rohbytes). */
  saveIcon(exerciseId: number, bytes: Uint8Array): Promise<void>;
}

/** Holt ein Bild von einer Adresse — oder null, wenn es keines ist. */
export interface ImageFetcher {
  fetch(url: string): Promise<Uint8Array | null>;
}

export interface ImageImportReport {
  source: string;
  dryRun: boolean;
  /** Einträge der Quelle mit Bildadresse */
  withImage: number;
  /** davon im Katalog gefunden */
  matched: number;
  /** übersprungen, weil schon ein Bild da ist — vorhandene Bilder bleiben */
  alreadyHasIcon: number;
  fetched: number;
  failed: number;
  samples: { fetched: string[]; failed: string[] };
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
  /** Nicht übernommene Zeilen mit Grund — sichtbar statt still verschluckt. */
  problems: string[];
}
