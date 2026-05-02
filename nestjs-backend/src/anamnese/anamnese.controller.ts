import { Controller, Get, Post, Put, Delete, Param, Body, ParseIntPipe, HttpException, HttpStatus } from '@nestjs/common';
import { AnamneseService } from './anamnese.service';
import { ClientAnamnese } from '../entities/remaining.entities';

@Controller('api/anamnese')
export class AnamneseController {
  constructor(private readonly service: AnamneseService) {}

  /** GET /api/anamnese/:clientId — fetch single anamnese by client ID */
  @Get(':clientId')
  async findByClient(@Param('clientId', ParseIntPipe) clientId: number) {
    try {
      const record = await this.service.findByClient(clientId);
      // Return empty object if none exists yet (Flutter treats null/empty as "start fresh")
      return record ?? {};
    } catch (err) {
      throw new HttpException(
        { message: err.message, detail: err.sqlMessage ?? null },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** POST /api/anamnese — create new anamnese */
  @Post()
  async create(@Body() body: Partial<ClientAnamnese>) {
    try {
      return await this.service.create(body);
    } catch (err) {
      throw new HttpException(
        { message: err.message, detail: err.sqlMessage ?? null },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** PUT /api/anamnese/:clientId — update or create anamnese for client */
  @Put(':clientId')
  async update(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: Partial<ClientAnamnese>,
  ) {
    try {
      return await this.service.upsertByClient(clientId, body);
    } catch (err) {
      throw new HttpException(
        { message: err.message, detail: err.sqlMessage ?? null },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** DELETE /api/anamnese/:clientId — delete by client ID */
  @Delete(':clientId')
  remove(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.service.remove(clientId);
  }
}
