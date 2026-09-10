import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CalendarConnection } from './entities/calendar-connection.entity';
import { CalendarFeed } from './entities/calendar-feed.entity';
import { ExternalBusy } from './entities/external-busy.entity';
import { CalendarOAuthService } from './calendar-oauth.service';
import { CalendarSyncService } from './calendar-sync.service';
import { CalendarFeedService } from './calendar-feed.service';
import { CalendarController } from './calendar.controller';

@Module({
  imports: [TypeOrmModule.forFeature([CalendarConnection, CalendarFeed, ExternalBusy])],
  providers: [CalendarOAuthService, CalendarSyncService, CalendarFeedService],
  controllers: [CalendarController],
  exports: [CalendarOAuthService, CalendarSyncService, CalendarFeedService],
})
export class CalendarModule {}
