import { Injectable, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, EntityManager } from 'typeorm';
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
    // Independent reads — run in parallel (one round-trip instead of two).
    const [sub, trialUsed] = await Promise.all([
      this.getActiveSubscription(clientId),
      this.hasUsedTrial(clientId),
    ]);

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
   * Compute a subscription period [validFrom, validTo] in Swiss calendar time.
   * Month-end safe (Jan 31 + 1 month → Feb 28/29) and timezone-safe: all
   * arithmetic is done on the Swiss Y-M-D components via UTC Date (no server-TZ
   * leakage). Single source used by both the manual and the purchase path.
   */
  computePeriod(months: number): { validFrom: string; validTo: string } {
    const validFrom = this.swissToday(); // 'YYYY-MM-DD' in Europe/Zurich
    const [y, m, d] = validFrom.split('-').map(Number);
    // Month arithmetic via Date.UTC handles year rollover; day=1 avoids overflow.
    const target = new Date(Date.UTC(y, m - 1 + months, 1));
    const ty = target.getUTCFullYear();
    const tm = target.getUTCMonth(); // 0-based
    const lastDay = new Date(Date.UTC(ty, tm + 1, 0)).getUTCDate();
    const day = Math.min(d, lastDay); // clamp to month end
    const validTo =
      `${ty}-${String(tm + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    return { validFrom, validTo };
  }

  /**
   * Atomically cancel any existing active subscription and create a new one.
   * Runs inside the caller's transaction (EntityManager) so cancel + insert
   * never leave the client without an active row on partial failure.
   */
  private async writeSubscription(
    mgr: EntityManager,
    clientId: number,
    months: number,
    tier: string,
  ): Promise<CoachingSubscription> {
    await mgr.update(
      CoachingSubscription,
      { clientId, status: 'active' },
      { status: 'cancelled' },
    );
    const { validFrom, validTo } = this.computePeriod(months);
    const sub = mgr.create(CoachingSubscription, {
      clientId,
      tier,
      status: 'active',
      validFrom,
      validTo,
    });
    return mgr.save(sub);
  }

  /**
   * Manually activate coaching for a client (trainer-only, no payment required).
   * Cancel + insert are atomic (single transaction).
   */
  async activateCoaching(
    clientId: number,
    months = 1,
    tier = 'monthly',
  ): Promise<CoachingSubscription> {
    return this.subRepo.manager.transaction((mgr) =>
      this.writeSubscription(mgr, clientId, months, tier),
    );
  }

  /**
   * Activate the one-time free trial (1 month, no payment). Self-service.
   * Guards (trial-once + no active sub) and the write run in ONE transaction
   * with a locking read on the client's rows, so concurrent double-taps can't
   * create two trials/active rows for a client that already has any sub row.
   */
  async activateTrial(clientId: number): Promise<CoachingSubscription> {
    return this.subRepo.manager.transaction(async (mgr) => {
      const rows = await mgr.find(CoachingSubscription, {
        where: { clientId },
        lock: { mode: 'pessimistic_write' },
      });
      const today = this.swissToday();
      if (rows.some((r) => r.tier === 'trial')) {
        throw new ConflictException('Test-Abo wurde bereits genutzt');
      }
      if (rows.some((r) => r.status === 'active' && String(r.validTo).slice(0, 10) >= today)) {
        throw new ConflictException('Es besteht bereits ein aktives Abo');
      }
      return this.writeSubscription(mgr, clientId, 1, 'trial');
    });
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
