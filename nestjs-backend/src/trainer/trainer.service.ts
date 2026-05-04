import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Trainer } from '../entities/trainer.entity';

@Injectable()
export class TrainerService {
  constructor(
    @InjectRepository(Trainer)
    private readonly repo: Repository<Trainer>,
  ) {}

  findAll() {
    return this.repo.find({ relations: ['locations'] });
  }

  async findOne(id: number) {
    const trainer = await this.repo.findOne({ where: { id }, relations: ['locations', 'availabilities'] });
    if (!trainer) throw new NotFoundException(`Trainer ${id} not found`);
    return trainer;
  }

  create(data: Partial<Trainer>) {
    return this.repo.save(this.repo.create(data));
  }

  async update(id: number, data: Partial<Trainer>) {
    await this.findOne(id);
    await this.repo.update(id, data);
    return this.findOne(id);
  }

  async remove(id: number) {
    const trainer = await this.findOne(id);
    return this.repo.remove(trainer);
  }

  async updatePasscode(id: number, newPasscode: string) {
    await this.repo
      .createQueryBuilder()
      .update(Trainer)
      .set({ passcode: newPasscode })
      .where('id = :id', { id })
      .execute();
  }
}
