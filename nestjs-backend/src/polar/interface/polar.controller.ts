import {
  BadGatewayException, BadRequestException, ConflictException, Controller, ForbiddenException, Get,
  HttpException, HttpStatus, Inject, Param, ParseIntPipe, Post, Query, Req, Res, ServiceUnavailableException,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Public } from '../../auth/decorators/public.decorator';
import { ConnectPlatform } from '../domain/oauth-state';
import {
  PolarApiError, PolarConsentMissingError, PolarNotConfiguredError, PolarNotConnectedError,
  PolarRateLimitedError, PolarUnauthorizedError,
} from '../application/ports';
import { PolarConnectUseCase } from '../application/polar-connect.usecase';
import { PolarSyncUseCase } from '../application/polar-sync.usecase';
import { PolarConfig } from './polar.config';
import { POLAR_CONFIG, POLAR_CONNECT, POLAR_SYNC } from './polar.provider';

/**
 * Polar AccessLink für die Client-Apps. Pfade wie die früheren Platzhalter
 * in ClientAppController — die Apps bleiben kompatibel.
 */
@Controller('api/client/polar')
export class PolarController {
  constructor(
    @Inject(POLAR_CONNECT) private readonly connect: PolarConnectUseCase,
    @Inject(POLAR_SYNC) private readonly syncer: PolarSyncUseCase,
    @Inject(POLAR_CONFIG) private readonly config: PolarConfig,
  ) {}

  /** Client nur eigene Daten, Trainer alle — wie ClientAppController. */
  private assertClientAccess(req: Request, clientId: number) {
    const client = (req as any).currentClient;
    const trainer = (req as any).currentTrainer;
    if (trainer) return;
    if (client && String(client.id) === String(clientId)) return;
    throw new ForbiddenException('Access denied');
  }

  /** Status; `connectUrl` öffnet die Polar-Anmeldung (platform=ios → Rücksprung in die App). */
  @Get('status/:clientId')
  status(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
    @Query('platform') platform?: string,
  ) {
    this.assertClientAccess(req, clientId);
    return this.connect.status(clientId, toPlatform(platform));
  }

  /**
   * Polar leitet den Browser nach der Anmeldung hierher. Öffentlich (kein
   * App-Token im Browser) — wer verbunden wird, sagt der signierte state.
   */
  @Public()
  @Get('callback')
  async callback(
    @Query('code') code: string | undefined,
    @Query('state') state: string | undefined,
    @Query('error') error: string | undefined,
    @Res() res: Response,
  ) {
    const outcome = await this.connect.completeAuthorization({ code, state, error });
    const params = outcome.ok
      ? new URLSearchParams({ status: 'connected' })
      : new URLSearchParams({ status: 'error', message: outcome.message });

    if (outcome.platform === 'ios') {
      res.redirect(`${this.config.iosReturnUrl}?${params.toString()}`);
    } else {
      const polarParams = new URLSearchParams({ polar: params.get('status')!, ...(outcome.ok ? {} : { message: outcome.message }) });
      res.redirect(`${this.config.webReturnUrl}?${polarParams.toString()}`);
    }
  }

  @Post('sync/:clientId')
  async sync(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    try {
      const report = await this.syncer.sync(clientId);
      return { success: true, ...report, message: syncMessage(report.imported) };
    } catch (e) {
      throw toHttp(e);
    }
  }

  @Post('disconnect/:clientId')
  async disconnect(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    await this.connect.disconnect(clientId);
    return { success: true };
  }
}

function toPlatform(raw: string | undefined): ConnectPlatform {
  return raw === 'ios' ? 'ios' : 'web';
}

function syncMessage(imported: number): string {
  if (imported === 0) return 'Keine neuen Polar-Trainings';
  return imported === 1 ? '1 Polar-Training importiert' : `${imported} Polar-Trainings importiert`;
}

/**
 * Fachfehler → HTTP. Bewusst nie 401: Die Apps werten 401 als
 * „App-Login ungültig" — ein abgelaufenes Polar-Token ist etwas anderes.
 */
function toHttp(e: unknown): HttpException {
  if (e instanceof HttpException) return e;
  if (e instanceof PolarNotConfiguredError) return new ServiceUnavailableException(e.message);
  if (e instanceof PolarNotConnectedError) return new BadRequestException(e.message);
  if (e instanceof PolarUnauthorizedError) return new ConflictException(e.message);
  if (e instanceof PolarConsentMissingError) return new ConflictException(e.message);
  if (e instanceof PolarRateLimitedError) return new HttpException(e.message, HttpStatus.TOO_MANY_REQUESTS);
  if (e instanceof PolarApiError) return new BadGatewayException(e.message);
  return new BadGatewayException('Polar-Sync fehlgeschlagen');
}
