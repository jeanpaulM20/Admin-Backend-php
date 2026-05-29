import {
  Controller, Get, Post, Param, Query, Req, Res,
  ParseIntPipe, ForbiddenException,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Public } from '../auth/decorators/public.decorator';
import { GarminService } from './garmin.service';

/**
 * Client-facing Garmin endpoints.
 * All endpoints (except /callback) require an x-auth-token.
 */
@Controller('api/garmin')
export class GarminController {
  constructor(private readonly garminService: GarminService) {}

  /** Check assertClientAccess — client can only access own data, trainer can access all */
  private assertClientAccess(req: Request, clientId: number) {
    const client = (req as any).currentClient;
    const trainer = (req as any).currentTrainer;
    if (trainer) return; // trainers can access any client
    if (client && String(client.id) === String(clientId)) return;
    throw new ForbiddenException('Access denied');
  }

  /** Get Garmin connection status for a client */
  @Get('status/:clientId')
  status(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.garminService.getStatus(clientId);
  }

  /**
   * Start OAuth flow — returns the Garmin authorization URL.
   * The Flutter app opens this URL in a new browser tab.
   */
  @Get('connect/:clientId')
  async connect(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.garminService.startOAuth(clientId);
  }

  /**
   * OAuth callback — Garmin redirects here after user authorizes.
   * This is a @Public endpoint (no auth token — it's a browser redirect).
   * After success, redirects the user back to the client app.
   */
  @Public()
  @Get('callback')
  async callback(
    @Query('oauth_token') oauthToken: string,
    @Query('oauth_verifier') oauthVerifier: string,
    @Res() res: Response,
  ) {
    try {
      const clientId = await this.garminService.handleCallback(oauthToken, oauthVerifier);
      // Redirect back to client app profile page with success indicator
      res.redirect(`/client/#/profile?garmin=connected`);
    } catch (err) {
      res.redirect(`/client/#/profile?garmin=error&message=${encodeURIComponent(err.message)}`);
    }
  }

  /** Disconnect Garmin */
  @Post('disconnect/:clientId')
  async disconnect(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.garminService.disconnect(clientId);
  }

  /** Get recent Garmin activities */
  @Get('activities/:clientId')
  async activities(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
    @Query('limit') limit?: string,
  ) {
    this.assertClientAccess(req, clientId);
    return this.garminService.getActivities(clientId, limit ? parseInt(limit) : 20);
  }

  /** Get daily health summaries */
  @Get('health/:clientId')
  async health(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
    @Query('days') days?: string,
  ) {
    this.assertClientAccess(req, clientId);
    return this.garminService.getDailySummaries(clientId, days ? parseInt(days) : 14);
  }
}
