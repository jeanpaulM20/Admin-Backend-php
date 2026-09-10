import {
  Controller, Get, Post, Delete, Body, Param, Query, Res, ParseIntPipe,
  BadRequestException, ForbiddenException,
} from '@nestjs/common';
import { Response } from 'express';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CalendarConnection, CalendarProvider } from './entities/calendar-connection.entity';
import { CalendarOAuthService } from './calendar-oauth.service';
import { CalendarSyncService } from './calendar-sync.service';
import { CalendarFeedService } from './calendar-feed.service';
import { CalendarConfig } from './calendar.config';
import { Public } from '../auth/decorators/public.decorator';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';
import { Trainer } from '../entities/trainer.entity';

const PROVIDERS: CalendarProvider[] = ['google', 'microsoft'];

function assertProvider(p: string): CalendarProvider {
  if (!PROVIDERS.includes(p as CalendarProvider)) {
    throw new BadRequestException(`Unbekannter Anbieter: ${p}`);
  }
  return p as CalendarProvider;
}

/** Nur der angemeldete Trainer selbst darf seine Kalender-Verbindungen
 *  sehen/ändern. Ohne diese Prüfung könnte jeder gültige Token (auch ein
 *  Client-Token) fremde trainerId aus der URL bedienen. */
function assertOwnTrainer(trainer: Trainer | null | undefined, trainerId: number): void {
  if (!trainer || trainer.id !== trainerId) {
    throw new ForbiddenException('Kein Zugriff auf diesen Trainer-Kalender.');
  }
}

@Controller('api/calendar')
export class CalendarController {
  constructor(
    @InjectRepository(CalendarConnection)
    private readonly repo: Repository<CalendarConnection>,
    private readonly oauth: CalendarOAuthService,
    private readonly sync: CalendarSyncService,
    private readonly feeds: CalendarFeedService,
  ) {}

  /** Welche Kalender sind verbunden — für die Anzeige im Trainerprofil. */
  @Get('status/:trainerId')
  async status(
    @CurrentTrainer() trainer: Trainer,
    @Param('trainerId', ParseIntPipe) trainerId: number,
  ) {
    assertOwnTrainer(trainer, trainerId);
    const conns = await this.repo.find({ where: { trainerId } });
    const of = (p: CalendarProvider) => {
      const c = conns.find((x) => x.provider === p);
      return {
        available: this.oauth.isConfigured(p),
        connected: !!c,
        accountEmail: c?.accountEmail ?? null,
        lastSyncAt: c?.lastSyncAt ?? null,
        lastSyncError: c?.lastSyncError ?? null,
      };
    };
    return { google: of('google'), microsoft: of('microsoft') };
  }

  /** Liefert die Anmeldeadresse des Anbieters — im Browser zu öffnen. */
  @Get('connect/:provider/:trainerId')
  connect(
    @CurrentTrainer() trainer: Trainer,
    @Param('provider') provider: string,
    @Param('trainerId', ParseIntPipe) trainerId: number,
  ) {
    assertOwnTrainer(trainer, trainerId);
    const p = assertProvider(provider);
    return { url: this.oauth.buildAuthUrl(trainerId, p) };
  }

  /** Rückruf des Anbieters — landet im Browser des Trainers. */
  @Public()
  @Get('callback/:provider')
  async callback(
    @Param('provider') provider: string,
    @Query('code') code: string,
    @Query('state') state: string,
    @Query('error') error: string,
    @Res() res: Response,
  ) {
    if (error) return res.send(this.page('Verbindung abgebrochen', error, false));
    if (!code || !state) return res.send(this.page('Unvollständige Antwort', 'Es fehlen Angaben des Anbieters.', false));

    try {
      const { trainerId, provider: p } = this.oauth.consumeState(state);
      assertProvider(provider);

      const fresh = await this.oauth.exchangeCode(p, code);
      const existing = await this.repo.findOne({ where: { trainerId, provider: p } });
      if (existing) {
        existing.accessToken = fresh.accessToken;
        // Google liefert das Refresh-Token nur beim ersten Mal
        if (fresh.refreshToken) existing.refreshToken = fresh.refreshToken;
        existing.expiresAt = fresh.expiresAt;
        existing.accountEmail = fresh.accountEmail ?? existing.accountEmail;
        existing.lastSyncError = null;
        await this.repo.save(existing);
      } else {
        fresh.trainerId = trainerId;
        await this.repo.save(fresh);
      }

      const name = p === 'google' ? 'Google Kalender' : 'Outlook';
      return res.send(this.page(`${name} verbunden`, 'Du kannst dieses Fenster schliessen.', true));
    } catch (e: any) {
      return res.send(this.page('Verbindung fehlgeschlagen', e?.message ?? 'Unbekannter Fehler', false));
    }
  }

