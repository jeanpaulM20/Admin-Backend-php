import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CoachingSubscription } from '../entities/coaching-subscription.entity';
import { EntitlementService } from './entitlement.service';
import { SubscriptionReminderService } from './subscription-reminder.service';
import { EntitlementController } from './entitlement.controller';
import { PushModule } from '../push/push.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([CoachingSubscription]),
    PushModule,
    RealtimeModule,
  ],
  controllers: [EntitlementController],
  providers: [EntitlementService, SubscriptionReminderService],
  exports: [EntitlementService, SubscriptionReminderService],
})
export class EntitlementModule {}
