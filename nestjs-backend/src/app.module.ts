import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
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
import { FileModule } from './file/file.module';
import { PushModule } from './push/push.module';
// Garmin module kept for later — not imported until Consumer Key is configured
// import { GarminModule } from './garmin/garmin.module';
import { PreferenceController } from './file/preference.controller';
import { StartupMigrationService } from './common/startup-migration.service';

const isSqlite = process.env.DB_TYPE === 'sqlite';

const dbConfig: any = isSqlite
  ? {
      type: 'better-sqlite3',
      database: process.env.DB_SQLITE_PATH ?? 'dev.sqlite',
      entities: [__dirname + '/entities/*.{entity,entities}{.ts,.js}'],
      synchronize: true,
      logging: false,
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
    };

@Module({
  imports: [
    TypeOrmModule.forRoot(dbConfig),
    ServeStaticModule.forRoot(
      {
        rootPath: join(__dirname, 'public'),
        serveRoot: '/client',
        serveStaticOptions: { index: ['index.html'] },
      },
      {
        rootPath: join(__dirname, 'public-trainer'),
        serveRoot: '/trainer',
        serveStaticOptions: { index: ['index.html'] },
      },
      {
        rootPath: join(__dirname, 'public-st'),
        serveRoot: '/st',
        serveStaticOptions: { index: ['index.html'] },
      },
      {
        rootPath: join(__dirname, 'public', 'exercise-icons'),
        serveRoot: '/exercise-icons',
        serveStaticOptions: { index: false },
      },
    ),
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
    FileModule,
    PushModule,
    // GarminModule, // re-enable when GARMIN_CONSUMER_KEY is set
  ],
  controllers: [PreferenceController],
  providers: [StartupMigrationService],
})
export class AppModule {}
