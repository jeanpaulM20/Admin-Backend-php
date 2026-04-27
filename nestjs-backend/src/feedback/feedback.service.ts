import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Feedback } from '../entities/feedback.entity';

@Injectable()
export class FeedbackService {
  constructor(
    @InjectRepository(Feedback)
    private readonly repo: Repository<Feedback>,
  ) {}

  findByClient(clientId: number) {
    return this.repo.find({
      where: { clientId },
      relations: ['trainer'],
      order: { createdAt: 'DESC' },
    });
  }

  create(data: Partial<Feedback>) {
    return this.repo.save(this.repo.create(data));
  }

  async markRead(id: number) {
    await this.repo.update(id, { read: 1 });
  }

  async remove(id: number) {
    const feedback = await this.repo.findOne({ where: { id } });
    if (!feedback) throw new NotFoundException();
    return this.repo.remove(feedback);
  }
}
