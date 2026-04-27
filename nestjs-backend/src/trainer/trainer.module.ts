import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Trainer } from '../entities/trainer.entity';
import { TrainerAvailability } from '../entities/trainer-availability.entity';
import { TrainerService } from './trainer.service';
import { TrainerController } from './trainer.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Trainer, TrainerAvailability])],
  providers: [TrainerService],
  controllers: [TrainerController],
  exports: [TrainerService],
})
export class TrainerModule {}
