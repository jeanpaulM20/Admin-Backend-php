import type { CatalogSource, ExerciseCatalogRepository, ImportReport } from './ports';
import { fillableFields, findExisting } from '../domain/duplicate-detection';
import type { ExistingExercise } from '../domain/catalog-entry';

/**
 * Katalog aus einer Quelle einspielen — idempotent.
 *
 * Regeln (Konzept, Abschnitt 8): Bestand gewinnt immer; Importe füllen nur
 * leere Felder; neue Einträge kommen mit Herkunft und Fremd-ID, damit ein
 * späterer Lauf sie wiedererkennt statt sie zu verdoppeln.
 */
export class ImportCatalogUseCase {
  constructor(
    private readonly source: CatalogSource,
    private readonly repo: ExerciseCatalogRepository,
  ) {}

  async execute(options: { dryRun: boolean }): Promise<ImportReport> {
    const entries = await this.source.load();
    const existing: ExistingExercise[] = await this.repo.listExisting();
    const groupIds = new Map<string, number>();

    const report: ImportReport = {
      source: this.source.name,
      dryRun: options.dryRun,
      total: entries.length,
      inserted: 0, updated: 0, unchanged: 0, skipped: 0,
      groups: [],
      samples: { inserted: [], updated: [] },
    };

    for (const entry of entries) {
      const match = findExisting(entry, existing);

      if (match) {
        const patch = fillableFields(entry, match);
        if (Object.keys(patch).length === 0) {
          report.unchanged++;
          continue;
        }
        if (!options.dryRun) await this.repo.patch(match.id, patch);
        Object.assign(match, patch);
        report.updated++;
        if (report.samples.updated.length < 5) report.samples.updated.push(match.name);
        continue;
      }

      let groupId = groupIds.get(entry.groupName);
      if (groupId == null) {
        groupId = options.dryRun ? -1 : await this.repo.ensureGroup(entry.groupName);
        groupIds.set(entry.groupName, groupId);
      }
      const id = options.dryRun ? -1 : await this.repo.insert(entry, groupId);

      // In den Bestand aufnehmen, damit Dubletten innerhalb desselben Laufs
      // (z.B. zwei Varianten mit gleichem deutschem Namen) erkannt werden.
      existing.push({
        id, name: entry.nameDe,
        primaryMuscleGroup: entry.primaryMuscleGroup,
        source: entry.source, sourceRef: entry.sourceRef,
        modality: entry.modality, equipment: entry.equipment, level: entry.level,
        instructionsDe: entry.instructionsDe, cuesDe: entry.cuesDe,
        isUnilateral: entry.isUnilateral, met: entry.met,
      });
      report.inserted++;
      if (report.samples.inserted.length < 5) report.samples.inserted.push(entry.nameDe);
    }

    report.groups = [...groupIds.keys()].sort();
    return report;
  }
}
