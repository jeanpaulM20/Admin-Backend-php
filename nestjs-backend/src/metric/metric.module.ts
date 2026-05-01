import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Metric } from '../entities/metric.entity';
import { MetricController } from './metric.controller';
import { MetricService } from './metric.service';

@Module({
  imports: [TypeOrmModule.forFeature([Metric])],
  controllers: [MetricController],
  providers: [MetricService],
})
export class MetricModule {}
