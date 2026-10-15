import { isExpired } from '../domain/polar-connection';
import { toWorkoutDraft } from '../domain/workout-mapping';
import {
  ImportedExerciseStore, PolarAccessLink, PolarConnectionRepository, PolarNotConfiguredError,
  PolarNotConnectedError, PolarRateLimitedError, PolarUnauthorizedError, WorkoutWriter,
} from './ports';

export interface SyncReport {
  /** neu angelegte Trainings */
  imported: number;
  /** ohne Startzeit — nicht übernehmbar */
  skipped: number;
  /** beim Abruf gescheitert, kommen beim nächsten Sync wieder dran */
  failed: number;
  /** schon früher importiert */
  alreadyImported: number;
}

/** Ein Sync holt höchstens so viele neue Trainings — der Rest folgt beim nächsten. */
export const MAX_IMPORTS_PER_SYNC = 25;

export interface SyncDeps {
  api: PolarAccessLink | null;
  connections: PolarConnectionRepository;
  imported: ImportedExerciseStore;
  workouts: WorkoutWriter;
  now: () => Date;
}

/** Holt neue Polar-Trainings (letzte 30 Tage) und legt sie als Trainings an. */
export class PolarSyncUseCase {
  constructor(private readonly deps: SyncDeps) {}

  async sync(clientId: number): Promise<SyncReport> {
    const { api, connections, imported, workouts, now } = this.deps;
    if (!api) throw new PolarNotConfiguredError();

    const conn = await connections.find(clientId);
    if (!conn) throw new PolarNotConnectedError();
    if (isExpired(conn, now())) {
      await connections.delete(clientId);
      throw new PolarUnauthorizedError();
    }

    const report: SyncReport = { imported: 0, skipped: 0, failed: 0, alreadyImported: 0 };
    try {
      const list = await api.listExercises(conn.accessToken);
      const ids = list.map((e) => String(e?.id ?? '')).filter(Boolean);
      const known = await imported.importedIds(clientId, ids);
      report.alreadyImported = known.size;

      const fresh = ids.filter((id) => !known.has(id)).slice(0, MAX_IMPORTS_PER_SYNC);
      for (const id of fresh) {
        try {
          const exercise = await api.getExercise(conn.accessToken, id);
          const draft = toWorkoutDraft(exercise);
          if (!draft) {
            await imported.record(clientId, id, null);
            report.skipped++;
            continue;
          }
          const reviewId = await workouts.write(clientId, draft);
          await imported.record(clientId, id, reviewId);
          report.imported++;
        } catch (e) {
          // Auth- und Lastfehler betreffen alle weiteren Abrufe → abbrechen
          if (e instanceof PolarUnauthorizedError || e instanceof PolarRateLimitedError) throw e;
          report.failed++;
        }
      }
    } catch (e) {
      if (e instanceof PolarUnauthorizedError) await connections.delete(clientId);
      throw e;
    }

    await connections.markSynced(clientId, now());
    return report;
  }
}
