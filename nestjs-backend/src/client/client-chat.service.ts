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
   * Includes: trainer info, last message preview, timestamp, unread count.
   */
  async getConversations(clientId: number) {
    // Get all distinct trainer_ids this client has feedback with
    const rows = await this.feedbackRepo
      .createQueryBuilder('f')
      .leftJoinAndSelect('f.trainer', 'trainer')
      .where('f.client_id = :clientId', { clientId })
      .orderBy('f.id', 'DESC')
      .getMany();

    // Group by trainer
    const trainerMap = new Map<number, {
      trainer: any;
      lastMessage: string;
      lastMessageAt: Date | null;
      unreadCount: number;
    }>();

    for (const row of rows) {
      const tid = row.trainer_id;
      if (!tid) continue;

      if (!trainerMap.has(tid)) {
        trainerMap.set(tid, {
          trainer: row.trainer,
          lastMessage: row.text ?? '',
          lastMessageAt: row.created_at ?? null,
          unreadCount: 0,
        });
      }

      // Count unread: trainer-sent messages the client hasn't read yet
      const isTrainerMsg = row.sender_type === 'trainer'
        || (!row.sender_type && row.read_trainer === 1 && row.read_client === 0);
      if (isTrainerMsg && row.read_client === 0) {
        trainerMap.get(tid)!.unreadCount++;
      }
    }

    // Also include assigned trainers with no messages yet
    const client = await this.clientRepo.findOne({
      where: { id: clientId },
      relations: ['trainers'],
    });
    if (client?.trainers) {
      for (const trainer of client.trainers) {
        if (!trainerMap.has(trainer.id)) {
          trainerMap.set(trainer.id, {
            trainer,
            lastMessage: '',
            lastMessageAt: null,
            unreadCount: 0,
          });
        }
      }
    }

    return Array.from(trainerMap.entries()).map(([, conv]) => ({
      trainer_id: conv.trainer?.id ?? 0,
      trainer_name: conv.trainer
        ? `${conv.trainer.firstname ?? ''} ${conv.trainer.lastname ?? ''}`.trim()
        : 'Trainer',
      trainer_picture: conv.trainer?.picture ?? null,
      last_message: conv.lastMessage,
      last_message_at: conv.lastMessageAt,
      unread_count: conv.unreadCount,
    }));
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
