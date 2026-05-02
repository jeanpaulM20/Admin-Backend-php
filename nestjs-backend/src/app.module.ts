import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from './auth/auth.module';
import { TrainerModule } from './trainer/trainer.module';
import { ClientModule } from './client/client.module';
import { TrainingModule } from './training/training.module';
import { FeedbackModule } from './feedback/feedback.module';
import { ExerciseModule } from './exercise/exercise.module';
import { TrainingPlanModule } from './training-plan/training-plan.module';
import { LocationModule } from './location/location.module';
import { MetricModule } from './metric/metric.module';
import { AvailabilityModule } from './availability/availability.module';
import { PerformanceTestModule } from './performance-test/performance-test.module';
import { AnamneseModule } from './anamnese/anamnese.module';
import { ReviewModule } from './review/review.module';
import { StartupMigrationService } from './common/startup-migration.service';
import { TblNamingStrategy } from './common/tbl-naming-strategy';

const isSqlite = process.env.DB_TYPE === 'sqlite';

const dbConfig: any = isSqlite
  ? {
      type: 'better-sqlite3',
      database: process.env.DB_SQLITE_PATH ?? 'dev.sqlite',
      entities: [__dirname + '/entities/*.{entity,entities}{.ts,.js}'],
      synchronize: true,
      logging: false,
      namingStrategy: new TblNamingStrategy(),
    }
  : {
      type: 'mysql',
      host: process.env.DB_HOST ?? 'localhost',
      port: parseInt(process.env.DB_PORT ?? '3306'),
      username: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME,
      entities: [__dirname + '/entities/*.{entity,entities}{.ts,.js}'],
      synchronize: false,
      logging: process.env.NODE_ENV === 'development',
      namingStrategy: new TblNamingStrategy(),
    };

@Module({
  imports: [
    TypeOrmModule.forRoot(dbConfig),
    AuthModule,
    TrainerModule,
    ClientModule,
    TrainingModule,
    FeedbackModule,
    ExerciseModule,
    TrainingPlanModule,
    LocationModule,
    MetricModule,
    AvailabilityModule,
    PerformanceTestModule,
    AnamneseModule,
    ReviewModule,
  ],
  providers: [StartupMigrationService],
})
export class AppModule {}
