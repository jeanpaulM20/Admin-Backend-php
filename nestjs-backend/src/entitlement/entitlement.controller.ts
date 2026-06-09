import { Controller, Post, Body, ForbiddenException, BadRequestException } from '@nestjs/common';
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

    const clientId = parseInt(String(body.clientId), 10);
    if (!clientId || clientId <= 0) {
      throw new BadRequestException('Ungültige clientId');
    }

    const months = body.months != null ? Number(body.months) : 1;
    if (!Number.isInteger(months) || months < 1 || months > 120) {
      throw new BadRequestException('months muss eine ganze Zahl zwischen 1 und 120 sein');
    }

    const tier = body.tier ?? 'monthly';
    if (!['monthly', 'yearly'].includes(tier)) {
      throw new BadRequestException('tier muss "monthly" oder "yearly" sein');
    }

    const sub = await this.entitlementService.activateCoaching(clientId, months, tier);
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
