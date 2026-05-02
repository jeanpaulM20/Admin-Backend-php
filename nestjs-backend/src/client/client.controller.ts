import { Controller, Get, Post, Put, Delete, Param, Body, ParseIntPipe } from '@nestjs/common';
import { ClientService } from './client.service';
import { Client } from '../entities/client.entity';
import { Public } from '../auth/decorators/public.decorator';
import { CurrentClient } from '../auth/decorators/current-user.decorator';

@Controller('api/client')
export class ClientController {
  constructor(private readonly service: ClientService) {}

  @Public()
  @Post('token')
  login(@Body() body: { email: string; passcode: string }) {
    return this.service.login(body.email, body.passcode);
  }

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get('me')
  getMe(@CurrentClient() client: Client) {
    return client;
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
