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

  async createSerial(params: {
    trainerId?: number;
    from: string;
    to?: string;
    rStart: string;
    rEnd: string;
    days: number[];
    locationId?: number;
  }) {
    const { trainerId, from, to, rStart, rEnd, days, locationId } = params;
    const start = new Date(rStart);
    const end = new Date(rEnd);
    const created: TrainerAvailability[] = [];

    for (const d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      const dayOfWeek = d.getDay() === 0 ? 7 : d.getDay(); // 1=Mon … 7=Sun
      if (days.includes(dayOfWeek)) {
        const dateStr = d.toISOString().slice(0, 10);
        const entry = this.repo.create({
          trainerId,
          locationId,
          date: dateStr,
          from,
          to,
        });
        created.push(await this.repo.save(entry));
      }
    }

    return { created: created.length, entries: created };
  }
}
