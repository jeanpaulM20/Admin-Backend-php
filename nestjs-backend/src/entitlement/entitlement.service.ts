import { Injectable, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CoachingSubscription } from '../entities/coaching-subscription.entity';

/**
 * Enriched subscription state — single source for the client-app state machine.
 * The frontend derives all UI (banner / popup / lock) from this, no date math.
 */
export interface SubscriptionState {
  active: boolean;
  tier: string | null;          // 'trial' | 'monthly' | 'yearly' | null
  validFrom: string | null;
  validTo: string | null;
  daysLeft: number | null;
  isTrial: boolean;
  trialUsed: boolean;           // has ever used the one-time free trial
  canStartTrial: boolean;       // !active && !trialUsed
  expiringSoon: boolean;        // active && daysLeft <= EXPIRY_WARNING_DAYS
}

/**
 * Single source of truth for online-coaching entitlement.
 * Reads subscription state; the transactional write lives in the purchase
 * flow (must be atomic with credits + invoice).
 */
@Injectable()
export class EntitlementService {
  /** Show the "expires soon" warning when this many days remain. */
  static readonly EXPIRY_WARNING_DAYS = 7;

  private static readonly TZ = 'Europe/Zurich';

  constructor(
    @InjectRepository(CoachingSubscription)
    private readonly subRepo: Repository<CoachingSubscription>,
  ) {}

  private swissToday(): string {
    return new Date().toLocaleDateString('en-CA', { timeZone: EntitlementService.TZ });
  }

  /** Newest active, non-expired subscription for a client (or null). */
  async getActiveSubscription(clientId: number): Promise<CoachingSubscription | null> {
    const rows = await this.subRepo
      .createQueryBuilder('s')
      .where('s.clientId = :clientId', { clientId })
      .andWhere('s.status = :status', { status: 'active' })
      .andWhere('s.validTo >= :today', { today: this.swissToday() })
      .orderBy('s.validTo', 'DESC')
      .limit(1)
      .getMany();
    return rows[0] ?? null;
  }

  async hasActiveSubscription(clientId: number): Promise<boolean> {
    return (await this.getActiveSubscription(clientId)) !== null;
  }

  /** Whether the client has ever used the one-time free trial. */
  async hasUsedTrial(clientId: number): Promise<boolean> {
    const count = await this.subRepo.count({ where: { clientId, tier: 'trial' } });
    return count > 0;
  }

  /** Whole days from Swiss "today" until a YYYY-MM-DD date (UTC-anchored, DST-safe). */
  private daysUntil(dateStr: string): number {
    const target = String(dateStr).slice(0, 10);
    const a = Date.parse(this.swissToday() + 'T00:00:00Z');
    const b = Date.parse(target + 'T00:00:00Z');
    if (Number.isNaN(b)) return 0;
    return Math.round((b - a) / 86_400_000);
  }

  /**
   * Single source of truth for the client-app subscription state machine.
   * Returns everything the frontend needs — no date math on the client.
   */
  async getStatus(clientId: number): Promise<SubscriptionState> {
    const sub = await this.getActiveSubscription(clientId);
    const trialUsed = await this.hasUsedTrial(clientId);

    if (!sub) {
      return {
        active: false,
        tier: null,
        validFrom: null,
        validTo: null,
        daysLeft: null,
        isTrial: false,
        trialUsed,
        canStartTrial: !trialUsed,
        expiringSoon: false,
      };
    }

    const daysLeft = this.daysUntil(sub.validTo);
    return {
      active: true,
      tier: sub.tier,
      validFrom: sub.validFrom,
      validTo: sub.validTo,
      daysLeft,
      isTrial: sub.tier === 'trial',
      trialUsed,
      canStartTrial: false,
      expiringSoon: daysLeft <= EntitlementService.EXPIRY_WARNING_DAYS,
    };
  }

  /**
   * Manually activate coaching for a client (trainer-only, no payment required).
   * Deactivates any existing active subscription first to avoid duplicate rows.
   * Uses day-clamped month arithmetic to avoid JS Date overflow (e.g. Jan 31 + 1).
   */
  async activateCoaching(
    clientId: number,
    months = 1,
    tier = 'monthly',
  ): Promise<CoachingSubscription> {
    // Deactivate any existing active subscription for this client
    await this.subRepo.update(
      { clientId, status: 'active' },
      { status: 'cancelled' },
    );

    const today = this.swissToday();

    // Month-end safe arithmetic: compute validTo by working directly with
    // the current Date in Swiss time (not by re-parsing the YYYY-MM-DD string,
    // which would anchor to UTC midnight and may land on the wrong calendar day).
    const now = new Date();
    const startDay = parseInt(today.split('-')[2], 10);
    const targetDate = new Date(now);
    targetDate.setDate(1); // step to 1st to avoid overflow during month addition
    targetDate.setMonth(targetDate.getMonth() + months);
    // Clamp to last day of target month if start day exceeds it
    const lastDayOfTarget = new Date(
      targetDate.getFullYear(),
      targetDate.getMonth() + 1,
      0,
    ).getDate();
    targetDate.setDate(Math.min(startDay, lastDayOfTarget));
    const validTo = targetDate.toLocaleDateString('en-CA', {
      timeZone: EntitlementService.TZ,
    });

    const sub = this.subRepo.create({
      clientId,
      tier,
      status: 'active',
      validFrom: today,
      validTo,
    });
    return this.subRepo.save(sub);
  }

  /**
   * Activate the one-time free trial (1 month, no payment).
   * Self-service from the client app — guarded so it can only be used once
   * and not while another subscription is already active.
   */
  async activateTrial(clientId: number): Promise<CoachingSubscription> {
    if (await this.hasUsedTrial(clientId)) {
      throw new ConflictException('Test-Abo wurde bereits genutzt');
    }
    if (await this.hasActiveSubscription(clientId)) {
      throw new ConflictException('Es besteht bereits ein aktives Abo');
    }
    return this.activateCoaching(clientId, 1, 'trial');
  }

  /**
   * Cancel all active subscriptions for a client (trainer/admin tooling —
   * refunds, mistakes, resetting a test account). Returns rows affected.
   */
  async deactivateCoaching(clientId: number): Promise<number> {
    const res = await this.subRepo.update(
      { clientId, status: 'active' },
      { status: 'cancelled' },
    );
    return res.affected ?? 0;
  }

  /** Whether a client may see FULL plan content — only with an active subscription. */
  async canAccessPlanFully(clientId: number): Promise<boolean> {
    return this.hasActiveSubscription(clientId);
  }
}
