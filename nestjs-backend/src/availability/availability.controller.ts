import { Controller, Get, Post, Put, Delete, Param, Body, Query, ParseIntPipe } from '@nestjs/common';
import { AvailabilityService } from './availability.service';
import { TrainerAvailability } from '../entities/trainer-availability.entity';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';
import { Trainer } from '../entities/trainer.entity';

@Controller('api/trainer-availability')
export class AvailabilityController {
  constructor(private readonly service: AvailabilityService) {}

  @Get()
  findAll(
    @CurrentTrainer() trainer: Trainer,
    @Query('trainer_id') trainerId?: number,
  ) {
    return this.service.findAll(trainer?.id ?? (trainerId ? +trainerId : undefined));
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post('serial')
  createSerial(
    @CurrentTrainer() trainer: Trainer,
    @Body() body: {
      trainerId?: number;
      from: string;
      to?: string;
      rStart: string;
      rEnd: string;
      days: number[];
      locationId?: number;
      trainingTypeId?: number;
    },
  ) {
    const resolvedTrainerId = trainer?.id ?? body.trainerId;
    return this.service.createSerial({ ...body, trainerId: resolvedTrainerId });
  }

  @Post()
  create(
    @CurrentTrainer() trainer: Trainer,
    @Body() body: Partial<TrainerAvailability>,
  ) {
    // Trainer aus dem Token gewinnt — sonst könnte ein eingeloggter
    // Trainer Slots auf fremde Kalender schreiben (wie bei createSerial)
    return this.service.create({ ...body, trainerId: trainer?.id ?? body.trainerId });
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() body: Partial<TrainerAvailability>) {
    return this.service.update(id, body);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
