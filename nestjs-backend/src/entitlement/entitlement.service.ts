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
   * Pure date check — is now inside the free window for a plan?
   * now < publishedAt + FREE_PLAN_ACCESS_DAYS. No DB access, so it can be
   * mapped over a whole plan list cheaply (pair with one hasActiveSubscription).
   */
  isWithinFreeWindow(publishedAt?: Date | string | null): boolean {
    if (!publishedAt) return false;
    const freeUntil = new Date(publishedAt);
    freeUntil.setDate(freeUntil.getDate() + EntitlementService.FREE_PLAN_ACCESS_DAYS);
    return new Date() < freeUntil;
  }

  /**
   * Whether a client may see the FULL plan content: inside the free window
   * (cheap, no query) OR holding an active subscription.
   */
  async canAccessPlanFully(
    clientId: number,
    publishedAt?: Date | string | null,
  ): Promise<boolean> {
    if (this.isWithinFreeWindow(publishedAt)) return true;
    return this.hasActiveSubscription(clientId);
  }
}
