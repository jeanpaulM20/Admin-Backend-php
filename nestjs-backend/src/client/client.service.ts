import { Injectable, NotFoundException, UnauthorizedException, BadRequestException } from '@nestjs/common';
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

  /** Strip fields that clients must never set directly. */
  private sanitizePayload(data: Partial<Client>): Partial<Client> {
    const {
      id, active, clientid, clientpasscode, doorAccess, qrcode, qrcodeStatic,
      qrcodeValidTo, trainers, accessTokens, trainings, metrics, account,
      ...safe
    } = data as any;
    return safe;
  }

  private validatePayload(data: Partial<Client>, requireFields = false) {
    if (requireFields) {
      if (!data.firstname || typeof data.firstname !== 'string' || data.firstname.trim().length === 0) {
        throw new BadRequestException('Vorname ist erforderlich');
      }
      if (!data.lastname || typeof data.lastname !== 'string' || data.lastname.trim().length === 0) {
        throw new BadRequestException('Nachname ist erforderlich');
      }
    }
    if (data.email !== undefined && data.email !== null && data.email !== '') {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(data.email)) {
        throw new BadRequestException('Ungültige E-Mail-Adresse');
      }
    }
  }

  /** Generate next clientid like "K0001", "K0002", etc.
   *  Uses CAST to numeric sort (avoids K9999 > K10000 string ordering bug). */
  private async generateClientId(): Promise<string> {
    const result = await this.clientRepo
      .createQueryBuilder('c')
      .select('c.clientid', 'clientid')
      .where("c.clientid REGEXP '^K[0-9]+$'")
      .orderBy('CAST(SUBSTRING(c.clientid, 2) AS UNSIGNED)', 'DESC')
      .limit(1)
      .getRawOne();

    let nextNum = 1;
    if (result?.clientid) {
      const match = result.clientid.match(/^K(\d+)$/);
      if (match) nextNum = parseInt(match[1], 10) + 1;
    }
    return `K${nextNum.toString().padStart(4, '0')}`;
  }

  async create(data: Partial<Client>) {
    // Map form field names to entity property names
    const mapped: any = { ...data };
    if (mapped.name && !mapped.firstname) { mapped.firstname = mapped.name; delete mapped.name; }
    if (mapped.surname && !mapped.lastname) { mapped.lastname = mapped.surname; delete mapped.surname; }
    if (mapped.e_mail && !mapped.email) { mapped.email = mapped.e_mail; delete mapped.e_mail; }

    const safe = this.sanitizePayload(mapped);
    this.validatePayload(safe, true);

    // Trim name fields
    safe.firstname = safe.firstname!.trim();
    safe.lastname = safe.lastname!.trim();
    if (safe.email) safe.email = safe.email.trim().toLowerCase();

    // Always auto-generate clientid (stripped by sanitize, never user-settable)
    (safe as any).clientid = await this.generateClientId();

    // Check email uniqueness if provided
    if (safe.email) {
      const existing = await this.clientRepo.findOne({ where: { email: safe.email } });
      if (existing) throw new BadRequestException('E-Mail-Adresse ist bereits vergeben');
    }

    try {
      return await this.clientRepo.save(this.clientRepo.create(safe));
    } catch (err: any) {
      if (err?.code === 'ER_DUP_ENTRY' || err?.message?.includes('Duplicate entry')) {
        throw new BadRequestException('E-Mail-Adresse oder Kunden-ID ist bereits vergeben');
      }
      throw err;
    }
  }

  async update(id: number, data: Partial<Client>) {
    const safe = this.sanitizePayload(data);
    this.validatePayload(safe, false);
    if (safe.firstname) safe.firstname = safe.firstname.trim();
    if (safe.lastname) safe.lastname = safe.lastname.trim();
    if (safe.email) safe.email = safe.email.trim().toLowerCase();

    // Check email uniqueness on update
    if (safe.email) {
      const existing = await this.clientRepo.findOne({ where: { email: safe.email } });
      if (existing && existing.id !== id) {
        throw new BadRequestException('E-Mail-Adresse ist bereits vergeben');
      }
    }

    await this.findOne(id);
    try {
      await this.clientRepo.update(id, safe);
    } catch (err: any) {
      if (err?.code === 'ER_DUP_ENTRY' || err?.message?.includes('Duplicate entry')) {
        throw new BadRequestException('E-Mail-Adresse ist bereits vergeben');
      }
      throw err;
    }
    return this.findOne(id);
  }

  async remove(id: number) {
    const client = await this.findOne(id);
    return this.clientRepo.remove(client);
  }

  async getAutoNotify(id: number) {
    const client = await this.clientRepo.findOne({ where: { id }, select: { id: true, auto_training_notify: true } });
    if (!client) throw new NotFoundException(`Client ${id} not found`);
    return { enabled: client.auto_training_notify ?? 0 };
  }

  async setAutoNotify(id: number, enabled: number) {
    await this.clientRepo.update(id, { auto_training_notify: enabled });
    return { enabled };
  }

  // Replaces actionToken() – client login returns an access token
  async login(email: string, passcode: string): Promise<{ token: string }> {
    const client = await this.clientRepo.findOne({
      where: { email, clientpasscode: passcode, active: 1 } as any,
      select: { id: true, firstname: true, lastname: true, active: true, clientpasscode: true },
    });
    if (!client) throw new NotFoundException('Invalid credentials');

    const token = randomBytes(32).toString('hex');
    await this.tokenRepo.save(this.tokenRepo.create({ clientId: client.id, token }));
    return { token };
  }

  /**
   * Client-app login — returns token + client data (matching PHP actionToken response).
   * Supports login by email+passcode or passcode-only (like PHP).
   */
  async loginClient(email: string, passcode: string) {
    const where: any = { active: 1, clientpasscode: passcode };
    if (email) {
      where.email = email;
    }

    const client = await this.clientRepo.findOne({
      where,
      select: {
        id: true, firstname: true, lastname: true, email: true,
        phone: true, picture: true, active: true, clientpasscode: true,
      },
    });
    if (!client) throw new UnauthorizedException('Falsche E-Mail-Adresse oder Passwort.');

    const token = randomBytes(32).toString('hex');
    await this.tokenRepo.save(this.tokenRepo.create({ clientId: client.id, token }));

    return {
      token,
      client: {
        id: client.id,
        firstname: client.firstname,
        lastname: client.lastname,
        email: client.email,
        phone: client.phone,
        photo: client.picture,
      },
    };
  }
}
