import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CoachingSubscription } from '../entities/coaching-subscription.entity';

/**
 * Single source of truth for online-coaching entitlement.
 * Reads subscription state; the transactional write lives in the purchase
 * flow (must be atomic with credits + invoice).
 */
@Injectable()
export class EntitlementService {
  /**
   * Free plan-access window before a subscription is required.
   * 7 = "erste Woche gratis"; switch to 30 for "erster Monat gratis".
   */
  static readonly FREE_PLAN_ACCESS_DAYS = 7;

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

  /**
   * Whether a client may see the FULL plan content.
   * Phase 2 supplies plan.publishedAt. Until a subscription exists, access
   * is granted only inside the free window: now < publishedAt + FREE_PLAN_ACCESS_DAYS.
   */
  async canAccessPlanFully(
    clientId: number,
    publishedAt?: Date | string | null,
  ): Promise<boolean> {
    if (await this.hasActiveSubscription(clientId)) return true;
    if (!publishedAt) return false;
    const freeUntil = new Date(publishedAt);
    freeUntil.setDate(freeUntil.getDate() + EntitlementService.FREE_PLAN_ACCESS_DAYS);
    return new Date() < freeUntil;
  }
}
