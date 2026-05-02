import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PerformanceTest } from '../entities/performance-test.entity';

@Injectable()
export class PerformanceTestService {
  constructor(
    @InjectRepository(PerformanceTest)
    private readonly repo: Repository<PerformanceTest>,
  ) {}

  findAll(clientId?: number) {
    const where: any = {};
    if (clientId) where.client_id = clientId;
    return this.repo.find({ where, order: { date: 'DESC' } });
  }

  findOne(id: number) {
    return this.repo.findOneBy({ id });
  }

  create(data: Partial<PerformanceTest>) {
    // Flutter add-dialog doesn't send a date — default to now
    if (!data.date) {
      data.date = new Date().toISOString().slice(0, 19).replace('T', ' ');
    }
    return this.repo.save(this.repo.create(data));
  }

  async update(id: number, data: Partial<PerformanceTest>) {
    await this.repo.update(id, data);
    return this.findOne(id);
  }

  async remove(id: number) {
    const m = await this.repo.findOneBy({ id });
    if (!m) return null;
    return this.repo.remove(m);
  }
}
