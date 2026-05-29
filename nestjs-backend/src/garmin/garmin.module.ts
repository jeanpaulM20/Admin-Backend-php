import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GarminConnection } from './entities/garmin-connection.entity';
import { GarminActivity } from './entities/garmin-activity.entity';
import { GarminDailySummary } from './entities/garmin-daily-summary.entity';
import { GarminService } from './garmin.service';
import { GarminController } from './garmin.controller';
import { GarminWebhookController } from './garmin-webhook.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      GarminConnection,
      GarminActivity,
      GarminDailySummary,
    ]),
  ],
  providers: [GarminService],
  controllers: [GarminController, GarminWebhookController],
  exports: [GarminService],
})
export class GarminModule {}
