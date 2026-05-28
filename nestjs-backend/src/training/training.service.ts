import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, MoreThanOrEqual, LessThanOrEqual } from 'typeorm';
import { Training, TrainingStatus } from '../entities/training.entity';

@Injectable()
export class TrainingService {
  constructor(
    @InjectRepository(Training)
    private readonly repo: Repository<Training>,
  ) {}

  private formatTraining(t: Training) {
    const typeName = t.trainingType?.name_de ?? t.trainingType?.name_en ?? null;
    return {
      ...t,
      training_type: typeName,
      type_name: typeName,
      type_abbr: t.trainingType?.abbr ?? null,
      location_name: t.location?.name ?? null,
    };
  }

  async findAll(clientId?: number, trainerId?: number, dateFrom?: string, dateTo?: string) {
    const where: any = {};
    if (clientId) where.clientId = clientId;
    if (trainerId) where.trainerId = trainerId;

    // Optional date range filtering
    if (dateFrom && dateTo) {
      where.date = Between(dateFrom, dateTo);
    } else if (dateFrom) {
      where.date = MoreThanOrEqual(dateFrom);
    } else if (dateTo) {
      where.date = LessThanOrEqual(dateTo);
    }

    const rows = await this.repo.find({
      where,
      relations: ['trainer', 'client', 'trainingType', 'location'],
      order: { date: 'ASC', starttime: 'ASC' },
    });
    return rows.map((t) => this.formatTraining(t));
  }

  async findOne(id: number, includeExercises = false) {
    const relations = ['trainer', 'client', 'trainingType', 'location'];
    if (includeExercises) relations.push('exercisesets');
    const training = await this.repo.findOne({
      where: { id },
      relations,
    });
    if (!training) throw new NotFoundException(`Training ${id} not found`);
    return this.formatTraining(training);
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
      cancelledAt: new Date().toISOString(),
    });
    return this.findOne(id);
  }

  async remove(id: number) {
    const raw = await this.repo.findOne({
      where: { id },
      relations: ['trainer', 'client', 'trainingType', 'location'],
    });
    if (!raw) throw new NotFoundException(`Training ${id} not found`);
    return this.repo.remove(raw);
  }
}
