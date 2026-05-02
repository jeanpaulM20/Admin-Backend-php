import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PerformanceTest } from '../entities/performance-test.entity';
import { PerformanceTestController } from './performance-test.controller';
import { PerformanceTestService } from './performance-test.service';

@Module({
  imports: [TypeOrmModule.forFeature([PerformanceTest])],
  controllers: [PerformanceTestController],
  providers: [PerformanceTestService],
})
export class PerformanceTestModule {}
