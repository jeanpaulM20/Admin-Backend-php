import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Exercise } from '../entities/exercise.entity';
import { Exercisegroup } from '../entities/exercise-group.entity';
import { Exercisesubgroup } from '../entities/exercise-subgroup.entity';
import { Exercisepictures } from '../entities/exercise-pictures.entity';
import { ExerciseService } from './exercise.service';
import { ExerciseIconService } from './exercise-icon.service';
import { ExerciseController } from './exercise.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Exercise, Exercisegroup, Exercisesubgroup, Exercisepictures])],
  providers: [ExerciseService, ExerciseIconService],
  controllers: [ExerciseController],
  exports: [ExerciseService, ExerciseIconService],
})
export class ExerciseModule {}
