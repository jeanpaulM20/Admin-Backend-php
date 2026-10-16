import { decodeState } from '../domain/oauth-state';
import type { PolarConnection } from '../domain/polar-connection';
import type { PolarExercise } from '../domain/polar-exercise';
import type { WorkoutDraft } from '../domain/workout-mapping';
import {
  ImportedExerciseStore, PolarAccessLink, PolarApiError, PolarConnectionRepository,
  PolarConsentMissingError, PolarNotConfiguredError, PolarNotConnectedError, PolarUnauthorizedError,
  TokenGrant, WorkoutWriter,
} from '../application/ports';
import { PolarConnectUseCase } from '../application/polar-connect.usecase';
import { MAX_IMPORTS_PER_SYNC, PolarSyncUseCase } from '../application/polar-sync.usecase';

const NOW = new Date('2026-10-15T12:00:00Z');
const KEY = Buffer.alloc(32, 3);

class FakeConnections implements PolarConnectionRepository {
  rows = new Map<number, PolarConnection>();
  async find(id: number) { return this.rows.get(id) ?? null; }
  async save(c: PolarConnection) { this.rows.set(c.clientId, { ...c }); }
  async delete(id: number) { this.rows.delete(id); }
  async markSynced(id: number, at: Date) { const c = this.rows.get(id); if (c) c.lastSyncAt = at; }
}

class FakeImports implements ImportedExerciseStore {
  rows: { clientId: number; exerciseId: string; reviewId: number | null }[] = [];
  async importedIds(clientId: number, ids: string[]) {
    return new Set(this.rows.filter((r) => r.clientId === clientId && ids.includes(r.exerciseId)).map((r) => r.exerciseId));
  }
  async record(clientId: number, exerciseId: string, reviewId: number | null) { this.rows.push({ clientId, exerciseId, reviewId }); }
}

class FakeWriter implements WorkoutWriter {
  written: { clientId: number; draft: WorkoutDraft }[] = [];
  async write(clientId: number, draft: WorkoutDraft) { this.written.push({ clientId, draft }); return 1000 + this.written.length; }
}

class FakeApi implements PolarAccessLink {
  grant: TokenGrant = { accessToken: 'tok', polarUserId: '555', expiresIn: 3600 };
  exercises: PolarExercise[] = [];
  registerResult: 'registered' | 'already' | Error = 'registered';
  failExercise = new Map<string, Error>();
  calls: string[] = [];
  authorizationUrl(state: string) { return `https://polar.test/auth?state=${state}`; }
  async exchangeCode(code: string) { this.calls.push(`exchange:${code}`); return this.grant; }
  async registerUser(_t: string, memberId: string) {
    this.calls.push(`register:${memberId}`);
    if (this.registerResult instanceof Error) throw this.registerResult;
    return this.registerResult;
  }
  async deregisterUser(_t: string, id: string) { this.calls.push(`deregister:${id}`); }
  async listExercises() { return this.exercises.map(({ id }) => ({ id })); }
  async getExercise(_t: string, id: string) {
    const err = this.failExercise.get(id);
    if (err) throw err;
    return this.exercises.find((e) => e.id === id)!;
  }
}

const exercise = (id: string): PolarExercise => ({
  id, start_time: '2026-10-14T08:00:00', start_time_utc_offset: 120, duration: 'PT30M', sport: 'RUNNING',
});

function connected(conns: FakeConnections, extra: Partial<PolarConnection> = {}) {
  conns.rows.set(7, {
    clientId: 7, polarUserId: '555', accessToken: 'tok', expiresAt: null,
    connectedAt: NOW, lastSyncAt: null, ...extra,
  });
}

