import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Exercise } from '../entities/exercise.entity';
import { Exercisegroup } from '../entities/exercise-group.entity';
import { Exercisesubgroup } from '../entities/exercise-subgroup.entity';
import { EXERCISE_SEED_DATA } from './exercise-seed.data';

@Injectable()
export class ExerciseService {
  private readonly logger = new Logger(ExerciseService.name);

  constructor(
    @InjectRepository(Exercise)
    private readonly exerciseRepo: Repository<Exercise>,
    @InjectRepository(Exercisegroup)
    private readonly groupRepo: Repository<Exercisegroup>,
    @InjectRepository(Exercisesubgroup)
    private readonly subgroupRepo: Repository<Exercisesubgroup>,
  ) {}

  findAll() {
    return this.exerciseRepo.find({ relations: ['group', 'subgroup', 'exercisePictures'] });
  }

  async findOne(id: number) {
    const exercise = await this.exerciseRepo.findOne({
      where: { id },
      relations: ['group', 'subgroup', 'exercisePictures'],
    });
    if (!exercise) throw new NotFoundException(`Exercise ${id} not found`);
    return exercise;
  }

  findGroups() {
    return this.groupRepo.find();
  }

  private static readonly VALID_BODY_REGIONS = [
    'UpperBody', 'LowerBody', 'Core', 'FullBody', 'Foot',
  ];

  private static readonly VALID_MOVEMENT_PATTERNS = [
    'Push', 'Pull', 'Squat', 'Hinge', 'Carry',
    'Rotation', 'Static', 'Plyo', 'Sprint', 'Agility',
  ];

  /** Validate create/update payload and throw 400 on bad input. */
  private validatePayload(data: Partial<Exercise>, requireName = false) {
    if (requireName) {
      if (!data.name || typeof data.name !== 'string' || data.name.trim().length === 0) {
        throw new BadRequestException('Name is required and must be non-empty');
      }
      if (data.name.trim().length > 200) {
        throw new BadRequestException('Name must be 200 characters or fewer');
      }
    }
    if (data.bodyRegion !== undefined && data.bodyRegion !== null) {
      if (!ExerciseService.VALID_BODY_REGIONS.includes(data.bodyRegion)) {
        throw new BadRequestException(
          `Invalid bodyRegion "${data.bodyRegion}". Allowed: ${ExerciseService.VALID_BODY_REGIONS.join(', ')}`,
        );
      }
    }
    if (data.movementPattern !== undefined && data.movementPattern !== null) {
      if (!ExerciseService.VALID_MOVEMENT_PATTERNS.includes(data.movementPattern)) {
        throw new BadRequestException(
          `Invalid movementPattern "${data.movementPattern}". Allowed: ${ExerciseService.VALID_MOVEMENT_PATTERNS.join(', ')}`,
        );
      }
    }
  }

  /** Strip fields that clients must never set directly. */
  private sanitizePayload(data: Partial<Exercise>): Partial<Exercise> {
    const { id, archive, published, group, subgroup, exercisePictures, ...safe } = data as any;
    return safe;
  }

  async create(data: Partial<Exercise>) {
    this.validatePayload(data, true);
    const safe = this.sanitizePayload(data);
    safe.name = safe.name!.trim();
    safe.archive = 0;
    safe.published = 0;
    // Validate group exists if provided
    if (safe.groupId) {
      const group = await this.groupRepo.findOne({ where: { id: safe.groupId } });
      if (!group) throw new BadRequestException(`Group ${safe.groupId} not found`);
    }
    return this.exerciseRepo.save(this.exerciseRepo.create(safe));
  }

  async update(id: number, data: Partial<Exercise>) {
    this.validatePayload(data, false);
    const safe = this.sanitizePayload(data);
    if (safe.name !== undefined) safe.name = safe.name.trim();
    if (safe.groupId) {
      const group = await this.groupRepo.findOne({ where: { id: safe.groupId } });
      if (!group) throw new BadRequestException(`Group ${safe.groupId} not found`);
    }
    await this.findOne(id);
    await this.exerciseRepo.update(id, safe);
    return this.findOne(id);
  }

