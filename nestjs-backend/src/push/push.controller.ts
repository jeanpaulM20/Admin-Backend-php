import { Controller, Get, Post, Delete, Param, Body, ParseIntPipe } from '@nestjs/common';
import { Public } from '../auth/decorators/public.decorator';
import { PushService } from './push.service';

/**
 * Push notification endpoints for the client Flutter app.
 * Public (no auth guard) — same as other client endpoints.
 */
@Public()
@Controller('api/client/push')
export class PushController {
  constructor(private readonly pushService: PushService) {}

  /** GET /api/client/push/vapid-key — return public VAPID key */
  @Get('vapid-key')
  getVapidKey() {
    const key = this.pushService.getPublicKey();
    return { publicKey: key };
  }

  /** POST /api/client/push/:clientId/subscribe — register a push subscription */
  @Post(':clientId/subscribe')
  subscribe(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: { endpoint: string; keys: { p256dh: string; auth: string } },
  ) {
    return this.pushService.subscribe(
      clientId,
      body.endpoint,
      body.keys.p256dh,
      body.keys.auth,
    );
  }

  /** POST /api/client/push/:clientId/unsubscribe — remove a push subscription */
  @Post(':clientId/unsubscribe')
  unsubscribe(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: { endpoint: string },
  ) {
    return this.pushService.unsubscribe(clientId, body.endpoint);
  }
}
