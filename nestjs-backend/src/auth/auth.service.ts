import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { createHash } from 'crypto';
import { Trainer } from '../entities/trainer.entity';
import { Clientaccesstoken } from '../entities/client-access-token.entity';

const AUTH_SALT = process.env.AUTH_SALT ?? 'sKLUIE7dfwo4hn23l;idfj[028325p*^&)(op';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(Trainer)
    private readonly trainerRepo: Repository<Trainer>,
    @InjectRepository(Clientaccesstoken)
    private readonly tokenRepo: Repository<Clientaccesstoken>,
  ) {}

  async validateToken(token: string): Promise<{ trainer?: Trainer; client?: any } | null> {
    // Check trainer auth: token = md5(salt + passcode)
    // Only check active trainers, ordered by id to ensure deterministic matching
    const trainers = await this.trainerRepo
      .createQueryBuilder('trainer')
      .addSelect('trainer.passcode')
      .where('trainer.active = :active', { active: 1 })
      .orderBy('trainer.id', 'ASC')
      .getMany();
    for (const trainer of trainers) {
      const expected = createHash('md5').update(AUTH_SALT + trainer.passcode).digest('hex');
      if (token === expected) {
        delete (trainer as any).passcode;
        return { trainer };
      }
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
