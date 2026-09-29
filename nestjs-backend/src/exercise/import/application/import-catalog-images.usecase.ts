import type { ExistingExercise } from '../domain/catalog-entry';
import { findByKey } from '../domain/duplicate-detection';
import type { CatalogSource, ExerciseCatalogRepository, ImageFetcher, ImageImportReport } from './ports';

/**
 * Bilder einer Quelle in den Katalog holen — getrennt vom Datenimport, weil
 * Bilder gross sind und ein eigenes Tempo brauchen. Regeln:
 * - Nur Einträge, die über Herkunft + Kennung eindeutig zugeordnet sind.
 * - Vorhandene Bilder (eigene Fotos, KI-Bilder des Bestands) bleiben.
 * - Ein fehlgeschlagener Abruf bricht nicht ab, sondern zählt als failed.
 */
export class ImportCatalogImagesUseCase {
  constructor(
    private readonly source: CatalogSource,
    private readonly repo: ExerciseCatalogRepository,
    private readonly fetcher: ImageFetcher,
  ) {}

  async execute(options: { dryRun: boolean; limit?: number }): Promise<ImageImportReport> {
    const { entries } = await this.source.load();
    const existing: ExistingExercise[] = await this.repo.listExisting();
    const report: ImageImportReport = {
      source: this.source.name, dryRun: options.dryRun,
      withImage: 0, matched: 0, alreadyHasIcon: 0, fetched: 0, failed: 0,
      samples: { fetched: [], failed: [] },
    };
    let budget = options.limit ?? Number.POSITIVE_INFINITY;

    for (const entry of entries) {
      if (!entry.imageUrl) continue;
      report.withImage++;
      const match = findByKey(entry, existing);
      if (!match) continue;
      report.matched++;
      if (match.hasIcon) { report.alreadyHasIcon++; continue; }
      if (budget <= 0) continue;
      budget--;
      if (options.dryRun) { report.fetched++; continue; }

      const bytes = await this.fetcher.fetch(entry.imageUrl).catch(() => null);
      if (!bytes) {
        report.failed++;
        if (report.samples.failed.length < 10) report.samples.failed.push(match.name);
        continue;
      }
      await this.repo.saveIcon(match.id, bytes);
      match.hasIcon = true;
      report.fetched++;
      if (report.samples.fetched.length < 10) report.samples.fetched.push(match.name);
    }
    return report;
  }
}
