import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TrainingPlan } from '../entities/training-plan.entity';
import { DailyQuoteService } from './daily-quote.service';
import { DailyQuoteController } from './daily-quote.controller';

@Module({
  imports: [TypeOrmModule.forFeature([TrainingPlan])],
  controllers: [DailyQuoteController],
  providers: [DailyQuoteService],
})
export class DailyQuoteModule {}
