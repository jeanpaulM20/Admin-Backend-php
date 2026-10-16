import {
  ConnectPlatform, decodeState, encodeState, signedPlatform, STATE_TTL_MS,
} from '../domain/oauth-state';
import { isExpired, memberId } from '../domain/polar-connection';
import {
  PolarAccessLink, PolarConnectionRepository, PolarNotConfiguredError,
} from './ports';

export interface PolarStatus {
  /** false = Polar ist auf dem Server nicht eingerichtet */
  available: boolean;
  connected: boolean;
  /** Nur wenn verfügbar und nicht verbunden */
  connectUrl: string | null;
  lastSyncAt: string | null;
}

export type AuthorizationOutcome =
  | { ok: true; platform: ConnectPlatform; clientId: number }
  | { ok: false; platform: ConnectPlatform; message: string };

export interface ConnectDeps {
  /** null = Polar nicht eingerichtet */
  api: PolarAccessLink | null;
  connections: PolarConnectionRepository;
  /** Schlüssel für die state-Signatur */
  stateKey: Buffer;
  now: () => Date;
  nonce: () => string;
}

/** Verbinden, Status und Trennen eines Polar-Accounts. */
export class PolarConnectUseCase {
  constructor(private readonly deps: ConnectDeps) {}

  async status(clientId: number, platform: ConnectPlatform): Promise<PolarStatus> {
    const { api, connections, now } = this.deps;
    if (!api) return { available: false, connected: false, connectUrl: null, lastSyncAt: null };

    const conn = await connections.find(clientId);
    const connected = !!conn && !isExpired(conn, now());
    return {
      available: true,
      connected,
      connectUrl: connected ? null : api.authorizationUrl(this.newState(clientId, platform)),
      lastSyncAt: conn?.lastSyncAt ? conn.lastSyncAt.toISOString() : null,
    };
  }

  /**
   * Polar leitet nach der Anmeldung mit `code` und `state` zurück — oder mit
   * `error`, wenn der Benutzer abgelehnt hat. Fehler werden nicht geworfen,
   * sondern als Ergebnis geliefert: Der Callback leitet in jedem Fall zurück.
   */
  async completeAuthorization(input: { code?: string; state?: string; error?: string }): Promise<AuthorizationOutcome> {
    const { api, connections, stateKey, now } = this.deps;
    const payload = decodeState(input.state, stateKey, now().getTime());
    if (!payload) {
      // Abgelaufen, aber echt: trotzdem auf die richtige Plattform zurück
      const platform = signedPlatform(input.state, stateKey) ?? 'web';
      return { ok: false, platform, message: 'Anmeldung abgelaufen – bitte erneut verbinden' };
    }
    const { clientId, platform } = payload;
    if (!api) return { ok: false, platform, message: new PolarNotConfiguredError().message };
    if (input.error || !input.code) {
      return { ok: false, platform, message: 'Polar-Verbindung abgebrochen' };
    }

    try {
      const grant = await api.exchangeCode(input.code);
      await api.registerUser(grant.accessToken, memberId(clientId, grant.polarUserId));
      const at = now();
      await connections.save({
        clientId,
        polarUserId: grant.polarUserId,
        accessToken: grant.accessToken,
        expiresAt: grant.expiresIn ? new Date(at.getTime() + grant.expiresIn * 1000) : null,
        connectedAt: at,
        lastSyncAt: null,
      });
      return { ok: true, platform, clientId };
    } catch (e: any) {
      return { ok: false, platform, message: e?.message || 'Polar-Verbindung fehlgeschlagen' };
    }
  }

  /**
   * Bei Polar abmelden und lokal löschen. Schlägt die Abmeldung bei Polar
   * fehl (Token schon widerrufen), wird trotzdem lokal getrennt.
   */
  async disconnect(clientId: number): Promise<void> {
    const { api, connections } = this.deps;
    const conn = await connections.find(clientId);
    if (!conn) return;
    if (api) {
      try {
        await api.deregisterUser(conn.accessToken, conn.polarUserId);
      } catch {
        // lokal trotzdem trennen — sonst bliebe der Client hängen
      }
    }
    await connections.delete(clientId);
  }

  private newState(clientId: number, platform: ConnectPlatform): string {
    const { stateKey, now, nonce } = this.deps;
    return encodeState(
      { clientId, platform, expiresAt: now().getTime() + STATE_TTL_MS, nonce: nonce() },
      stateKey,
    );
  }
}
