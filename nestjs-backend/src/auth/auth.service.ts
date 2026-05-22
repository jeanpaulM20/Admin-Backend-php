import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { createHash } from 'crypto';
import { Trainer } from '../entities/trainer.entity';
import { Clientaccesstoken } from '../entities/client-access-token.entity';

const AUTH_SALT = process.env.AUTH_SALT ?? 'sKLUIE7dfwo4hn23l;idfj[028325p*^&)(op';

/** Cache TTL: rebuild trainer token map every 60 seconds */
const CACHE_TTL_MS = 60_000;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  /** Cached map of md5-token → trainer */
  private trainerTokenMap = new Map<string, Trainer>();
  private cacheBuiltAt = 0;

  constructor(
    @InjectRepository(Trainer)
    private readonly trainerRepo: Repository<Trainer>,
    @InjectRepository(Clientaccesstoken)
    private readonly tokenRepo: Repository<Clientaccesstoken>,
  ) {}

  /**
   * Build or refresh the trainer token cache.
   * Instead of loading ALL trainers on EVERY request, we load them once
   * and keep a Map<hashedToken, Trainer> that is refreshed every 60s.
   */
  private async ensureTrainerCache(): Promise<void> {
    const now = Date.now();
    if (now - this.cacheBuiltAt < CACHE_TTL_MS && this.trainerTokenMap.size > 0) {
      return; // Cache is still fresh
    }

    try {
      const trainers = await this.trainerRepo
        .createQueryBuilder('trainer')
        .addSelect('trainer.passcode')
        .where('trainer.active = :active', { active: 1 })
        .orderBy('trainer.id', 'ASC')
        .getMany();

      const newMap = new Map<string, Trainer>();
      for (const trainer of trainers) {
        const token = createHash('md5').update(AUTH_SALT + trainer.passcode).digest('hex');
        delete (trainer as any).passcode;
        newMap.set(token, trainer);
      }

      this.trainerTokenMap = newMap;
      this.cacheBuiltAt = now;
    } catch (e) {
      this.logger.error('Failed to build trainer token cache', e);
      // Keep existing cache on error
    }
  }

  /** Invalidate cache (call after trainer passcode changes) */
  invalidateCache(): void {
    this.cacheBuiltAt = 0;
  }

  async validateToken(token: string): Promise<{ trainer?: Trainer; client?: any } | null> {
    // Check trainer auth: token = md5(salt + passcode), cached
    await this.ensureTrainerCache();

    const trainer = this.trainerTokenMap.get(token);
    if (trainer) {
      return { trainer };
    }

    // Check client auth: token stored in tbl_client_access_token
    const accessToken = await this.tokenRepo.findOne({
      where: { token },
      relations: ['client'],
    });
    if (accessToken?.client?.active) {
      return { client: accessToken.client };
    }

    return null;
  }
}