describe('PolarConnectUseCase', () => {
  let api: FakeApi;
  let conns: FakeConnections;
  let uc: PolarConnectUseCase;

  beforeEach(() => {
    api = new FakeApi();
    conns = new FakeConnections();
    uc = new PolarConnectUseCase({ api, connections: conns, stateKey: KEY, now: () => NOW, nonce: () => 'n1' });
  });

  it('ohne Konfiguration: nicht verfügbar, kein Link', async () => {
    const off = new PolarConnectUseCase({ api: null, connections: conns, stateKey: KEY, now: () => NOW, nonce: () => 'n' });
    expect(await off.status(7, 'ios')).toEqual({ available: false, connected: false, connectUrl: null, lastSyncAt: null });
  });

  it('nicht verbunden: Link mit signiertem state für Client und Plattform', async () => {
    const s = await uc.status(7, 'ios');
    expect(s).toMatchObject({ available: true, connected: false });
    const state = new URL(s.connectUrl!).searchParams.get('state');
    expect(decodeState(state, KEY, NOW.getTime())).toMatchObject({ clientId: 7, platform: 'ios' });
  });

  it('verbunden: kein Link, letzter Sync', async () => {
    connected(conns, { lastSyncAt: new Date('2026-10-15T10:00:00Z') });
    expect(await uc.status(7, 'web')).toEqual({
      available: true, connected: true, connectUrl: null, lastSyncAt: '2026-10-15T10:00:00.000Z',
    });
  });

  it('abgelaufenes Token zählt als nicht verbunden', async () => {
    connected(conns, { expiresAt: new Date('2026-10-15T11:00:00Z') });
    expect((await uc.status(7, 'web')).connected).toBe(false);
  });

  it('Callback: tauscht Code, registriert, speichert mit Ablauf', async () => {
    const state = new URL((await uc.status(7, 'ios')).connectUrl!).searchParams.get('state')!;
    const out = await uc.completeAuthorization({ code: 'c1', state });
    expect(out).toEqual({ ok: true, platform: 'ios', clientId: 7 });
    expect(api.calls).toEqual(['exchange:c1', 'register:sihl-7-555']);
    expect(conns.rows.get(7)).toMatchObject({
      polarUserId: '555', accessToken: 'tok', expiresAt: new Date('2026-10-15T13:00:00Z'),
    });
  });

  it('Callback: bereits registriert (409) ist in Ordnung', async () => {
    api.registerResult = 'already';
    const state = new URL((await uc.status(7, 'web')).connectUrl!).searchParams.get('state')!;
    expect((await uc.completeAuthorization({ code: 'c', state })).ok).toBe(true);
  });

  it('Callback: ungültiger state verknüpft nichts', async () => {
    const out = await uc.completeAuthorization({ code: 'c', state: 'gefälscht' });
    expect(out.ok).toBe(false);
    expect(api.calls).toEqual([]);
    expect(conns.rows.size).toBe(0);
  });

  it('Callback: abgelehnt bei Polar', async () => {
    const state = new URL((await uc.status(7, 'ios')).connectUrl!).searchParams.get('state')!;
    expect(await uc.completeAuthorization({ state, error: 'access_denied' }))
      .toEqual({ ok: false, platform: 'ios', message: 'Polar-Verbindung abgebrochen' });
  });

  it('Callback: fehlende Einwilligungen → Meldung, nichts gespeichert', async () => {
    api.registerResult = new PolarConsentMissingError();
    const state = new URL((await uc.status(7, 'ios')).connectUrl!).searchParams.get('state')!;
    const out = await uc.completeAuthorization({ code: 'c', state });
    expect(out).toMatchObject({ ok: false, platform: 'ios' });
    expect(conns.rows.size).toBe(0);
  });

  it('Trennen: bei Polar abmelden und lokal löschen', async () => {
    connected(conns);
    await uc.disconnect(7);
    expect(api.calls).toEqual(['deregister:555']);
    expect(conns.rows.size).toBe(0);
  });

  it('Trennen: lokal auch, wenn Polar-Abmeldung scheitert', async () => {
    connected(conns);
    api.deregisterUser = async () => { throw new PolarApiError(500, 'kaputt'); };
    await uc.disconnect(7);
    expect(conns.rows.size).toBe(0);
  });
});

describe('PolarSyncUseCase', () => {
  let api: FakeApi;
  let conns: FakeConnections;
  let imports: FakeImports;
  let writer: FakeWriter;
  let uc: PolarSyncUseCase;

  beforeEach(() => {
    api = new FakeApi();
    conns = new FakeConnections();
    imports = new FakeImports();
    writer = new FakeWriter();
    uc = new PolarSyncUseCase({ api, connections: conns, imported: imports, workouts: writer, now: () => NOW });
  });

  it('ohne Konfiguration / ohne Verbindung', async () => {
    const off = new PolarSyncUseCase({ api: null, connections: conns, imported: imports, workouts: writer, now: () => NOW });
    await expect(off.sync(7)).rejects.toBeInstanceOf(PolarNotConfiguredError);
    await expect(uc.sync(7)).rejects.toBeInstanceOf(PolarNotConnectedError);
  });

  it('importiert neue, überspringt bekannte und unbrauchbare', async () => {
    connected(conns);
    api.exercises = [exercise('A'), exercise('B'), { id: 'C' }];
    await imports.record(7, 'A', 1);

    expect(await uc.sync(7)).toEqual({ imported: 1, skipped: 1, failed: 0, alreadyImported: 1 });
    expect(writer.written.map((w) => w.draft.trainingType)).toEqual(['Joggen']);
    expect(imports.rows.map((r) => [r.exerciseId, r.reviewId])).toEqual([['A', 1], ['B', 1001], ['C', null]]);
    expect(conns.rows.get(7)!.lastSyncAt).toEqual(NOW);
  });

  it('zweiter Sync legt nichts doppelt an', async () => {
    connected(conns);
    api.exercises = [exercise('A')];
    await uc.sync(7);
    expect(await uc.sync(7)).toMatchObject({ imported: 0, alreadyImported: 1 });
    expect(writer.written).toHaveLength(1);
  });

  it('Einzelfehler: Rest läuft weiter, Fehlschlag kommt nächstes Mal wieder', async () => {
    connected(conns);
    api.exercises = [exercise('A'), exercise('B')];
    api.failExercise.set('A', new PolarApiError(500, 'x'));
    expect(await uc.sync(7)).toMatchObject({ imported: 1, failed: 1 });
    expect(imports.rows.map((r) => r.exerciseId)).toEqual(['B']);
  });

  it('401: Verbindung wird entfernt', async () => {
    connected(conns);
    api.exercises = [exercise('A')];
    api.failExercise.set('A', new PolarUnauthorizedError());
    await expect(uc.sync(7)).rejects.toBeInstanceOf(PolarUnauthorizedError);
    expect(conns.rows.size).toBe(0);
  });

  it('abgelaufenes Token: kein Abruf, Verbindung entfernt', async () => {
    connected(conns, { expiresAt: new Date('2026-10-15T11:00:00Z') });
    await expect(uc.sync(7)).rejects.toBeInstanceOf(PolarUnauthorizedError);
    expect(conns.rows.size).toBe(0);
  });

  it(`höchstens ${MAX_IMPORTS_PER_SYNC} Importe je Sync`, async () => {
    connected(conns);
    api.exercises = Array.from({ length: MAX_IMPORTS_PER_SYNC + 5 }, (_, i) => exercise(`E${i}`));
    expect((await uc.sync(7)).imported).toBe(MAX_IMPORTS_PER_SYNC);
    expect((await uc.sync(7)).imported).toBe(5);
  });
});
