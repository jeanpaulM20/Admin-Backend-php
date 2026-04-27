import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TrainingPlan } from '../entities/training-plan.entity';

@Injectable()
export class TrainingPlanService {
  constructor(
    @InjectRepository(TrainingPlan)
    private readonly repo: Repository<TrainingPlan>,
  ) {}

  findAll(clientId?: number) {
    return this.repo.find({
      where: clientId ? { clientId } : {},
      relations: ['exercisesets', 'exercisesets.exercises'],
    });
  }

  async findOne(id: number) {
    const plan = await this.repo.findOne({
      where: { id },
      relations: ['client', 'trainer', 'exercisesets', 'exercisesets.exercises'],
    });
    if (!plan) throw new NotFoundException(`TrainingPlan ${id} not found`);
    return plan;
  }

  create(data: Partial<TrainingPlan>) {
    return this.repo.save(this.repo.create(data));
  }

  async update(id: number, data: Partial<TrainingPlan>) {
    await this.findOne(id);
    await this.repo.update(id, data);
    return this.findOne(id);
  }

  async remove(id: number) {
    const plan = await this.findOne(id);
    return this.repo.remove(plan);
  }
}
