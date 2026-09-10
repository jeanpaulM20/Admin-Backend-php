import { Module } from '@nestjs/common';
import { ExternalBusy } from '../calendar/entities/external-busy.entity';
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
    // ExternalBusy: Buchungen prüfen seit Phase 2 auch gegen Fremdkalender
    TypeOrmModule.forFeature([Training, TrainingType, Location, TrainingPlan, ExternalBusy]),
    PushModule,
  ],
  providers: [TrainingService, IcalService],
  controllers: [TrainingController],
  exports: [TrainingService],
})
export class TrainingModule {}
