import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Training, TrainingStatus } from '../entities/training.entity';

@Injectable()
export class TrainingService {
  constructor(
    @InjectRepository(Training)
    private readonly repo: Repository<Training>,
  ) {}

  findAll(clientId?: number, trainerId?: number) {
    const where: any = {};
    if (clientId) where.clientId = clientId;
    if (trainerId) where.trainerId = trainerId;
    return this.repo.find({ where, relations: ['trainer', 'client', 'exercisesets'] });
  }

  async findOne(id: number) {
    const training = await this.repo.findOne({
      where: { id },
      relations: ['trainer', 'client', 'exercisesets'],
    });
    if (!training) throw new NotFoundException(`Training ${id} not found`);
    return training;
  }

  create(data: Partial<Training>) {
    return this.repo.save(this.repo.create(data));
  }

  async update(id: number, data: Partial<Training>) {
    await this.findOne(id);
    await this.repo.update(id, data);
    return this.findOne(id);
  }

  async cancel(id: number) {
    const training = await this.findOne(id);
    if (training.status === TrainingStatus.ATTENDED) {
      throw new BadRequestException('Cannot cancel an attended training');
    }
    await this.repo.update(id, {
      status: TrainingStatus.CANCELLED,
      cancelledAt: new Date(),
    });
    return this.findOne(id);
  }

  async remove(id: number) {
    const training = await this.findOne(id);
    return this.repo.remove(training);
  }
}
