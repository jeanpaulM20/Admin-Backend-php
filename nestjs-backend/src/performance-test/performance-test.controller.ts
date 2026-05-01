import { Controller, Get, Post, Put, Delete, Param, Body, Query, ParseIntPipe } from '@nestjs/common';
import { PerformanceTestService } from './performance-test.service';
import { PerformanceTest } from '../entities/performance-test.entity';

@Controller('api/performance_test')
export class PerformanceTestController {
  constructor(private readonly service: PerformanceTestService) {}

  @Get()
  findAll(@Query('client_id') clientId?: number) {
    return this.service.findAll(clientId ? +clientId : undefined);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() body: Partial<PerformanceTest>) {
    return this.service.create(body);
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() body: Partial<PerformanceTest>) {
    return this.service.update(id, body);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
