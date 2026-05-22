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
    // Step 1: Get distinct trainer IDs + aggregates using raw SQL
    let convRows: any[];
    try {
      convRows = await this.feedbackRepo.query(
        `SELECT trainer_id, MAX(id) AS last_id, MAX(created_at) AS last_message_at,
         SUM(CASE WHEN read_client = 0 AND (sender_type = 'trainer' OR (sender_type IS NULL AND read_trainer = 1)) THEN 1 ELSE 0 END) AS unread_count
         FROM feedback WHERE client_id = ? AND trainer_id IS NOT NULL GROUP BY trainer_id ORDER BY last_id DESC`,
        [clientId],
      );
    } catch (e) {
      // Fallback: load all and group in JS (works on any DB)
      return this._getConversationsFallback(clientId);
    }

    // Step 2: Enrich with trainer info and last message text
    const result: any[] = [];
    for (const row of convRows) {
      let trainerName = 'Trainer';
      let trainerPicture: string | null = null;
      let lastMessage = '';

      try {
        const tRows = await this.feedbackRepo.query(
          `SELECT firstname, lastname, picture FROM trainer WHERE id = ? LIMIT 1`,
          [row.trainer_id],
        );
        if (tRows?.[0]) {
          trainerName = `${tRows[0].firstname ?? ''} ${tRows[0].lastname ?? ''}`.trim() || 'Trainer';
          trainerPicture = tRows[0].picture ?? null;
        }
      } catch (_) {}

      if (row.last_id) {
        try {
          const mRows = await this.feedbackRepo.query(
            `SELECT text FROM feedback WHERE id = ? LIMIT 1`,
            [row.last_id],
          );
          lastMessage = mRows?.[0]?.text ?? '';
        } catch (_) {}
      }

      result.push({
        trainer_id: row.trainer_id,
        trainer_name: trainerName,
        trainer_picture: trainerPicture,
        last_message: lastMessage,
        last_message_at: row.last_message_at ?? null,
        unread_count: Number(row.unread_count) || 0,
      });
    }

    const trainerIds = new Set(convRows.map(r => r.trainer_id));

    // Also include assigned trainers with no messages yet
    const client = await this.clientRepo.findOne({
      where: { id: clientId },
      relations: ['trainers'],
    });

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
   * JS-based fallback if raw SQL fails (e.g. SQLite dev environment).
   */
  private async _getConversationsFallback(clientId: number) {
    const rows = await this.feedbackRepo.find({
      where: { client_id: clientId },
      relations: ['trainer'],
      order: { id: 'DESC' },
    });

    const trainerMap = new Map<number, any>();
    for (const row of rows) {
      const tid = row.trainer_id;
      if (!tid) continue;
      if (!trainerMap.has(tid)) {
        trainerMap.set(tid, {
          trainer_id: tid,
          trainer_name: row.trainer ? `${row.trainer.firstname ?? ''} ${row.trainer.lastname ?? ''}`.trim() : 'Trainer',
          trainer_picture: row.trainer?.picture ?? null,
          last_message: row.text ?? '',
          last_message_at: row.created_at ?? null,
          unread_count: 0,
        });
      }
      const isTrainerMsg = row.sender_type === 'trainer' || (!row.sender_type && row.read_trainer === 1 && row.read_client === 0);
      if (isTrainerMsg && row.read_client === 0) {
        trainerMap.get(tid)!.unread_count++;
      }
    }

    const client = await this.clientRepo.findOne({ where: { id: clientId }, relations: ['trainers'] });
    if (client?.trainers) {
      for (const trainer of client.trainers) {
        if (!trainerMap.has(trainer.id)) {
          trainerMap.set(trainer.id, {
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
    return Array.from(trainerMap.values());
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
