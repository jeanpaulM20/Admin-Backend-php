import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CoachingSubscription } from '../entities/coaching-subscription.entity';
import { EntitlementService } from './entitlement.service';

@Module({
  imports: [TypeOrmModule.forFeature([CoachingSubscription])],
  providers: [EntitlementService],
  exports: [EntitlementService],
})
export class EntitlementModule {}
