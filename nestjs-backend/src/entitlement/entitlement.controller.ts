import { Controller, Post, Body, ForbiddenException } from '@nestjs/common';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';
import { Trainer } from '../entities/trainer.entity';
import { EntitlementService } from './entitlement.service';
import { SubscriptionReminderService } from './subscription-reminder.service';

/**
 * Admin endpoints for subscription management.
 * All endpoints require a trainer token.
 */
@Controller('api/entitlement')
export class EntitlementController {
  constructor(
    private readonly entitlementService: EntitlementService,
    private readonly reminder: SubscriptionReminderService,
  ) {}

  /**
   * POST /api/entitlement/activate
   * Manually activate online coaching for a client (no payment required).
   * Body: { clientId: number, months?: number, tier?: 'monthly' | 'yearly' }
   */
  @Post('activate')
  async activate(
    @CurrentTrainer() trainer: Trainer,
    @Body() body: { clientId: number; months?: number; tier?: string },
  ) {
    if (!trainer) {
      throw new ForbiddenException('Nur Trainer können Coaching aktivieren');
    }
    const sub = await this.entitlementService.activateCoaching(
      body.clientId,
      body.months ?? 1,
      body.tier ?? 'monthly',
    );
    return { success: true, sub };
  }

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
