import { Provider } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Exercise } from '../../../entities/exercise.entity';
import { Exercisegroup } from '../../../entities/exercise-group.entity';
import { ImportCatalogUseCase } from '../application/import-catalog.usecase';
import { RepDbSource } from '../adapter/repdb.source';
import { TypeOrmExerciseCatalogRepository } from '../adapter/typeorm-exercise-catalog.repository';
import { readCatalogImportConfig } from './catalog-import.config';

/** DI-Token für den RepDB-Import-Use-Case. */
export const REPDB_IMPORT = Symbol('REPDB_IMPORT');

/**
 * Composition Root des Katalog-Imports: hier — und nur hier — treffen
 * Konfiguration, Adapter und Use Case aufeinander.
 */
export const repDbImportProvider: Provider = {
  provide: REPDB_IMPORT,
  inject: [getRepositoryToken(Exercise), getRepositoryToken(Exercisegroup)],
  useFactory: (exercises: Repository<Exercise>, groups: Repository<Exercisegroup>) => {
    const config = readCatalogImportConfig();
    return new ImportCatalogUseCase(
      new RepDbSource(config.repDbUrl),
      new TypeOrmExerciseCatalogRepository(exercises, groups),
    );
  },
};
