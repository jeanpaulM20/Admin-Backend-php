import type { PolarConnection } from '../domain/polar-connection';
import type { PolarExercise } from '../domain/polar-exercise';
import type { WorkoutDraft } from '../domain/workout-mapping';

export interface TokenGrant {
  accessToken: string;
  polarUserId: string;
  /** Sekunden; null = ohne Ablaufangabe */
  expiresIn: number | null;
}

/** Was wir von Polar AccessLink brauchen — nicht mehr. */
export interface PolarAccessLink {
  authorizationUrl(state: string): string;
  exchangeCode(code: string): Promise<TokenGrant>;
  /** 'already' = Polar meldet 409, der Benutzer ist schon registriert. */
  registerUser(accessToken: string, memberId: string): Promise<'registered' | 'already'>;
  deregisterUser(accessToken: string, polarUserId: string): Promise<void>;
  /** Trainings der letzten 30 Tage, ohne Samples/Route. */
  listExercises(accessToken: string): Promise<PolarExercise[]>;
  /** Ein Training mit HF-Samples und Route. */
  getExercise(accessToken: string, exerciseId: string): Promise<PolarExercise>;
}

export interface PolarConnectionRepository {
  find(clientId: number): Promise<PolarConnection | null>;
  save(conn: PolarConnection): Promise<void>;
  delete(clientId: number): Promise<void>;
  markSynced(clientId: number, at: Date): Promise<void>;
}

/** Merkt sich importierte Polar-Trainings, damit keines doppelt entsteht. */
export interface ImportedExerciseStore {
  importedIds(clientId: number, exerciseIds: string[]): Promise<Set<string>>;
  /** reviewId null = bewusst übersprungen (z. B. ohne Startzeit) */
  record(clientId: number, exerciseId: string, reviewId: number | null): Promise<void>;
}

export interface WorkoutWriter {
  /** Legt das Training an und liefert die Review-ID. */
  write(clientId: number, draft: WorkoutDraft): Promise<number>;
}

// ── Fehler, die die Interface-Schicht in HTTP-Antworten übersetzt ──────────

/** Polar ist auf dem Server nicht eingerichtet (Variablen fehlen). */
export class PolarNotConfiguredError extends Error {
  constructor() { super('Polar ist auf dem Server nicht eingerichtet'); }
}

export class PolarNotConnectedError extends Error {
  constructor() { super('Kein Polar-Konto verbunden'); }
}

/** Token abgelaufen oder vom Benutzer bei Polar widerrufen (401). */
export class PolarUnauthorizedError extends Error {
  constructor() { super('Polar-Verbindung abgelaufen – bitte neu verbinden'); }
}

/** 403 bei der Registrierung: Pflicht-Einwilligungen bei Polar fehlen. */
export class PolarConsentMissingError extends Error {
  constructor() { super('Bitte in Polar Flow alle Einwilligungen bestätigen und erneut verbinden'); }
}

export class PolarRateLimitedError extends Error {
  constructor() { super('Polar ist gerade ausgelastet – bitte später erneut versuchen'); }
}

export class PolarApiError extends Error {
  constructor(readonly status: number, message: string) { super(message); }
}
