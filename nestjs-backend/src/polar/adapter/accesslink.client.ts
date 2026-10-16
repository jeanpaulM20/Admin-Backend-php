import type { PolarExercise } from '../domain/polar-exercise';
import {
  PolarAccessLink, PolarApiError, PolarConsentMissingError, PolarRateLimitedError,
  PolarUnauthorizedError, TokenGrant,
} from '../application/ports';

export interface AccessLinkSettings {
  clientId: string;
  clientSecret: string;
  /** Muss exakt einer in Polar registrierten Redirect-URL entsprechen. */
  redirectUri: string;
  authorizeUrl: string;
  tokenUrl: string;
  apiBase: string;
}

const TIMEOUT_MS = 20_000;

/** HTTP-Adapter für Polar AccessLink v3 (non-transactional Exercises). */
export class AccessLinkClient implements PolarAccessLink {
  constructor(private readonly s: AccessLinkSettings) {}

  authorizationUrl(state: string): string {
    const q = new URLSearchParams({
      response_type: 'code',
      client_id: this.s.clientId,
      redirect_uri: this.s.redirectUri,
      scope: 'accesslink.read_all',
      state,
    });
    return `${this.s.authorizeUrl}?${q.toString()}`;
  }

  async exchangeCode(code: string): Promise<TokenGrant> {
    const basic = Buffer.from(`${this.s.clientId}:${this.s.clientSecret}`).toString('base64');
    const res = await fetch(this.s.tokenUrl, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${basic}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code,
        redirect_uri: this.s.redirectUri,
      }).toString(),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (!res.ok) throw new PolarApiError(res.status, `Polar-Anmeldung fehlgeschlagen (${res.status})`);
    const json: any = await res.json();
    const accessToken = String(json?.access_token ?? '');
    const polarUserId = String(json?.x_user_id ?? '');
    if (!accessToken || !polarUserId) throw new PolarApiError(502, 'Polar hat kein gültiges Token geliefert');
    const expiresIn = Number(json?.expires_in);
    return { accessToken, polarUserId, expiresIn: Number.isFinite(expiresIn) && expiresIn > 0 ? expiresIn : null };
  }

  async registerUser(accessToken: string, memberId: string): Promise<'registered' | 'already'> {
    const res = await this.call('POST', '/v3/users', accessToken, { 'member-id': memberId });
    if (res.status === 409) return 'already';
    if (res.status === 403) throw new PolarConsentMissingError();
    await this.ensureOk(res);
    return 'registered';
  }

  async deregisterUser(accessToken: string, polarUserId: string): Promise<void> {
    const res = await this.call('DELETE', `/v3/users/${encodeURIComponent(polarUserId)}`, accessToken);
    if (res.status === 404) return;
    await this.ensureOk(res);
  }

  async listExercises(accessToken: string): Promise<PolarExercise[]> {
    const res = await this.call('GET', '/v3/exercises', accessToken);
    await this.ensureOk(res);
    const json: any = await res.json();
    return Array.isArray(json) ? json : Array.isArray(json?.exercises) ? json.exercises : [];
  }

  async getExercise(accessToken: string, exerciseId: string): Promise<PolarExercise> {
    const res = await this.call(
      'GET', `/v3/exercises/${encodeURIComponent(exerciseId)}?samples=true&route=true`, accessToken);
    await this.ensureOk(res);
    return (await res.json()) as PolarExercise;
  }

  private call(method: string, path: string, accessToken: string, body?: unknown): Promise<Response> {
    return fetch(`${this.s.apiBase}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/json',
        ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  }

  private async ensureOk(res: Response): Promise<void> {
    if (res.ok) return;
    if (res.status === 401) throw new PolarUnauthorizedError();
    if (res.status === 429) throw new PolarRateLimitedError();
    throw new PolarApiError(res.status, `Polar-Fehler ${res.status}`);
  }
}