  /**
   * Abgleich sofort auslösen, ohne auf den Zeitplan zu warten.
   * Seit Phase 2 genügt eine Quelle: Outlook ODER ein abonnierter Kalender.
   */
  @Post('sync/:trainerId')
  async syncNow(
    @CurrentTrainer() trainer: Trainer,
    @Param('trainerId', ParseIntPipe) trainerId: number,
  ) {
    assertOwnTrainer(trainer, trainerId);
    const outlook = await this.repo.findOne({ where: { trainerId, provider: 'microsoft' } });
    const feeds = await this.feeds.list(trainerId);
    if (!outlook && feeds.length === 0) {
      throw new BadRequestException('Es ist keine Quelle verbunden — Outlook oder ein Kalender-Abo.');
    }
    const changed = await this.sync.syncTrainerId(trainerId);
    return { success: true, changed };
  }

  // ── Abonnierte Fremdkalender (Phase 2) ──────────────────────────────────

  /** Abos des Trainers. Die Adressen kommen nur maskiert zurück. */
  @Get('feeds/:trainerId')
  async listFeeds(
    @CurrentTrainer() trainer: Trainer,
    @Param('trainerId', ParseIntPipe) trainerId: number,
  ) {
    assertOwnTrainer(trainer, trainerId);
    return this.feeds.list(trainerId);
  }

  /** Neues Abo anlegen; wird sofort einmal eingelesen. */
  @Post('feeds/:trainerId')
  async addFeed(
    @CurrentTrainer() trainer: Trainer,
    @Param('trainerId', ParseIntPipe) trainerId: number,
    @Body() body: { label?: string; url?: string },
  ) {
    assertOwnTrainer(trainer, trainerId);
    if (!body?.url) throw new BadRequestException('Es fehlt die Kalender-Adresse.');
    const feed = await this.feeds.add(trainerId, body.label ?? '', body.url);
    // Direkt spiegeln, damit die Zeit auch in Google sofort gesperrt ist.
    this.sync.syncTrainerId(trainerId).catch(() => undefined);
    return feed;
  }

  @Delete('feeds/:trainerId/:feedId')
  async removeFeed(
    @CurrentTrainer() trainer: Trainer,
    @Param('trainerId', ParseIntPipe) trainerId: number,
    @Param('feedId', ParseIntPipe) feedId: number,
  ) {
    assertOwnTrainer(trainer, trainerId);
    await this.feeds.remove(trainerId, feedId);
    return { success: true };
  }

  /** Belegte Zeiten aus allen Abos — für den Kalender in der Trainer-App. */
  @Get('busy/:trainerId')
  async busy(
    @CurrentTrainer() trainer: Trainer,
    @Param('trainerId', ParseIntPipe) trainerId: number,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    assertOwnTrainer(trainer, trainerId);
    const start = from ? new Date(from) : new Date();
    const end = to ? new Date(to) : new Date(Date.now() + CalendarConfig.syncDays * 86_400_000);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
      throw new BadRequestException('Ungültiger Zeitraum.');
    }
    const labels = await this.feeds.labels(trainerId);
    const rows = await this.feeds.busyFor(trainerId, start, end);
    return rows.map((r) => ({
      id: r.id,
      source: labels.get(r.feedId) ?? 'Externer Kalender',
      start: r.startsAt.toISOString(),
      end: r.endsAt.toISOString(),
      allDay: !!r.allDay,
    }));
  }

  @Delete(':provider/:trainerId')
  async disconnect(
    @CurrentTrainer() trainer: Trainer,
    @Param('provider') provider: string,
    @Param('trainerId', ParseIntPipe) trainerId: number,
  ) {
    assertOwnTrainer(trainer, trainerId);
    const p = assertProvider(provider);
    await this.repo.delete({ trainerId, provider: p });
    return { success: true };
  }

  /** Schlichte Rückmeldeseite für den Browser nach dem Rückruf. */
  private page(title: string, message: string, ok: boolean): string {
    const esc = (t: string) =>
      String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    title = esc(title);
    message = esc(message);
    const accent = ok ? '#636B2F' : '#C8532B';
    return `<!doctype html><html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#14170F;color:#EEF0E4;
font-family:-apple-system,system-ui,sans-serif;text-align:center;padding:24px}
.c{max-width:22rem}h1{font-size:1.35rem;margin:0 0 .5rem;color:${accent}}p{margin:0;color:#B8BCA8;line-height:1.5}</style>
</head><body><div class="c"><h1>${title}</h1><p>${message}</p></div></body></html>`;
  }
}
