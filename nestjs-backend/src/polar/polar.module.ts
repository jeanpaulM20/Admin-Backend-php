import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ReviewModule } from '../review/review.module';
import { PolarConnectionRow } from './adapter/polar-connection.entity';
import { PolarExerciseImportRow } from './adapter/polar-exercise-import.entity';
import { PolarController } from './interface/polar.controller';
import {
  polarConfigProvider, polarConnectProvider, polarSyncProvider,
} from './interface/polar.provider';

/**
 * Polar AccessLink: Verbinden, Trainings-Sync, Trennen.
 * Ohne POLAR_CLIENT_ID/POLAR_CLIENT_SECRET/POLAR_TOKEN_KEY meldet der Status
 * `available: false` — die Apps blenden „Verbinden" dann aus.
 */
@Module({
  imports: [TypeOrmModule.forFeature([PolarConnectionRow, PolarExerciseImportRow]), ReviewModule],
  controllers: [PolarController],
  providers: [polarConfigProvider, polarConnectProvider, polarSyncProvider],
})
export class PolarModule {}
