import { Controller, Get, Post, Put, Delete, Param, Body, Query, Res, ParseIntPipe } from '@nestjs/common';
import { Response } from 'express';
import { TrainingService } from './training.service';
import { IcalService } from './ical.service';
import { Training } from '../entities/training.entity';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';
import { CurrentClient } from '../auth/decorators/current-user.decorator';
import { Public } from '../auth/decorators/public.decorator';
import { Trainer } from '../entities/trainer.entity';
import { Client } from '../entities/client.entity';

// Legacy PHP-compatible endpoint: GET /api/getIcal?id=...
@Controller('api/getIcal')
export class IcalLegacyController {
  constructor(private readonly icalService: IcalService) {}

  @Public()
  @Get()
  async getIcal(
    @Query('id', ParseIntPipe) id: number,
    @Res() res: Response,
  ) {
    const ical = await this.icalService.generateIcal(id);
    res.set({
      'Content-Type': 'text/calendar; charset=utf-8',
      'Content-Disposition': `attachment; filename="Appointment.ics"`,
    });
    res.send(ical);
  }
}

@Controller('api/training')
export class TrainingController {
  constructor(
    private readonly service: TrainingService,
    private readonly icalService: IcalService,
  ) {}

  @Get()
  findAll(
    @CurrentClient() client: Client,
    @CurrentTrainer() trainer: Trainer,
    @Query('client_id') clientId?: number,
    @Query('trainer_id') trainerId?: number,
    @Query('date_from') dateFrom?: string,
    @Query('date_to') dateTo?: string,
  ) {
    // Clients only see their own trainings
    if (client) return this.service.findAll(client.id, undefined, dateFrom, dateTo);
    return this.service.findAll(clientId, trainerId ?? trainer?.id, dateFrom, dateTo);
  }

  // ── iCal download ────────────────────────────────────────────────────────
  @Public()
  @Get(':id/ical')
  async getIcal(
    @Param('id', ParseIntPipe) id: number,
    @Res() res: Response,
  ) {
    const ical = await this.icalService.generateIcal(id);
    res.set({
      'Content-Type': 'text/calendar; charset=utf-8',
      'Content-Disposition': `attachment; filename="training-${id}.ics"`,
    });
    res.send(ical);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() body: Partial<Training>) {
    return this.service.create(body);
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() body: Partial<Training>) {
    return this.service.update(id, body);
  }

  @Post(':id/cancel')
  cancel(@Param('id', ParseIntPipe) id: number) {
    return this.service.cancel(id);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
