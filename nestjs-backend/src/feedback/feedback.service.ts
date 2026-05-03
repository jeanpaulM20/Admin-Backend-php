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

  async findByClient(clientId?: number) {
    const where: any = {};
    if (clientId) where.client_id = clientId;
    const rows = await this.repo.find({
      where,
      order: { id: 'ASC' },
    });

    // Add 'align' field for Flutter chat UI:
    // trainer-sent → right, client-sent → left
    // Prefer sender_type column, fall back to read-flag heuristic for legacy data
    return rows.map((r) => {
      const sender = r.sender_type ?? (r.read_trainer === 1 && r.read_client === 0 ? 'trainer' : 'client');
      return {
        ...r,
        sender_type: sender,
        align: sender === 'trainer' ? 'right' : 'left',
        client_name: r.client
          ? `${r.client.firstname ?? ''} ${r.client.lastname ?? ''}`.trim()
          : undefined,
      };
    });
  }

  async findAll() {
    const rows = await this.repo.find({
      relations: ['client'],
      order: { id: 'DESC' },
    });

    return rows.map((r) => {
      const sender = r.sender_type ?? (r.read_trainer === 1 && r.read_client === 0 ? 'trainer' : 'client');
      return {
        ...r,
        sender_type: sender,
        align: sender === 'trainer' ? 'right' : 'left',
        client_name: r.client
          ? `${r.client.firstname ?? ''} ${r.client.lastname ?? ''}`.trim()
          : undefined,
      };
    });
  }

  create(data: Partial<Feedback>) {
    return this.repo.save(this.repo.create(data));
  }

  async markRead(id: number, byClient: boolean) {
    const update = byClient ? { read_client: 1 } : { read_trainer: 1 };
    await this.repo.update(id, update);
    return { success: true };
  }

  async remove(id: number) {
    const feedback = await this.repo.findOne({ where: { id } });
    if (!feedback) throw new NotFoundException();
    return this.repo.remove(feedback);
  }
}
