import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as crypto from 'crypto';
import { CalendarConnection, CalendarProvider } from './entities/calendar-connection.entity';
import { CalendarConfig } from './calendar.config';

/**
 * OAuth 2.0 für Google und Microsoft — beide folgen demselben Ablauf
 * (Authorization Code + Refresh Token), deshalb eine gemeinsame Stelle.
 * Bewusst ohne SDK: zwei POST-Aufrufe sind weniger Abhängigkeit als zwei
 * Bibliotheken.
 */
@Injectable()
export class CalendarOAuthService {
  private readonly log = new Logger('CalendarOAuth');

  /** Kurzlebige State-Werte gegen untergeschobene Rückrufe (CSRF). */
  private readonly pendingStates = new Map<string, { trainerId: number; provider: CalendarProvider; at: number }>();

  constructor(
    @InjectRepository(CalendarConnection)
    private readonly repo: Repository<CalendarConnection>,
  ) {}

  private cfg(provider: CalendarProvider) {
    return provider === 'google' ? CalendarConfig.google : CalendarConfig.microsoft;
  }

  isConfigured(provider: CalendarProvider): boolean {
    return this.cfg(provider).isConfigured;
  }

  // ── Schritt 1: Anmeldeseite des Anbieters ────────────────────────

  buildAuthUrl(trainerId: number, provider: CalendarProvider): string {
    const cfg = this.cfg(provider);
    if (!cfg.isConfigured) {
      throw new BadRequestException(
        `${provider === 'google' ? 'Google' : 'Microsoft'} ist auf dem Server noch nicht eingerichtet.`,
      );
    }

    this.prunePendingStates();
    const state = crypto.randomBytes(24).toString('hex');
    this.pendingStates.set(state, { trainerId, provider, at: Date.now() });

    const params = new URLSearchParams({
      client_id: cfg.clientId,
      response_type: 'code',
      redirect_uri: CalendarConfig.redirectUri(provider),
      scope: cfg.scope,
      state,
    });
    if (provider === 'google') {
      // Nur mit consent + offline liefert Google verlässlich ein Refresh-Token
      params.set('access_type', 'offline');
      params.set('prompt', 'consent');
    }
    return `${cfg.authUrl}?${params.toString()}`;
  }

  /** Entwertet den State — jeder Rückruf gilt genau einmal. */
  consumeState(state: string): { trainerId: number; provider: CalendarProvider } {
    const entry = this.pendingStates.get(state);
    if (!entry) throw new BadRequestException('Die Verbindung ist abgelaufen. Bitte erneut starten.');
    this.pendingStates.delete(state);
    return { trainerId: entry.trainerId, provider: entry.provider };
  }

  private prunePendingStates() {
    const limit = Date.now() - 15 * 60 * 1000;
    for (const [k, v] of this.pendingStates) if (v.at < limit) this.pendingStates.delete(k);
  }

  // ── Schritt 2: Code gegen Token tauschen ─────────────────────────

  async exchangeCode(provider: CalendarProvider, code: string): Promise<CalendarConnection> {
    const cfg = this.cfg(provider);
    const body = new URLSearchParams({
      client_id: cfg.clientId,
      client_secret: cfg.clientSecret,
      code,
      grant_type: 'authorization_code',
      redirect_uri: CalendarConfig.redirectUri(provider),
    });

    const res = await fetch(cfg.tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    });
    if (!res.ok) {
      const text = await res.text();
      this.log.error(`Token-Tausch fehlgeschlagen (${provider}): ${res.status} ${text.slice(0, 200)}`);
      throw new BadRequestException('Die Verbindung konnte nicht hergestellt werden.');
    }
    const json = (await res.json()) as {
      access_token: string; refresh_token?: string; expires_in?: number; id_token?: string;
    };

    const conn = new CalendarConnection();
    conn.provider = provider;
    conn.accessToken = json.access_token;
    conn.refreshToken = json.refresh_token ?? null;
    conn.expiresAt = json.expires_in ? new Date(Date.now() + json.expires_in * 1000) : null;
    conn.accountEmail = this.emailFromIdToken(json.id_token);
    return conn;
  }

  /** E-Mail aus dem id_token lesen — nur zur Anzeige, ohne Signaturprüfung. */
  private emailFromIdToken(idToken?: string): string | null {
    if (!idToken) return null;
    try {
      const payload = idToken.split('.')[1];
      const json = JSON.parse(Buffer.from(payload, 'base64').toString('utf8'));
      return json.email ?? json.preferred_username ?? null;
    } catch {
      return null;
    }
  }

  // ── Schritt 3: Gültiges Token für API-Aufrufe ────────────────────

  /** Liefert ein gültiges Access-Token und erneuert es bei Bedarf. */
  async validAccessToken(conn: CalendarConnection): Promise<string> {
    const stillValid = conn.expiresAt && conn.expiresAt.getTime() - 60_000 > Date.now();
    if (stillValid) return conn.accessToken;
    if (!conn.refreshToken) return conn.accessToken; // ohne Refresh bleibt nur der Versuch

    const cfg = this.cfg(conn.provider);
    const body = new URLSearchParams({
      client_id: cfg.clientId,
      client_secret: cfg.clientSecret,
      refresh_token: conn.refreshToken,
      grant_type: 'refresh_token',
    });

    const res = await fetch(cfg.tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    });
    if (!res.ok) {
      const text = await res.text();
      this.log.warn(`Token-Erneuerung fehlgeschlagen (${conn.provider}): ${res.status} ${text.slice(0, 160)}`);
      throw new BadRequestException('Die Kalender-Verbindung ist abgelaufen. Bitte neu verbinden.');
    }
    const json = (await res.json()) as { access_token: string; refresh_token?: string; expires_in?: number };

    conn.accessToken = json.access_token;
    if (json.refresh_token) conn.refreshToken = json.refresh_token;
    conn.expiresAt = json.expires_in ? new Date(Date.now() + json.expires_in * 1000) : null;
    await this.repo.save(conn);
    return conn.accessToken;
  }
}
