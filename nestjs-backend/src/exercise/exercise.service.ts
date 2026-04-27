import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Exercise } from '../entities/exercise.entity';
import { Exercisegroup } from '../entities/exercise-group.entity';

@Injectable()
export class ExerciseService {
  constructor(
    @InjectRepository(Exercise)
    private readonly exerciseRepo: Repository<Exercise>,
    @InjectRepository(Exercisegroup)
    private readonly groupRepo: Repository<Exercisegroup>,
  ) {}

  findAll() {
    return this.exerciseRepo.find({ relations: ['group', 'subgroup', 'pictures'] });
  }

  async findOne(id: number) {
    const exercise = await this.exerciseRepo.findOne({
      where: { id },
      relations: ['group', 'subgroup', 'pictures'],
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
}
