import { Logger, Provider } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { randomBytes } from 'crypto';
import { Repository } from 'typeorm';
import { ReviewService } from '../../review/review.service';
import { AccessLinkClient } from '../adapter/accesslink.client';
import { PolarConnectionRow } from '../adapter/polar-connection.entity';
import { PolarExerciseImportRow } from '../adapter/polar-exercise-import.entity';
import { ReviewWorkoutWriter } from '../adapter/review-workout.writer';
import { TokenCipher } from '../adapter/token-cipher';
import {
  TypeOrmImportedExerciseStore, TypeOrmPolarConnectionRepository,
} from '../adapter/typeorm-polar.repositories';
import { PolarConnectUseCase } from '../application/polar-connect.usecase';
import { PolarSyncUseCase } from '../application/polar-sync.usecase';
import { PolarConfig, readPolarConfig } from './polar.config';

export const POLAR_CONFIG = Symbol('POLAR_CONFIG');
export const POLAR_CONNECT = Symbol('POLAR_CONNECT');
export const POLAR_SYNC = Symbol('POLAR_SYNC');

const now = () => new Date();

/**
 * Composition Root der Polar-Anbindung: hier — und nur hier — treffen
 * Konfiguration, Adapter und Use Cases aufeinander.
 */
export const polarConfigProvider: Provider = {
  provide: POLAR_CONFIG,
  useFactory: () => {
    const config = readPolarConfig();
    if (config.disabledReason) {
      new Logger('Polar').warn(`Polar-Anbindung abgeschaltet — ${config.disabledReason}`);
    }
    return config;
  },
};

function connectionRepo(config: PolarConfig, rows: Repository<PolarConnectionRow>) {
  // Ohne Schlüssel bleibt die Anbindung ohnehin abgeschaltet (accessLink null);
  // ein Wegwerf-Schlüssel hält den Repository-Typ trotzdem einheitlich.
  return new TypeOrmPolarConnectionRepository(rows, new TokenCipher(config.tokenKey ?? randomBytes(32)));
}

export const polarConnectProvider: Provider = {
  provide: POLAR_CONNECT,
  inject: [POLAR_CONFIG, getRepositoryToken(PolarConnectionRow)],
  useFactory: (config: PolarConfig, rows: Repository<PolarConnectionRow>) =>
    new PolarConnectUseCase({
      api: config.accessLink ? new AccessLinkClient(config.accessLink) : null,
      connections: connectionRepo(config, rows),
      stateKey: config.stateKey,
      now,
      nonce: () => randomBytes(9).toString('base64url'),
    }),
};

export const polarSyncProvider: Provider = {
  provide: POLAR_SYNC,
  inject: [
    POLAR_CONFIG, getRepositoryToken(PolarConnectionRow), getRepositoryToken(PolarExerciseImportRow), ReviewService,
  ],
  useFactory: (
    config: PolarConfig,
    rows: Repository<PolarConnectionRow>,
    imports: Repository<PolarExerciseImportRow>,
    reviews: ReviewService,
  ) =>
    new PolarSyncUseCase({
      api: config.accessLink ? new AccessLinkClient(config.accessLink) : null,
      connections: connectionRepo(config, rows),
      imported: new TypeOrmImportedExerciseStore(imports),
      workouts: new ReviewWorkoutWriter(reviews),
      now,
    }),
};
