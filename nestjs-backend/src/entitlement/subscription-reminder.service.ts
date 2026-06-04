import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { CoachingSubscription } from '../entities/coaching-subscription.entity';
import { PushService } from '../push/push.service';
import { RealtimeService } from '../realtime/realtime.service';

/**
 * Sends "your coaching expires soon" reminders.
 * Runs daily at 08:00 Swiss time. A subscription is reminded once when
 * fewer than REMIND_DAYS days remain; last_reminded_at prevents duplicates.
 *
 * Delivery channels:
 *  1. Persistent chat message (visible offline + later)
 *  2. Web push (instant)
 *  3. SSE realtime ping (open client app updates)
 */
@Injectable()
export class SubscriptionReminderService {
  private readonly logger = new Logger(SubscriptionReminderService.name);

  /** Send reminder when fewer than this many days remain. */
  static readonly REMIND_DAYS = 7;

  constructor(
    @InjectRepository(CoachingSubscription)
    private readonly subRepo: Repository<CoachingSubscription>,
    private readonly dataSource: DataSource,
    private readonly pushService: PushService,
    private readonly realtime: RealtimeService,
  ) {}

  /** Daily at 08:00 Europe/Zurich. */
  @Cron('0 8 * * *', { timeZone: 'Europe/Zurich' })
  async runDaily() {
    try {
      const sent = await this.sendDueReminders();
      this.logger.log(`Subscription reminders sent: ${sent}`);
    } catch (err: any) {
      this.logger.error(`Reminder run failed: ${err.message}`, err.stack);
    }
  }

  /**
   * Core logic, separated so it can be invoked manually for testing.
   * Returns the number of reminders dispatched.
   */
  async sendDueReminders(): Promise<number> {
    // Active subs with <= REMIND_DAYS remaining AND not reminded in the last 24h
    const rows: CoachingSubscription[] = await this.subRepo
      .createQueryBuilder('s')
      .where('s.status = :status', { status: 'active' })
      .andWhere(
        'DATEDIFF(s.validTo, CURDATE()) BETWEEN 0 AND :days',
        { days: SubscriptionReminderService.REMIND_DAYS },
      )
      .andWhere(
        '(s.lastRemindedAt IS NULL OR s.lastRemindedAt < (NOW() - INTERVAL 1 DAY))',
      )
      .getMany();

    let sent = 0;
    for (const sub of rows) {
      try {
        await this.sendReminder(sub);
        await this.subRepo.update(sub.id, { lastRemindedAt: new Date() });
        sent++;
      } catch (err: any) {
        this.logger.warn(`Reminder for sub ${sub.id} failed: ${err.message}`);
      }
    }
    return sent;
  }

  private async sendReminder(sub: CoachingSubscription): Promise<void> {
    const daysLeft = Math.max(
      0,
      Math.ceil(
        (new Date(sub.validTo).getTime() - Date.now()) / (1000 * 60 * 60 * 24),
      ),
    );

    const title = 'Online Coaching läuft bald ab';
    const body = daysLeft === 0
      ? 'Dein Coaching endet heute. Verlängere jetzt, um nahtlos weiterzutrainieren.'
      : `Dein Coaching endet in ${daysLeft} ${daysLeft === 1 ? 'Tag' : 'Tagen'}. Verlängere jetzt.`;

    // 1. Persistent system chat message via assigned trainers
    const trainerRows: { trainer_id: number }[] = await this.dataSource.query(
      'SELECT trainer_id FROM trainer_client WHERE client_id = ?',
      [sub.clientId],
    );
    for (const t of trainerRows) {
      try {
        await this.dataSource.query(
          `INSERT INTO feedback (client_id, trainer_id, text, sender_type, is_circle,
            read_client, read_trainer, created_at)
           VALUES (?, ?, ?, 'trainer', 1, 0, 1, NOW())`,
          [sub.clientId, t.trainer_id, `⏳ ${body}`],
        );
      } catch (err: any) {
        this.logger.warn(`Chat insert failed: ${err.message}`);
      }
    }

    // 2. Web push (instant)
    this.pushService
      .sendToClient(sub.clientId, { title, body, url: '/client/' })
      .catch((err) =>
        this.logger.warn(`Push for client ${sub.clientId}: ${err.message}`),
      );

    // 3. SSE realtime ping (live update for open client app)
    this.realtime.emitToClient(sub.clientId, 'subscription_expiring', {
      daysLeft,
      validTo: sub.validTo,
    });

    this.logger.log(
      `Reminder sent to client ${sub.clientId} (sub ${sub.id}, ${daysLeft}d left)`,
    );
  }
}
