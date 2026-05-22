import { Controller, Get, Post, Put, Delete, Param, Body, ParseIntPipe, ForbiddenException, Req } from '@nestjs/common';
import { Request } from 'express';
import { ClientService } from './client.service';
import { FileService } from '../file/file.service';
import { Client } from '../entities/client.entity';
import { Public } from '../auth/decorators/public.decorator';
import { CurrentClient } from '../auth/decorators/current-user.decorator';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';
import { Trainer } from '../entities/trainer.entity';

@Controller('api/client')
export class ClientController {
  constructor(
    private readonly service: ClientService,
    private readonly fileService: FileService,
  ) {}

  /** Ensure caller is the trainer or the client themselves */
  private assertTrainerOrSelf(req: Request, clientId: number): void {
    const trainer = (req as any).currentTrainer;
    if (trainer) return;
    const client = (req as any).currentClient;
    if (!client || client.id !== clientId) {
      throw new ForbiddenException('Zugriff verweigert');
    }
  }

  @Public()
  @Post('token')
  login(@Body() body: any) {
    // Accept both NestJS-style (email/passcode) and PHP-style (e_mail/clientpasscode)
    const email = body.email ?? body.e_mail ?? '';
    const passcode = body.passcode ?? body.clientpasscode ?? '';
    return this.service.loginClient(email, passcode);
  }

  @Get()
  findAll(@CurrentTrainer() trainer: Trainer) {
    if (!trainer) throw new ForbiddenException('Nur Trainer können Clients auflisten');
    return this.service.findAll();
  }

  @Get('me')
  getMe(@CurrentClient() client: Client) {
    return client;
  }

  /** GET /api/client/files/:clientId — files for a client */
  @Get('files/:clientId')
  async getClientFiles(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
  ) {
    this.assertTrainerOrSelf(req, clientId);
    const files = await this.fileService.findByClient(clientId);
    return files.map((f: any) => this.fileService.formatFileForApi(f));
  }

  /** GET /api/client/:id/auto-notify — get auto-notify state */
  @Get(':id/auto-notify')
  getAutoNotify(
    @Req() req: Request,
    @Param('id', ParseIntPipe) id: number,
  ) {
    this.assertTrainerOrSelf(req, id);
    return this.service.getAutoNotify(id);
  }

  /** PUT /api/client/:id/auto-notify — toggle auto-notify { enabled: 0|1 } */
  @Put(':id/auto-notify')
  setAutoNotify(
    @Req() req: Request,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { enabled: number },
  ) {
    this.assertTrainerOrSelf(req, id);
    return this.service.setAutoNotify(id, body.enabled ? 1 : 0);
  }

  @Get(':id')
  findOne(
    @Req() req: Request,
    @Param('id', ParseIntPipe) id: number,
  ) {
    this.assertTrainerOrSelf(req, id);
    return this.service.findOne(id);
  }

  @Post()
  create(
    @CurrentTrainer() trainer: Trainer,
    @Body() body: Partial<Client>,
  ) {
    if (!trainer) throw new ForbiddenException('Nur Trainer können Clients erstellen');
    return this.service.create(body);
  }

  @Put(':id')
  update(
    @CurrentTrainer() trainer: Trainer,
    @Param('id', ParseIntPipe) id: number,
    @Body() body: Partial<Client>,
  ) {
    if (!trainer) throw new ForbiddenException('Nur Trainer können Clients bearbeiten');
    return this.service.update(id, body);
  }

  @Delete(':id')
  remove(
    @CurrentTrainer() trainer: Trainer,
    @Param('id', ParseIntPipe) id: number,
  ) {
    if (!trainer) throw new ForbiddenException('Nur Trainer können Clients löschen');
    return this.service.remove(id);
  }
}
