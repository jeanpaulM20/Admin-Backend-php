import { Controller, Get, Post, Put, Delete, Param, Body, Query, ParseIntPipe } from '@nestjs/common';
import { MetricService } from './metric.service';
import { Metric } from '../entities/metric.entity';

@Controller('api/metric')
export class MetricController {
  constructor(private readonly service: MetricService) {}

  @Get()
  findAll(@Query('client_id') clientId?: number) {
    return this.service.findAll(clientId ? +clientId : undefined);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() body: Partial<Metric>) {
    return this.service.create(body);
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() body: Partial<Metric>) {
    return this.service.update(id, body);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
