import { createHmac, timingSafeEqual } from 'crypto';

/**
 * Der OAuth-`state` trägt, für wen die Polar-Anmeldung läuft. Er ist
 * signiert und kurzlebig: Ohne gültige Signatur könnte jemand einen
 * fremden Polar-Account mit einem beliebigen Client verknüpfen.
 */
export type ConnectPlatform = 'ios' | 'web';

export interface OAuthStatePayload {
  clientId: number;
  platform: ConnectPlatform;
  /** Ablauf, ms seit Epoch */
  expiresAt: number;
  /** Zufallswert — macht jeden state einmalig */
  nonce: string;
}

/** Polar lässt den Code 10 Minuten gelten; der state gilt genauso lange. */
export const STATE_TTL_MS = 10 * 60_000;

const b64url = (buf: Buffer) => buf.toString('base64url');

function sign(body: string, key: Buffer): string {
  return b64url(createHmac('sha256', key).update(body).digest());
}

export function encodeState(payload: OAuthStatePayload, key: Buffer): string {
  const body = b64url(Buffer.from(JSON.stringify({
    c: payload.clientId, p: payload.platform, e: payload.expiresAt, n: payload.nonce,
  })));
  return `${body}.${sign(body, key)}`;
}

/** Payload bei gültiger Signatur und nicht abgelaufenem state, sonst null. */
export function decodeState(state: unknown, key: Buffer, nowMs: number): OAuthStatePayload | null {
  const payload = readSigned(state, key);
  if (!payload || payload.expiresAt < nowMs) return null;
  return payload;
}

/**
 * Plattform aus einem echt signierten, aber evtl. abgelaufenen state —
 * nur für den Rücksprung: Auch eine abgelaufene iOS-Anmeldung muss nach
 * `sihlmove://` zurück, sonst hängt die App in der Web-Seite fest.
 */
export function signedPlatform(state: unknown, key: Buffer): ConnectPlatform | null {
  return readSigned(state, key)?.platform ?? null;
}

/** Payload bei gültiger Signatur — ohne Ablaufprüfung. */
function readSigned(state: unknown, key: Buffer): OAuthStatePayload | null {
  if (typeof state !== 'string') return null;
  const parts = state.split('.');
  if (parts.length !== 2) return null;
  const [body, sig] = parts;

  const expected = Buffer.from(sign(body, key));
  const given = Buffer.from(sig);
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) return null;

  let raw: any;
  try {
    raw = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  const clientId = Number(raw?.c);
  const expiresAt = Number(raw?.e);
  const platform = raw?.p === 'ios' ? 'ios' : raw?.p === 'web' ? 'web' : null;
  if (!Number.isInteger(clientId) || clientId <= 0 || !platform) return null;
  if (!Number.isFinite(expiresAt)) return null;
  return { clientId, platform, expiresAt, nonce: String(raw?.n ?? '') };
}
