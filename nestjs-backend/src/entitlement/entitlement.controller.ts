import { Controller, Post, ForbiddenException } from '@nestjs/common';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';
import { Trainer } from '../entities/trainer.entity';
import { SubscriptionReminderService } from './subscription-reminder.service';

/**
 * Admin endpoints for the subscription reminder cron. Lets ops/trainers
 * trigger a reminder run manually (e.g. for testing the chain) without
 * waiting for the daily 08:00 schedule.
 */
@Controller('api/entitlement')
export class EntitlementController {
  constructor(private readonly reminder: SubscriptionReminderService) {}

  /** POST /api/entitlement/reminders/run — manually dispatch due reminders. */
  @Post('reminders/run')
  async runReminders(@CurrentTrainer() trainer: Trainer) {
    if (!trainer) {
      throw new ForbiddenException('Nur Trainer können den Reminder-Run auslösen');
    }
    const sent = await this.reminder.sendDueReminders();
    return { success: true, sent };
  }
}
