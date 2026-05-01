import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TrainerAvailability } from '../entities/trainer-availability.entity';

@Injectable()
export class AvailabilityService {
  constructor(
    @InjectRepository(TrainerAvailability)
    private readonly repo: Repository<TrainerAvailability>,
  ) {}

  findAll(trainerId?: number) {
    const where: any = {};
    if (trainerId) where.trainerId = trainerId;
    return this.repo.find({ where, order: { date: 'ASC', from: 'ASC' } });
  }

  findOne(id: number) {
    return this.repo.findOneBy({ id });
  }

  create(data: Partial<TrainerAvailability>) {
    return this.repo.save(this.repo.create(data));
  }

  async update(id: number, data: Partial<TrainerAvailability>) {
    await this.repo.update(id, data);
    return this.findOne(id);
  }

  async remove(id: number) {
    const a = await this.repo.findOneBy({ id });
    if (!a) return null;
    return this.repo.remove(a);
  }
}
