import type { CatalogSource, ExerciseCatalogRepository, ImportReport } from './ports';
import { fillableFields, findByKey, findExisting, masterFields } from '../domain/duplicate-detection';
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
    const { entries, problems } = await this.source.load();
    const existing: ExistingExercise[] = await this.repo.listExisting();
    const groupIds = new Map<string, number>();

    const report: ImportReport = {
      source: this.source.name,
      dryRun: options.dryRun,
      total: entries.length,
      inserted: 0, updated: 0, unchanged: 0, skipped: 0,
      groups: [],
      samples: { inserted: [], updated: [] },
      problems: [...problems],
    };

    for (const entry of entries) {
      // Eine Master-Quelle kennt ihr Repertoire selbst — sie legt nur mit
      // eigenen früheren Einträgen zusammen, nie per Namensähnlichkeit.
      const match = this.source.overwrites ? findByKey(entry, existing) : findExisting(entry, existing);

      if (match) {
        const patch = this.source.overwrites ? masterFields(entry, match) : fillableFields(entry, match);
        // Reformer-Angaben hängen an der eigenen Tabelle und werden bei einer
        // Master-Quelle immer mitgeschrieben — das Studio korrigiert Federn
        // im Blatt und erwartet sie beim nächsten Lauf im Katalog.
        const refreshReformer = this.source.overwrites && !!entry.reformer;
        if (Object.keys(patch).length === 0 && !refreshReformer) {
          report.unchanged++;
          continue;
        }
        if (!options.dryRun) {
          if (Object.keys(patch).length) await this.repo.patch(match.id, patch);
          if (refreshReformer) await this.repo.upsertReformer(match.id, entry.reformer!);
        }
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
      if (!options.dryRun && entry.reformer) await this.repo.upsertReformer(id, entry.reformer);

      // In den Bestand aufnehmen, damit Dubletten innerhalb desselben Laufs
      // (z.B. zwei Varianten mit gleichem deutschem Namen) erkannt werden.
      existing.push({
        id, name: entry.nameDe,
        primaryMuscleGroup: entry.primaryMuscleGroup,
        source: entry.source, sourceRef: entry.sourceRef,
        modality: entry.modality, equipment: entry.equipment, level: entry.level,
        instructionsDe: entry.instructionsDe, cuesDe: entry.cuesDe,
        isUnilateral: entry.isUnilateral, met: entry.met,
        breathingDe: entry.breathingDe ?? null, tempo: entry.tempo ?? null,
        contraindications: entry.contraindications ?? null,
      });
      report.inserted++;
      if (report.samples.inserted.length < 5) report.samples.inserted.push(entry.nameDe);
    }

    report.groups = [...groupIds.keys()].sort();
    return report;
  }
}