  async remove(id: number) {
    const exercise = await this.findOne(id);
    return this.exerciseRepo.remove(exercise);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEED — idempotent: skips exercises that already exist by name
  // ═══════════════════════════════════════════════════════════════════════════

  async seed(): Promise<{
    groupsCreated: number;
    subgroupsCreated: number;
    exercisesCreated: number;
    exercisesSkipped: number;
    metadataUpdated: number;
    details: string[];
  }> {
    const details: string[] = [];
    let groupsCreated = 0;
    let subgroupsCreated = 0;
    let exercisesCreated = 0;
    let exercisesSkipped = 0;
    let metadataUpdated = 0;

    // Cache existing exercise names for deduplication
    const existingExercises = await this.exerciseRepo.find({ select: ['name'] });
    const existingNames = new Set(existingExercises.map((e) => e.name.toLowerCase()));

    for (const category of EXERCISE_SEED_DATA) {
      // 1. Find or create group
      let group = await this.groupRepo.findOne({
        where: { name: category.group },
      });
      if (!group) {
        group = await this.groupRepo.save(
          this.groupRepo.create({ name: category.group }),
        );
        groupsCreated++;
        this.logger.log(`Created group: "${category.group}" → id=${group.id}`);
      }

      // 2. Find or create subgroups
      const subgroupMap = new Map<string, number>();
      for (const sgName of category.subgroups) {
        let sg = await this.subgroupRepo.findOne({ where: { name: sgName } });
        if (!sg) {
          sg = await this.subgroupRepo.save(
            this.subgroupRepo.create({ name: sgName }),
          );
          subgroupsCreated++;
        }
        subgroupMap.set(sgName, sg.id);
      }

      // 3. Create or update exercises (skip duplicates for new, update metadata for existing)
      for (const ex of category.exercises) {
        if (existingNames.has(ex.name.toLowerCase())) {
          // Update anatomy metadata on existing exercises (idempotent)
          if (ex.body_region || ex.primary_muscle_group || ex.target_joint || ex.movement_pattern) {
            await this.exerciseRepo.update(
              { name: ex.name },
              {
                ...(ex.body_region && { bodyRegion: ex.body_region }),
                ...(ex.primary_muscle_group && { primaryMuscleGroup: ex.primary_muscle_group }),
                ...(ex.target_joint && { targetJoint: ex.target_joint }),
                ...(ex.movement_pattern && { movementPattern: ex.movement_pattern }),
              },
            );
            metadataUpdated++;
          }
          exercisesSkipped++;
          continue;
        }

        const exercise = await this.exerciseRepo.save(
          this.exerciseRepo.create({
            name: ex.name,
            groupId: group.id,
            subgroupId: ex.subgroup ? subgroupMap.get(ex.subgroup) : undefined,
            published: 1,
            archive: 0,
            bodyRegion: ex.body_region || undefined,
            primaryMuscleGroup: ex.primary_muscle_group || undefined,
            targetJoint: ex.target_joint || undefined,
            movementPattern: ex.movement_pattern || undefined,
          }),
        );
        existingNames.add(ex.name.toLowerCase());
        exercisesCreated++;
      }

      details.push(
        `${category.group}: ${category.exercises.length} Übungen definiert`,
      );
    }

    this.logger.log(
      `Seed complete: ${groupsCreated} groups, ${subgroupsCreated} subgroups, ` +
      `${exercisesCreated} exercises created, ${exercisesSkipped} skipped, ${metadataUpdated} metadata updated`,
    );

    return { groupsCreated, subgroupsCreated, exercisesCreated, exercisesSkipped, metadataUpdated, details };
  }
}
