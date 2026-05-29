import { Controller, Post, Body, Logger, HttpCode } from '@nestjs/common';
import { Public } from '../auth/decorators/public.decorator';
import { GarminService } from './garmin.service';

/**
 * Webhook endpoints called by Garmin when a user syncs their device.
 *
 * IMPORTANT: These are server-to-server calls from Garmin — no auth token.
 * They must return HTTP 200 within seconds (Garmin will retry otherwise).
 * All processing happens async after the response.
 *
 * Register these callback URLs in the Garmin Developer Portal:
 *   Activities:  POST https://your-domain/api/garmin/webhook/activities
 *   Dailies:     POST https://your-domain/api/garmin/webhook/dailies
 *   Deregistration: POST https://your-domain/api/garmin/webhook/deregistrations
 */
@Controller('api/garmin/webhook')
export class GarminWebhookController {
  private readonly logger = new Logger(GarminWebhookController.name);

  constructor(private readonly garminService: GarminService) {}

  /** Activity push — workout/exercise data */
  @Public()
  @Post('activities')
  @HttpCode(200)
  async activities(@Body() body: any) {
    this.logger.log(`Garmin activity webhook received: ${JSON.stringify(body).slice(0, 200)}`);
    // Process async — don't block the response
    setImmediate(() => {
      this.garminService.processActivities(body).catch((err) => {
        this.logger.error(`Activity processing failed: ${err.message}`);
      });
    });
    return { ok: true };
  }

  /** Daily summary push — steps, HR, stress, body battery, sleep */
  @Public()
  @Post('dailies')
  @HttpCode(200)
  async dailies(@Body() body: any) {
    this.logger.log(`Garmin dailies webhook received: ${JSON.stringify(body).slice(0, 200)}`);
    setImmediate(() => {
      this.garminService.processDailySummaries(body).catch((err) => {
        this.logger.error(`Dailies processing failed: ${err.message}`);
      });
    });
    return { ok: true };
  }

  /** Deregistration push — user revoked access in Garmin Connect */
  @Public()
  @Post('deregistrations')
  @HttpCode(200)
  async deregistrations(@Body() body: any) {
    this.logger.log(`Garmin deregistration webhook received`);
    setImmediate(() => {
      this.garminService.handleDeregistration(body).catch((err) => {
        this.logger.error(`Deregistration processing failed: ${err.message}`);
      });
    });
    return { ok: true };
  }
}
