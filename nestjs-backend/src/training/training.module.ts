import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Training } from '../entities/training.entity';
import { TrainingType } from '../entities/training-type.entity';
import { Location } from '../entities/location.entity';
import { TrainingPlan } from '../entities/training-plan.entity';
import { TrainingService } from './training.service';
import { IcalService } from './ical.service';
import { TrainingController } from './training.controller';
import { PushModule } from '../push/push.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Training, TrainingType, Location, TrainingPlan]),
    PushModule,
  ],
  providers: [TrainingService, IcalService],
  controllers: [TrainingController],
  exports: [TrainingService],
})
export class TrainingModule {}
