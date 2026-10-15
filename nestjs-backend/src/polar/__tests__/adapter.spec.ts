import { AccessLinkClient } from '../adapter/accesslink.client';
import { TokenCipher } from '../adapter/token-cipher';
import {
  PolarApiError, PolarConsentMissingError, PolarRateLimitedError, PolarUnauthorizedError,
} from '../application/ports';

const settings = {
  clientId: 'cid',
  clientSecret: 'sec',
  redirectUri: 'https://backend.test/api/client/polar/callback',
  authorizeUrl: 'https://flow.polar.com/oauth2/authorization',
  tokenUrl: 'https://polarremote.com/v2/oauth2/token',
  apiBase: 'https://www.polaraccesslink.com',
};

function mockFetch(status: number, body: unknown = {}) {
  const fn = jest.fn(async () => new Response(
    status === 204 ? null : JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } },
  ));
  (global as any).fetch = fn;
  return fn;
}

describe('AccessLinkClient', () => {
  const client = new AccessLinkClient(settings);

  it('Autorisierungs-URL mit Redirect, Scope und state', () => {
    const url = new URL(client.authorizationUrl('st'));
    expect(url.origin + url.pathname).toBe(settings.authorizeUrl);
    expect(Object.fromEntries(url.searchParams)).toEqual({
      response_type: 'code', client_id: 'cid', redirect_uri: settings.redirectUri,
      scope: 'accesslink.read_all', state: 'st',
    });
  });

  it('Token-Tausch: Basic-Auth, Formular, Antwort gelesen', async () => {
    const f = mockFetch(200, { access_token: 'tok', token_type: 'bearer', expires_in: 31535999, x_user_id: 12345 });
    expect(await client.exchangeCode('c1')).toEqual({ accessToken: 'tok', polarUserId: '12345', expiresIn: 31535999 });
    const [url, init] = f.mock.calls[0] as any;
    expect(url).toBe(settings.tokenUrl);
    expect(init.headers.Authorization).toBe(`Basic ${Buffer.from('cid:sec').toString('base64')}`);
    expect(Object.fromEntries(new URLSearchParams(init.body))).toEqual({
      grant_type: 'authorization_code', code: 'c1', redirect_uri: settings.redirectUri,
    });
  });

  it('Registrierung: 200, 409, 403', async () => {
    const f = mockFetch(200);
    expect(await client.registerUser('tok', 'sihl-1-2')).toBe('registered');
    const [url, init] = f.mock.calls[0] as any;
    expect(url).toBe('https://www.polaraccesslink.com/v3/users');
    expect(JSON.parse(init.body)).toEqual({ 'member-id': 'sihl-1-2' });
    expect(init.headers.Authorization).toBe('Bearer tok');

    mockFetch(409);
    expect(await client.registerUser('tok', 'x')).toBe('already');
    mockFetch(403);
    await expect(client.registerUser('tok', 'x')).rejects.toBeInstanceOf(PolarConsentMissingError);
  });

  it('Training mit Samples und Route', async () => {
    const f = mockFetch(200, { id: 'A1' });
    expect(await client.getExercise('tok', 'A1')).toEqual({ id: 'A1' });
    expect((f.mock.calls[0] as any)[0]).toBe('https://www.polaraccesslink.com/v3/exercises/A1?samples=true&route=true');
  });

  it('Liste: Array oder verpackt', async () => {
    mockFetch(200, [{ id: 'A' }]);
    expect(await client.listExercises('tok')).toEqual([{ id: 'A' }]);
    mockFetch(200, { exercises: [{ id: 'B' }] });
    expect(await client.listExercises('tok')).toEqual([{ id: 'B' }]);
  });

  it('Fehlercodes werden zu Fachfehlern', async () => {
    mockFetch(401);
    await expect(client.listExercises('tok')).rejects.toBeInstanceOf(PolarUnauthorizedError);
    mockFetch(429);
    await expect(client.listExercises('tok')).rejects.toBeInstanceOf(PolarRateLimitedError);
    mockFetch(500);
    await expect(client.listExercises('tok')).rejects.toBeInstanceOf(PolarApiError);
  });

  it('Abmelden: 204 und 404 sind in Ordnung', async () => {
    const f = mockFetch(204);
    await client.deregisterUser('tok', '555');
    expect((f.mock.calls[0] as any)[1].method).toBe('DELETE');
    mockFetch(404);
    await expect(client.deregisterUser('tok', '555')).resolves.toBeUndefined();
  });
});

describe('TokenCipher', () => {
  const cipher = new TokenCipher(Buffer.alloc(32, 1));

  it('Rundreise, jedes Mal anderer Geheimtext', () => {
    const a = cipher.encrypt('geheim');
    expect(a).not.toContain('geheim');
    expect(cipher.encrypt('geheim')).not.toBe(a);
    expect(cipher.decrypt(a)).toBe('geheim');
  });

  it('anderer Schlüssel oder Manipulation schlägt fehl', () => {
    const a = cipher.encrypt('geheim');
    expect(() => new TokenCipher(Buffer.alloc(32, 2)).decrypt(a)).toThrow();
    const parts = a.split(':');
    parts[3] = Buffer.from('xxxxxx').toString('base64');
    expect(() => cipher.decrypt(parts.join(':'))).toThrow();
  });

  it('verlangt 32 Byte Schlüssel', () => {
    expect(() => new TokenCipher(Buffer.alloc(16))).toThrow();
  });
});
