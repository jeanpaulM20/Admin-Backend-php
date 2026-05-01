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

  create(data: Partial<ClientAnamnese>) {
    return this.repo.save(this.repo.create(data));
  }

  async upsertByClient(clientId: number, data: Partial<ClientAnamnese>) {
    const existing = await this.repo.findOneBy({ client_id: clientId });
    if (existing) {
      // Merge incoming data with existing, then save
      Object.assign(existing, data);
      existing.client_id = clientId;
      return this.repo.save(existing);
    }
    data.client_id = clientId;
    return this.repo.save(this.repo.create(data));
  }

  async remove(clientId: number) {
    const m = await this.repo.findOneBy({ client_id: clientId });
    if (!m) return null;
    return this.repo.remove(m);
  }
}
