import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { randomBytes } from 'crypto';
import { Client } from '../entities/client.entity';
import { Clientaccesstoken } from '../entities/client-access-token.entity';

@Injectable()
export class ClientService {
  constructor(
    @InjectRepository(Client)
    private readonly clientRepo: Repository<Client>,
    @InjectRepository(Clientaccesstoken)
    private readonly tokenRepo: Repository<Clientaccesstoken>,
  ) {}

  findAll() {
    return this.clientRepo.find({ relations: ['trainers'] });
  }

  async findOne(id: number) {
    const client = await this.clientRepo.findOne({
      where: { id },
      relations: ['trainers', 'account'],
    });
    if (!client) throw new NotFoundException(`Client ${id} not found`);
    return client;
  }

  create(data: Partial<Client>) {
    return this.clientRepo.save(this.clientRepo.create(data));
  }

  async update(id: number, data: Partial<Client>) {
    await this.findOne(id);
    await this.clientRepo.update(id, data);
    return this.findOne(id);
  }

  async remove(id: number) {
    const client = await this.findOne(id);
    return this.clientRepo.remove(client);
  }

  // Replaces actionToken() – client login returns an access token
  async login(email: string, passcode: string): Promise<{ token: string }> {
    const client = await this.clientRepo.findOne({
      where: { email, clientpasscode: passcode, active: 1 } as any,
    });
    if (!client) throw new NotFoundException('Invalid credentials');

    const token = randomBytes(32).toString('hex');
    await this.tokenRepo.save(this.tokenRepo.create({ clientId: client.id, token }));
    return { token };
  }
}
