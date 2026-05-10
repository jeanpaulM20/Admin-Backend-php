import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TrainingPlan } from '../entities/training-plan.entity';
import { PerformanceTest } from '../entities/performance-test.entity';
import { ClientAnamnese } from '../entities/client-anamnese.entity';
import { Exercise } from '../entities/exercise.entity';
import { Client } from '../entities/client.entity';
import { TrainingPlanService } from './training-plan.service';
import { AiPlanService } from './ai-plan.service';
import { TrainingPlanController } from './training-plan.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      TrainingPlan,
      PerformanceTest,
      ClientAnamnese,
      Exercise,
      Client,
    ]),
  ],
  providers: [TrainingPlanService, AiPlanService],
  controllers: [TrainingPlanController],
  exports: [TrainingPlanService, AiPlanService],
})
export class TrainingPlanModule {}
