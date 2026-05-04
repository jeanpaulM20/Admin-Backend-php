import { Controller, Get, Post, Put, Delete, Param, Body, ParseIntPipe } from '@nestjs/common';
import { ClientService } from './client.service';
import { FileService } from '../file/file.service';
import { Client } from '../entities/client.entity';
import { Public } from '../auth/decorators/public.decorator';
import { CurrentClient } from '../auth/decorators/current-user.decorator';

@Controller('api/client')
export class ClientController {
  constructor(
    private readonly service: ClientService,
    private readonly fileService: FileService,
  ) {}

  @Public()
  @Post('token')
  login(@Body() body: any) {
    // Accept both NestJS-style (email/passcode) and PHP-style (e_mail/clientpasscode)
    const email = body.email ?? body.e_mail ?? '';
    const passcode = body.passcode ?? body.clientpasscode ?? '';
    return this.service.loginClient(email, passcode);
  }

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get('me')
  getMe(@CurrentClient() client: Client) {
    return client;
  }

  /** GET /api/client/files/:clientId — files for a client (used by client Flutter app) */
  @Get('files/:clientId')
  async getClientFiles(@Param('clientId', ParseIntPipe) clientId: number) {
    const files = await this.fileService.findByClient(clientId);
    const mapped = files.map((f: any) => ({
      id: f.id,
      name: f.name,
      date: f.date,
      file: f.file ? `/api/file/${f.id}/download` : null,
      client_id: f.client_id,
      _handler: 'getClientFiles',
    }));
    return mapped;
  }

  /** GET /api/client/:id/auto-notify — get auto-notify state */
  @Get(':id/auto-notify')
  getAutoNotify(@Param('id', ParseIntPipe) id: number) {
    return this.service.getAutoNotify(id);
  }

  /** PUT /api/client/:id/auto-notify — toggle auto-notify { enabled: 0|1 } */
  @Put(':id/auto-notify')
  setAutoNotify(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { enabled: number },
  ) {
    return this.service.setAutoNotify(id, body.enabled ? 1 : 0);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() body: Partial<Client>) {
    return this.service.create(body);
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() body: Partial<Client>) {
    return this.service.update(id, body);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
