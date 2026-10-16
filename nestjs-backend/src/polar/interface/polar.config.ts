/**
 * Konfiguration der Polar-Anbindung — ausschliesslich hier gelesen und in
 * die Adapter hineingereicht (Composition Root). Fehlt etwas, bleibt Polar
 * abgeschaltet (`accessLink: null`) statt halb zu laufen.
 */
import { createHmac, randomBytes } from 'crypto';
import type { AccessLinkSettings } from '../adapter/accesslink.client';

export interface PolarConfig {
  /** null = nicht eingerichtet */
  accessLink: AccessLinkSettings | null;
  /** 32 Bytes für AES-256-GCM; null = nicht eingerichtet */
  tokenKey: Buffer | null;
  /** Schlüssel für die Signatur des OAuth-state */
  stateKey: Buffer;
  /** Rücksprung in die iOS-App nach der Anmeldung */
  iosReturnUrl: string;
  /** Rücksprung in die Web-App (relativ zum Backend) */
  webReturnUrl: string;
  /** Warum Polar abgeschaltet ist — fürs Log, ohne Werte */
  disabledReason: string | null;
}

const DEFAULT_REDIRECT_URI = 'https://admin-backend-php-production.up.railway.app/api/client/polar/callback';

export function readPolarConfig(env: NodeJS.ProcessEnv = process.env): PolarConfig {
  const clientId = env.POLAR_CLIENT_ID?.trim() ?? '';
  const clientSecret = env.POLAR_CLIENT_SECRET?.trim() ?? '';
  const tokenKey = parseKey(env.POLAR_TOKEN_KEY);

  const missing = [
    !clientId && 'POLAR_CLIENT_ID',
    !clientSecret && 'POLAR_CLIENT_SECRET',
    !tokenKey && 'POLAR_TOKEN_KEY (32 Bytes base64)',
  ].filter(Boolean);
  const enabled = missing.length === 0;

  return {
    accessLink: enabled
      ? {
          clientId,
          clientSecret,
          redirectUri: env.POLAR_REDIRECT_URI?.trim() || DEFAULT_REDIRECT_URI,
          authorizeUrl: 'https://flow.polar.com/oauth2/authorization',
          tokenUrl: 'https://polarremote.com/v2/oauth2/token',
          apiBase: 'https://www.polaraccesslink.com',
        }
      : null,
    tokenKey,
    // Vom Client-Secret abgeleitet: kein weiterer Schlüssel nötig, und ein
    // neues Secret macht offene Anmeldungen automatisch ungültig.
    stateKey: clientSecret
      ? createHmac('sha256', clientSecret).update('polar-oauth-state').digest()
      : randomBytes(32),
    iosReturnUrl: env.POLAR_IOS_RETURN_URL?.trim() || 'sihlmove://polar',
    webReturnUrl: env.POLAR_WEB_RETURN_URL?.trim() || '/client/#/profile',
    disabledReason: enabled ? null : `fehlt: ${missing.join(', ')}`,
  };
}

function parseKey(raw: string | undefined): Buffer | null {
  if (!raw?.trim()) return null;
  const key = Buffer.from(raw.trim(), 'base64');
  return key.length === 32 ? key : null;
}
