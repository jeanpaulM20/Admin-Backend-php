import {
  Controller, Get, Post, Delete, Param, Query, Res, ParseIntPipe, BadRequestException,
} from '@nestjs/common';
import { Response } from 'express';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CalendarConnection, CalendarProvider } from './entities/calendar-connection.entity';
import { CalendarOAuthService } from './calendar-oauth.service';
import { CalendarSyncService } from './calendar-sync.service';
import { CalendarConfig } from './calendar.config';
import { Public } from '../auth/decorators/public.decorator';

const PROVIDERS: CalendarProvider[] = ['google', 'microsoft'];

function assertProvider(p: string): CalendarProvider {
  if (!PROVIDERS.includes(p as CalendarProvider)) {
    throw new BadRequestException(`Unbekannter Anbieter: ${p}`);
  }
  return p as CalendarProvider;
}

@Controller('api/calendar')
export class CalendarController {
  constructor(
    @InjectRepository(CalendarConnection)
    private readonly repo: Repository<CalendarConnection>,
    private readonly oauth: CalendarOAuthService,
    private readonly sync: CalendarSyncService,
  ) {}

  /** Welche Kalender sind verbunden — für die Anzeige im Trainerprofil. */
  @Get('status/:trainerId')
  async status(@Param('trainerId', ParseIntPipe) trainerId: number) {
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
    @Param('provider') provider: string,
    @Param('trainerId', ParseIntPipe) trainerId: number,
  ) {
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

  /** Abgleich sofort auslösen, ohne auf den Zeitplan zu warten. */
  @Post('sync/:trainerId')
  async syncNow(@Param('trainerId', ParseIntPipe) trainerId: number) {
    const outlook = await this.repo.findOne({ where: { trainerId, provider: 'microsoft' } });
    const google = await this.repo.findOne({ where: { trainerId, provider: 'google' } });
    if (!outlook || !google) {
      throw new BadRequestException('Für den Abgleich müssen Outlook und Google verbunden sein.');
    }
    const changed = await this.sync.syncTrainer(outlook, google);
    return { success: true, changed };
  }

  @Delete(':provider/:trainerId')
  async disconnect(
    @Param('provider') provider: string,
    @Param('trainerId', ParseIntPipe) trainerId: number,
  ) {
    const p = assertProvider(provider);
    await this.repo.delete({ trainerId, provider: p });
    return { success: true };
  }

  /** Schlichte Rückmeldeseite für den Browser nach dem Rückruf. */
  private page(title: string, message: string, ok: boolean): string {
    const accent = ok ? '#636B2F' : '#C8532B';
    return `<!doctype html><html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#14170F;color:#EEF0E4;
font-family:-apple-system,system-ui,sans-serif;text-align:center;padding:24px}
.c{max-width:22rem}h1{font-size:1.35rem;margin:0 0 .5rem;color:${accent}}p{margin:0;color:#B8BCA8;line-height:1.5}</style>
</head><body><div class="c"><h1>${title}</h1><p>${message}</p></div></body></html>`;
  }
}
