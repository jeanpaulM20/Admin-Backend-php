import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CalendarConnection } from './entities/calendar-connection.entity';
import { CalendarOAuthService } from './calendar-oauth.service';
import { CalendarSyncService } from './calendar-sync.service';
import { CalendarController } from './calendar.controller';

@Module({
  imports: [TypeOrmModule.forFeature([CalendarConnection])],
  providers: [CalendarOAuthService, CalendarSyncService],
  controllers: [CalendarController],
  exports: [CalendarOAuthService, CalendarSyncService],
})
export class CalendarModule {}
