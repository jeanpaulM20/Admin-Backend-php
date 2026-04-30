import { Controller, Get, Post, Put, Delete, Param, Body, ParseIntPipe } from '@nestjs/common';
import { TrainerService } from './trainer.service';
import { Trainer } from '../entities/trainer.entity';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';

@Controller('api/trainer')
export class TrainerController {
  constructor(private readonly service: TrainerService) {}

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get('me')
  getMe(@CurrentTrainer() trainer: Trainer) {
    return trainer;
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() body: Partial<Trainer>) {
    return this.service.create(body);
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() body: Partial<Trainer>) {
    return this.service.update(id, body);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
