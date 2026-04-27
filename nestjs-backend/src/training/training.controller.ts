import { Controller, Get, Post, Put, Delete, Param, Body, Query, ParseIntPipe } from '@nestjs/common';
import { TrainingService } from './training.service';
import { Training } from '../entities/training.entity';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';
import { CurrentClient } from '../auth/decorators/current-user.decorator';
import { Trainer } from '../entities/trainer.entity';
import { Client } from '../entities/client.entity';

@Controller('api/training')
export class TrainingController {
  constructor(private readonly service: TrainingService) {}

  @Get()
  findAll(
    @CurrentClient() client: Client,
    @CurrentTrainer() trainer: Trainer,
    @Query('client_id') clientId?: number,
    @Query('trainer_id') trainerId?: number,
  ) {
    // Clients only see their own trainings
    if (client) return this.service.findAll(client.id);
    return this.service.findAll(clientId, trainerId ?? trainer?.id);
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
