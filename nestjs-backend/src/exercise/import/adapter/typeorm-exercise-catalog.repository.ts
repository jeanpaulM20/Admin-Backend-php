import { Repository } from 'typeorm';
import { Exercise } from '../../../entities/exercise.entity';
import { Exercisegroup } from '../../../entities/exercise-group.entity';
import type { ExerciseCatalogRepository } from '../application/ports';
import type { CatalogEntry, ExistingExercise } from '../domain/catalog-entry';

/** TypeORM-Adapter für den Katalog — die einzige Stelle mit Datenbankwissen. */
export class TypeOrmExerciseCatalogRepository implements ExerciseCatalogRepository {
  constructor(
    private readonly exercises: Repository<Exercise>,
    private readonly groups: Repository<Exercisegroup>,
  ) {}

  async listExisting(): Promise<ExistingExercise[]> {
    const rows = await this.exercises.find({ where: { archive: 0 } });
    return rows.map((e) => ({
      id: e.id,
      name: e.name,
      primaryMuscleGroup: e.primaryMuscleGroup ?? null,
      source: e.source ?? null,
      sourceRef: e.sourceRef ?? null,
      modality: e.modality ?? null,
      equipment: e.equipment ?? null,
      level: e.level ?? null,
      instructionsDe: e.instructionsDe ?? null,
      cuesDe: e.cuesDe ?? null,
      isUnilateral: e.isUnilateral ?? null,
      met: e.met ?? null,
    }));
  }

  async ensureGroup(name: string): Promise<number> {
    const found = await this.groups.findOne({ where: { name } });
    if (found) return found.id;
    const created = await this.groups.save(this.groups.create({ name }));
    return created.id;
  }

  async insert(entry: CatalogEntry, groupId: number): Promise<number> {
    const saved = await this.exercises.save(
      this.exercises.create({
        name: entry.nameDe,
        groupId,
        archive: 0,
        published: 1,
        modality: entry.modality,
        equipment: entry.equipment,
        level: entry.level,
        bodyRegion: entry.bodyRegion ?? undefined,
        primaryMuscleGroup: entry.primaryMuscleGroup ?? undefined,
        movementPattern: entry.movementPattern ?? undefined,
        instructionsDe: entry.instructionsDe,
        cuesDe: entry.cuesDe,
        isUnilateral: entry.isUnilateral,
        met: entry.met,
        source: entry.source,
        sourceRef: entry.sourceRef,
      }),
    );
    return saved.id;
  }

  async patch(id: number, fields: Partial<ExistingExercise>): Promise<void> {
    const { name: _name, id: _id, primaryMuscleGroup: _m, ...safe } = fields;
    await this.exercises.update({ id }, safe);
  }
}
