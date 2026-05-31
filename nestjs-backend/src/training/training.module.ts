import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Training } from '../entities/training.entity';
import { TrainingType } from '../entities/training-type.entity';
import { Location } from '../entities/location.entity';
import { TrainingService } from './training.service';
import { IcalService } from './ical.service';
import { TrainingController, IcalLegacyController } from './training.controller';
import { PushModule } from '../push/push.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Training, TrainingType, Location]),
    PushModule,
  ],
  providers: [TrainingService, IcalService],
  controllers: [TrainingController, IcalLegacyController],
  exports: [TrainingService],
})
export class TrainingModule {}
