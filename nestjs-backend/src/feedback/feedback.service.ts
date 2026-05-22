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

  /**
   * Efficient conversation list for trainer: one row per client with last message + unread count.
   * Used by the Nachrichten screen instead of loading ALL messages.
   */
  async getTrainerConversations(trainerId: number) {
    const rows: any[] = await this.repo.query(`
      SELECT
        f.client_id,
        MAX(c.firstname) AS client_firstname,
        MAX(c.lastname) AS client_lastname,
        MAX(f.id) AS last_id,
        SUM(CASE
          WHEN f.read_trainer = 0 AND (f.sender_type = 'client' OR (f.sender_type IS NULL AND f.read_client = 1))
          THEN 1 ELSE 0
        END) AS unread_count
      FROM feedback f
      LEFT JOIN client c ON c.id = f.client_id
      WHERE f.trainer_id = ?
      GROUP BY f.client_id
      ORDER BY last_id DESC
    `, [trainerId]);

    // Fetch last message text for each conversation (avoids correlated subquery issues)
    for (const row of rows) {
      if (row.last_id) {
        const msgRows = await this.repo.query(
          `SELECT text FROM feedback WHERE id = ? LIMIT 1`,
          [row.last_id],
        );
        row.last_message = msgRows?.[0]?.text ?? '';
      } else {
        row.last_message = '';
      }
    }

    return rows.map(r => ({
      client_id: r.client_id,
      client_name: `${r.client_firstname ?? ''} ${r.client_lastname ?? ''}`.trim() || 'Unbekannt',
      last_message: r.last_message ?? '',
      last_id: Number(r.last_id) || 0,
      unread_count: Number(r.unread_count) || 0,
    }));
  }

  create(data: Partial<Feedback>) {
    return this.repo.save(this.repo.create(data));
  }

  async markRead(id: number, byClient: boolean) {
    const update = byClient ? { read_client: 1 } : { read_trainer: 1 };
    await this.repo.update(id, update);
    return { success: true };
  }

  /**
   * Batch mark all unread messages for a client as read by trainer.
   */
  async markAllReadByTrainer(clientId: number) {
    await this.repo
      .createQueryBuilder()
      .update(Feedback)
      .set({ read_trainer: 1 })
      .where('client_id = :clientId AND read_trainer = 0 AND (sender_type = :st OR (sender_type IS NULL AND read_client = 1))', {
        clientId,
        st: 'client',
      })
      .execute();
    return { success: true };
  }

  async remove(id: number) {
    const feedback = await this.repo.findOne({ where: { id } });
    if (!feedback) throw new NotFoundException();
    return this.repo.remove(feedback);
  }
}
