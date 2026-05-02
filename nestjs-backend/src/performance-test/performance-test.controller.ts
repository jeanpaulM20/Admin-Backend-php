import { Controller, Get, Post, Put, Delete, Param, Body, Query, ParseIntPipe, HttpException, HttpStatus } from '@nestjs/common';
import { PerformanceTestService } from './performance-test.service';
import { PerformanceTest } from '../entities/remaining.entities';

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
  async create(@Body() body: Partial<PerformanceTest>) {
    try {
      return await this.service.create(body);
    } catch (err) {
      throw new HttpException(
        { message: err.message, detail: err.sqlMessage ?? err.detail ?? null },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Put(':id')
  async update(@Param('id', ParseIntPipe) id: number, @Body() body: Partial<PerformanceTest>) {
    try {
      return await this.service.update(id, body);
    } catch (err) {
      throw new HttpException(
        { message: err.message, detail: err.sqlMessage ?? err.detail ?? null },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
