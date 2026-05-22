import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Feedback } from '../entities/feedback.entity';
import { Client } from '../entities/client.entity';

@Injectable()
export class ClientChatService {
  constructor(
    @InjectRepository(Feedback) private readonly feedbackRepo: Repository<Feedback>,
    @InjectRepository(Client) private readonly clientRepo: Repository<Client>,
  ) {}

  /**
   * Returns a list of conversations (one per trainer the client has chatted with).
   * Uses SQL aggregation instead of loading all messages into memory.
   */
  async getConversations(clientId: number) {
    // Efficient SQL: get last message + unread count per trainer in one query
    const convRows: any[] = await this.feedbackRepo.query(`
      SELECT
        f.trainer_id,
        MAX(t.firstname) AS trainer_firstname,
        MAX(t.lastname) AS trainer_lastname,
        MAX(t.picture) AS trainer_picture,
        MAX(f.id) AS last_id,
        MAX(f.created_at) AS last_message_at,
        SUM(CASE
          WHEN f.read_client = 0 AND (f.sender_type = 'trainer' OR (f.sender_type IS NULL AND f.read_trainer = 1))
          THEN 1 ELSE 0
        END) AS unread_count
      FROM feedback f
      LEFT JOIN trainer t ON t.id = f.trainer_id
      WHERE f.client_id = ?
      GROUP BY f.trainer_id
      ORDER BY last_id DESC
    `, [clientId]);

    // Fetch last message text for each conversation
    for (const row of convRows) {
      if (row.last_id) {
        const msgRows = await this.feedbackRepo.query(
          `SELECT text FROM feedback WHERE id = ? LIMIT 1`,
          [row.last_id],
        );
        row.last_message = msgRows?.[0]?.text ?? '';
      } else {
        row.last_message = '';
      }
    }

    const trainerIds = new Set(convRows.map(r => r.trainer_id));

    // Also include assigned trainers with no messages yet
    const client = await this.clientRepo.findOne({
      where: { id: clientId },
      relations: ['trainers'],
    });

    const result = convRows.map(row => ({
      trainer_id: row.trainer_id,
      trainer_name: `${row.trainer_firstname ?? ''} ${row.trainer_lastname ?? ''}`.trim() || 'Trainer',
      trainer_picture: row.trainer_picture ?? null,
      last_message: row.last_message ?? '',
      last_message_at: row.last_message_at ?? null,
      unread_count: Number(row.unread_count) || 0,
    }));

    if (client?.trainers) {
      for (const trainer of client.trainers) {
        if (!trainerIds.has(trainer.id)) {
          result.push({
            trainer_id: trainer.id,
            trainer_name: `${trainer.firstname ?? ''} ${trainer.lastname ?? ''}`.trim() || 'Trainer',
            trainer_picture: trainer.picture ?? null,
            last_message: '',
            last_message_at: null,
            unread_count: 0,
          });
        }
      }
    }

    return result;
  }

  /**
   * Returns all messages for a client-trainer conversation, oldest first.
   */
  async getMessages(clientId: number, trainerId: number) {
    const rows = await this.feedbackRepo.find({
      where: { client_id: clientId, trainer_id: trainerId },
      order: { id: 'ASC' },
    });

    return rows.map((row) => ({
      id: row.id,
      text: row.text ?? '',
      // Prefer explicit sender_type column; fall back to read-flag heuristic for legacy data
      sender_type: row.sender_type
        ?? (row.read_trainer === 1 && row.read_client === 0 ? 'trainer' : 'client'),
      created_at: row.created_at ?? null,
      read_client: row.read_client,
      read_trainer: row.read_trainer,
    }));
  }

  /**
   * Client sends a message to a trainer.
   */
  async sendMessage(clientId: number, trainerId: number, text: string) {
    // Sanitize: trim whitespace and enforce max length (5000 chars)
    const sanitized = (text ?? '').trim().slice(0, 5000);
    if (!sanitized) {
      throw new Error('Nachricht darf nicht leer sein');
    }

    const msg = this.feedbackRepo.create({
      client_id: clientId,
      trainer_id: trainerId,
      text: sanitized,
      sender_type: 'client',
      read_client: 1,   // Client has seen their own message
      read_trainer: 0,   // Trainer hasn't read it yet
      is_circle: 0,
    });
    const saved = await this.feedbackRepo.save(msg);
    return {
      id: saved.id,
      text: saved.text,
      sender_type: 'client',
      created_at: saved.created_at ?? new Date(),
      read_client: saved.read_client,
      read_trainer: saved.read_trainer,
    };
  }

  /**
   * Mark all unread messages from trainer as read by client.
   * Handles both new rows (sender_type = 'trainer') and legacy rows (no sender_type, inferred from read flags).
   */
  async markAsRead(clientId: number, trainerId: number) {
    await this.feedbackRepo
      .createQueryBuilder()
      .update(Feedback)
      .set({ read_client: 1 })
      .where('client_id = :clientId AND trainer_id = :trainerId AND read_client = 0 AND (sender_type = :st OR (sender_type IS NULL AND read_trainer = 1))', {
        clientId,
        trainerId,
        st: 'trainer',
      })
      .execute();
    return { success: true };
  }
}
