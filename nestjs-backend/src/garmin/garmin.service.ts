import {
  Injectable, Logger, BadRequestException, NotFoundException,
  InternalServerErrorException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as crypto from 'crypto';
import { GarminConnection } from './entities/garmin-connection.entity';
import { GarminActivity } from './entities/garmin-activity.entity';
import { GarminDailySummary } from './entities/garmin-daily-summary.entity';

// ── OAuth 1.0a helpers ─────────────────────────────────────────────
// Garmin uses OAuth 1.0a with HMAC-SHA1 signed requests.
// We implement the signing inline to avoid extra dependencies.

function percentEncode(str: string): string {
  return encodeURIComponent(str)
    .replace(/!/g, '%21')
    .replace(/\*/g, '%2A')
    .replace(/'/g, '%27')
    .replace(/\(/g, '%28')
    .replace(/\)/g, '%29');
}

function hmacSha1(key: string, data: string): string {
  return crypto.createHmac('sha1', key).update(data).digest('base64');
}

function generateNonce(): string {
  return crypto.randomBytes(16).toString('hex');
}

interface OAuthParams {
  consumerKey: string;
  consumerSecret: string;
  token?: string;
  tokenSecret?: string;
  verifier?: string;
  callback?: string;
}

function buildOAuthHeader(
  method: string,
  url: string,
  params: OAuthParams,
  extraParams: Record<string, string> = {},
): string {
  const oauthParams: Record<string, string> = {
    oauth_consumer_key: params.consumerKey,
    oauth_nonce: generateNonce(),
    oauth_signature_method: 'HMAC-SHA1',
    oauth_timestamp: Math.floor(Date.now() / 1000).toString(),
    oauth_version: '1.0',
  };
  if (params.token) oauthParams.oauth_token = params.token;
  if (params.verifier) oauthParams.oauth_verifier = params.verifier;
  if (params.callback) oauthParams.oauth_callback = params.callback;

  // Combine all params for signature base string
  const allParams = { ...oauthParams, ...extraParams };
  const sortedKeys = Object.keys(allParams).sort();
  const paramString = sortedKeys
    .map((k) => `${percentEncode(k)}=${percentEncode(allParams[k])}`)
    .join('&');

  const signatureBase = `${method.toUpperCase()}&${percentEncode(url)}&${percentEncode(paramString)}`;
  const signingKey = `${percentEncode(params.consumerSecret)}&${percentEncode(params.tokenSecret ?? '')}`;
  const signature = hmacSha1(signingKey, signatureBase);

  oauthParams.oauth_signature = signature;
  const headerParts = Object.keys(oauthParams)
    .sort()
    .map((k) => `${percentEncode(k)}="${percentEncode(oauthParams[k])}"`)
    .join(', ');

  return `OAuth ${headerParts}`;
}

// ── Garmin API constants ───────────────────────────────────────────

const GARMIN_REQUEST_TOKEN_URL = 'https://connectapi.garmin.com/oauth-service/oauth/request_token';
const GARMIN_AUTHORIZE_URL = 'https://connect.garmin.com/oauthConfirm';
const GARMIN_ACCESS_TOKEN_URL = 'https://connectapi.garmin.com/oauth-service/oauth/access_token';

// ── In-memory store for pending OAuth flows ────────────────────────
// Maps request_token → { secret, clientId }
// Entries expire after 10 minutes.
interface PendingOAuth {
  tokenSecret: string;
  clientId: number;
  createdAt: number;
}

@Injectable()
export class GarminService {
  private readonly logger = new Logger(GarminService.name);

  // Temporary store for OAuth request tokens (cleared after 10 min)
  private pendingOAuth = new Map<string, PendingOAuth>();

  constructor(
    @InjectRepository(GarminConnection)
    private readonly connRepo: Repository<GarminConnection>,
    @InjectRepository(GarminActivity)
    private readonly activityRepo: Repository<GarminActivity>,
    @InjectRepository(GarminDailySummary)
    private readonly dailyRepo: Repository<GarminDailySummary>,
  ) {
    // Cleanup expired pending tokens every 5 minutes
    setInterval(() => this.cleanupPendingTokens(), 5 * 60 * 1000);
  }

  private get consumerKey(): string {
    return process.env.GARMIN_CONSUMER_KEY ?? '';
  }
  private get consumerSecret(): string {
    return process.env.GARMIN_CONSUMER_SECRET ?? '';
  }
  private get callbackBaseUrl(): string {
    return process.env.GARMIN_CALLBACK_BASE_URL ?? process.env.BASE_URL ?? 'https://admin-backend-php-production.up.railway.app';
  }

  private ensureConfigured() {
    if (!this.consumerKey || !this.consumerSecret) {
      throw new BadRequestException(
        'Garmin API not configured. Set GARMIN_CONSUMER_KEY and GARMIN_CONSUMER_SECRET.',
      );
    }
  }

  private cleanupPendingTokens() {
    const now = Date.now();
    for (const [token, data] of this.pendingOAuth.entries()) {
      if (now - data.createdAt > 10 * 60 * 1000) {
        this.pendingOAuth.delete(token);
      }
    }
  }

  // ── Public API ──────────────────────────────────────────────────

  /** Check if a client has an active Garmin connection */
  async getStatus(clientId: number) {
    const conn = await this.connRepo.findOne({ where: { clientId } });
    return {
      connected: !!conn,
      garminDisplayName: conn?.garminDisplayName ?? null,
      connectedAt: conn?.connectedAt ?? null,
      lastSyncAt: conn?.lastSyncAt ?? null,
      configured: !!(this.consumerKey && this.consumerSecret),
    };
  }

  /**
   * Step 1: Start OAuth flow.
   * Returns the Garmin authorization URL the client should be redirected to.
   */
  async startOAuth(clientId: number): Promise<{ authUrl: string }> {
    this.ensureConfigured();

    const callbackUrl = `${this.callbackBaseUrl}/api/garmin/callback`;

    // 1. Get request token from Garmin
    const authHeader = buildOAuthHeader('POST', GARMIN_REQUEST_TOKEN_URL, {
      consumerKey: this.consumerKey,
      consumerSecret: this.consumerSecret,
      callback: callbackUrl,
    });

    const response = await fetch(GARMIN_REQUEST_TOKEN_URL, {
      method: 'POST',
      headers: { Authorization: authHeader },
    });

    if (!response.ok) {
      const body = await response.text();
      this.logger.error(`Garmin request token failed: ${response.status} ${body}`);
      throw new InternalServerErrorException('Failed to start Garmin OAuth');
    }

    const body = await response.text();
    const params = new URLSearchParams(body);
    const oauthToken = params.get('oauth_token');
    const oauthTokenSecret = params.get('oauth_token_secret');

    if (!oauthToken || !oauthTokenSecret) {
      throw new InternalServerErrorException('Invalid Garmin OAuth response');
    }

    // Store the request token secret for the callback
    this.pendingOAuth.set(oauthToken, {
      tokenSecret: oauthTokenSecret,
      clientId,
      createdAt: Date.now(),
    });

    // 2. Return the authorization URL
    const authUrl = `${GARMIN_AUTHORIZE_URL}?oauth_token=${encodeURIComponent(oauthToken)}`;
    return { authUrl };
  }

  /**
   * Step 2: OAuth callback — exchange request token for access token.
   * Called by Garmin's redirect after user authorizes.
   */
  async handleCallback(oauthToken: string, oauthVerifier: string): Promise<number> {
    this.ensureConfigured();

    const pending = this.pendingOAuth.get(oauthToken);
    if (!pending) {
      throw new BadRequestException('Unknown or expired OAuth token');
    }
    this.pendingOAuth.delete(oauthToken);

    // Exchange for access token
    const authHeader = buildOAuthHeader('POST', GARMIN_ACCESS_TOKEN_URL, {
      consumerKey: this.consumerKey,
      consumerSecret: this.consumerSecret,
      token: oauthToken,
      tokenSecret: pending.tokenSecret,
      verifier: oauthVerifier,
    });

    const response = await fetch(GARMIN_ACCESS_TOKEN_URL, {
      method: 'POST',
      headers: { Authorization: authHeader },
    });

    if (!response.ok) {
      const body = await response.text();
      this.logger.error(`Garmin access token failed: ${response.status} ${body}`);
      throw new InternalServerErrorException('Failed to complete Garmin OAuth');
    }

    const body = await response.text();
    const params = new URLSearchParams(body);
    const accessToken = params.get('oauth_token');
    const accessTokenSecret = params.get('oauth_token_secret');

    if (!accessToken || !accessTokenSecret) {
      throw new InternalServerErrorException('Invalid Garmin access token response');
    }

    // Upsert connection for this client
    let conn = await this.connRepo.findOne({ where: { clientId: pending.clientId } });
    if (conn) {
      conn.accessToken = accessToken;
      conn.accessTokenSecret = accessTokenSecret;
      conn.connectedAt = new Date();
    } else {
      conn = this.connRepo.create({
        clientId: pending.clientId,
        accessToken,
        accessTokenSecret,
        connectedAt: new Date(),
      });
    }
    await this.connRepo.save(conn);

    this.logger.log(`Garmin connected for client ${pending.clientId}`);
    return pending.clientId;
  }

  /** Disconnect Garmin for a client */
  async disconnect(clientId: number) {
    const conn = await this.connRepo.findOne({ where: { clientId } });
    if (conn) {
      await this.connRepo.remove(conn);
    }
    return { success: true };
  }

  // ── Webhook handlers (called by Garmin push) ────────────────────

  /**
   * Process activity push from Garmin.
   * Garmin sends an array of activities; each has a userAccessToken we use
   * to look up the client.
   */
  async processActivities(payload: any) {
    const activities = payload?.activities ?? payload?.activityDetails ?? [];
    if (!Array.isArray(activities)) {
      this.logger.warn('Garmin activities webhook: invalid payload');
      return;
    }

    for (const act of activities) {
      try {
        const userToken = act.userAccessToken;
        const conn = await this.connRepo.findOne({ where: { accessToken: userToken } });
        if (!conn) {
          this.logger.warn(`Garmin activity: unknown userAccessToken`);
          continue;
        }

        const garminId = String(act.activityId ?? act.summaryId ?? '');
        if (!garminId) continue;

        // Upsert by garminActivityId (idempotent)
        let existing = await this.activityRepo.findOne({
          where: { garminActivityId: garminId },
        });

        const data = {
          clientId: conn.clientId,
          garminActivityId: garminId,
          garminUserToken: userToken,
          activityType: act.activityType ?? act.sportType ?? null,
          activityName: act.activityName ?? act.summary?.activityName ?? null,
          startTime: act.startTimeInSeconds
            ? new Date(act.startTimeInSeconds * 1000).toISOString()
            : act.startTimeLocal ?? null,
          durationSeconds: act.durationInSeconds ?? act.duration ?? null,
          distanceMeters: act.distanceInMeters ?? act.distance ?? null,
          activeKcal: act.activeKilocalories ?? act.calories ?? null,
          avgHeartRate: act.averageHeartRateInBeatsPerMinute ?? act.avgHr ?? null,
          maxHeartRate: act.maxHeartRateInBeatsPerMinute ?? act.maxHr ?? null,
          avgSpeed: act.averageSpeedInMetersPerSecond ?? null,
          steps: act.steps ?? null,
          rawJson: JSON.stringify(act),
        };

        if (existing) {
          Object.assign(existing, data);
          await this.activityRepo.save(existing);
        } else {
          await this.activityRepo.save(this.activityRepo.create(data));
        }

        // Update last sync timestamp
        conn.lastSyncAt = new Date();
        await this.connRepo.save(conn);
      } catch (err) {
        this.logger.error(`Garmin activity processing error: ${err.message}`, err.stack);
      }
    }
  }

  /**
   * Process daily summary push from Garmin.
   */
  async processDailySummaries(payload: any) {
    const summaries = payload?.dailies ?? payload?.allDayActivities ?? [];
    if (!Array.isArray(summaries)) {
      this.logger.warn('Garmin dailies webhook: invalid payload');
      return;
    }

    for (const s of summaries) {
      try {
        const userToken = s.userAccessToken;
        const conn = await this.connRepo.findOne({ where: { accessToken: userToken } });
        if (!conn) continue;

        const calendarDate = s.calendarDate ?? s.summaryDate ?? null;
        if (!calendarDate) continue;

        // Upsert by clientId + date
        let existing = await this.dailyRepo.findOne({
          where: { clientId: conn.clientId, calendarDate },
        });

        const data = {
          clientId: conn.clientId,
          calendarDate,
          steps: s.steps ?? null,
          activeKcal: s.activeKilocalories ?? s.activeCalories ?? null,
          restingHeartRate: s.restingHeartRateInBeatsPerMinute ?? s.restingHr ?? null,
          maxHeartRate: s.maxHeartRateInBeatsPerMinute ?? null,
          avgStress: s.averageStressLevel ?? null,
          bodyBatteryMax: s.bodyBatteryChargedValue ?? s.bodyBatteryMax ?? null,
          bodyBatteryMin: s.bodyBatteryDrainedValue ?? s.bodyBatteryMin ?? null,
          sleepDurationSeconds: s.sleepDurationInSeconds ?? null,
          sleepScore: s.overallSleepScore?.value ?? s.sleepScore ?? null,
          spo2Avg: s.averageSpo2 ?? null,
          respirationAvg: s.averageRespirationInBreathsPerMinute ?? null,
          floorsClimbed: s.floorsClimbed ?? null,
          intensityMinutes: Math.round(
            ((s.moderateIntensityDurationInSeconds ?? 0) + (s.vigorousIntensityDurationInSeconds ?? 0)) / 60,
          ) || undefined,
          rawJson: JSON.stringify(s),
        };

        if (existing) {
          Object.assign(existing, data);
          await this.dailyRepo.save(existing);
        } else {
          await this.dailyRepo.save(this.dailyRepo.create(data));
        }

        conn.lastSyncAt = new Date();
        await this.connRepo.save(conn);
      } catch (err) {
        this.logger.error(`Garmin daily processing error: ${err.message}`, err.stack);
      }
    }
  }

  // ── Client-facing data queries ──────────────────────────────────

  /** Get recent activities for a client */
  async getActivities(clientId: number, limit = 20) {
    return this.activityRepo.find({
      where: { clientId },
      order: { startTime: 'DESC' },
      take: limit,
      select: [
        'id', 'garminActivityId', 'activityType', 'activityName',
        'startTime', 'durationSeconds', 'distanceMeters', 'activeKcal',
        'avgHeartRate', 'maxHeartRate', 'steps', 'receivedAt',
      ],
    });
  }

  /** Get daily summaries for a client (last N days) */
  async getDailySummaries(clientId: number, days = 14) {
    const fromDate = new Date();
    fromDate.setDate(fromDate.getDate() - days);
    const fromStr = fromDate.toISOString().split('T')[0];

    return this.dailyRepo
      .createQueryBuilder('d')
      .where('d.client_id = :clientId', { clientId })
      .andWhere('d.calendar_date >= :fromStr', { fromStr })
      .orderBy('d.calendar_date', 'DESC')
      .getMany();
  }

  /** Deregistration webhook — Garmin notifies us when a user revokes access */
  async handleDeregistration(payload: any) {
    const deregistrations = payload?.deregistrations ?? [];
    for (const d of deregistrations) {
      const userToken = d.userAccessToken;
      if (!userToken) continue;
      const conn = await this.connRepo.findOne({ where: { accessToken: userToken } });
      if (conn) {
        this.logger.log(`Garmin deregistration for client ${conn.clientId}`);
        await this.connRepo.remove(conn);
      }
    }
  }
}
