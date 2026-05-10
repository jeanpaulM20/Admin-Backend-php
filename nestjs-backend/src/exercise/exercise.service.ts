import { Injectable, Logger, NotFoundException } from '@nestjs/common';
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

  create(data: Partial<Exercise>) {
    return this.exerciseRepo.save(this.exerciseRepo.create(data));
  }

  async update(id: number, data: Partial<Exercise>) {
    await this.findOne(id);
    await this.exerciseRepo.update(id, data);
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
    details: string[];
  }> {
    const details: string[] = [];
    let groupsCreated = 0;
    let subgroupsCreated = 0;
    let exercisesCreated = 0;
    let exercisesSkipped = 0;

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

      // 3. Create exercises (skip duplicates)
      for (const ex of category.exercises) {
        if (existingNames.has(ex.name.toLowerCase())) {
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
      `${exercisesCreated} exercises created, ${exercisesSkipped} skipped`,
    );

    return { groupsCreated, subgroupsCreated, exercisesCreated, exercisesSkipped, details };
  }
}
