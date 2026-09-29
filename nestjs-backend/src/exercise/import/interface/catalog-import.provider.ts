import { Provider } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Exercise } from '../../../entities/exercise.entity';
import { Exercisegroup } from '../../../entities/exercise-group.entity';
import { ExerciseReformer } from '../../../entities/exercise-reformer.entity';
import { ImportCatalogUseCase } from '../application/import-catalog.usecase';
import { RepDbSource } from '../adapter/repdb.source';
import { HttpImageFetcher } from '../adapter/http-image-fetcher';
import { ImportCatalogImagesUseCase } from '../application/import-catalog-images.usecase';
import { ReformerCsvSource } from '../adapter/reformer-csv.source';
import { TypeOrmExerciseCatalogRepository } from '../adapter/typeorm-exercise-catalog.repository';
import { readCatalogImportConfig } from './catalog-import.config';

/** DI-Token für die Import-Use-Cases. */
export const REPDB_IMPORT = Symbol('REPDB_IMPORT');
export const REPDB_IMAGE_IMPORT = Symbol('REPDB_IMAGE_IMPORT');
export const REFORMER_IMPORT = Symbol('REFORMER_IMPORT');

const REPOS = [
  getRepositoryToken(Exercise),
  getRepositoryToken(Exercisegroup),
  getRepositoryToken(ExerciseReformer),
];

/**
 * Composition Root des Katalog-Imports: hier — und nur hier — treffen
 * Konfiguration, Adapter und Use Case aufeinander.
 */
export const repDbImportProvider: Provider = {
  provide: REPDB_IMPORT,
  inject: REPOS,
  useFactory: (
    exercises: Repository<Exercise>, groups: Repository<Exercisegroup>, reformer: Repository<ExerciseReformer>,
  ) => {
    const config = readCatalogImportConfig();
    return new ImportCatalogUseCase(
      new RepDbSource(config.repDbUrl, config.repDbImageBase),
      new TypeOrmExerciseCatalogRepository(exercises, groups, reformer),
    );
  },
};

/** RepDB-Illustrationen (WebP, freie Stufe mit Attribution) in den Katalog holen. */
export const repDbImageImportProvider: Provider = {
  provide: REPDB_IMAGE_IMPORT,
  inject: REPOS,
  useFactory: (
    exercises: Repository<Exercise>, groups: Repository<Exercisegroup>, reformer: Repository<ExerciseReformer>,
  ) => {
    const config = readCatalogImportConfig();
    return new ImportCatalogImagesUseCase(
      new RepDbSource(config.repDbUrl, config.repDbImageBase),
      new TypeOrmExerciseCatalogRepository(exercises, groups, reformer),
      new HttpImageFetcher(),
    );
  },
};

/** Erfassungsblatt des Studios → Reformer-Repertoire (Etappe 5). */
export const reformerImportProvider: Provider = {
  provide: REFORMER_IMPORT,
  inject: REPOS,
  useFactory: (
    exercises: Repository<Exercise>, groups: Repository<Exercisegroup>, reformer: Repository<ExerciseReformer>,
  ) => {
    const config = readCatalogImportConfig();
    return new ImportCatalogUseCase(
      new ReformerCsvSource(config.reformerSheetPath),
      new TypeOrmExerciseCatalogRepository(exercises, groups, reformer),
    );
  },
};
