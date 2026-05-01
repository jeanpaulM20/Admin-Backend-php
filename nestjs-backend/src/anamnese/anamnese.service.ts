import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ClientAnamnese } from '../entities/client-anamnese.entity';

@Injectable()
export class AnamneseService {
  constructor(
    @InjectRepository(ClientAnamnese)
    private readonly repo: Repository<ClientAnamnese>,
  ) {}

  /** Find the single anamnese record for a client */
  findByClient(clientId: number) {
    return this.repo.findOneBy({ client_id: clientId });
  }

  findOne(id: number) {
    return this.repo.findOneBy({ id });
  }

  create(data: Partial<ClientAnamnese>) {
    return this.repo.save(this.repo.create(data));
  }

  async upsertByClient(clientId: number, data: Partial<ClientAnamnese>) {
    const existing = await this.repo.findOneBy({ client_id: clientId });
    if (existing) {
      await this.repo.update(existing.id, data);
      return this.repo.findOneBy({ id: existing.id });
    }
    data.client_id = clientId;
    return this.repo.save(this.repo.create(data));
  }

  async remove(id: number) {
    const m = await this.repo.findOneBy({ id });
    if (!m) return null;
    return this.repo.remove(m);
  }
}
