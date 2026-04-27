import { Controller, Get, Post, Put, Delete, Param, Body, Query, ParseIntPipe } from '@nestjs/common';
import { TrainingPlanService } from './training-plan.service';
import { TrainingPlan } from '../entities/training-plan.entity';
import { CurrentClient } from '../auth/decorators/current-user.decorator';
import { Client } from '../entities/client.entity';

@Controller('api/trainingplan')
export class TrainingPlanController {
  constructor(private readonly service: TrainingPlanService) {}

  @Get()
  findAll(@CurrentClient() client: Client, @Query('client_id') clientId?: number) {
    return this.service.findAll(client?.id ?? clientId);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() body: Partial<TrainingPlan>) {
    return this.service.create(body);
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() body: Partial<TrainingPlan>) {
    return this.service.update(id, body);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
