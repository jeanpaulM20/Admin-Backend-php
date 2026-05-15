import {
  Controller, Get, Post, Put, Delete, Param, Body, Query,
  ParseIntPipe, NotFoundException,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { ClientAppService } from './client-app.service';
import { ClientChatService } from './client-chat.service';
import { Public } from '../auth/decorators/public.decorator';

/**
 * Client-app specific endpoints.
 *
 * These mirror the PHP endpoints the Flutter client-app calls:
 *   /api/client/start/:id    — dashboard data (credits + upcoming trainings)
 *   /api/client/calendar/:id — calendar data (trainers, types, availability, appointments)
 *   /api/client/profile/:id  — client profile
 *   /api/client/credits/:id  — credit packs
 *   /api/client/appointment  — book / cancel
 */
@Public()
@Controller('api/client')
export class ClientAppController {

  constructor(
    private readonly appService: ClientAppService,
    private readonly chatService: ClientChatService,
    private readonly dataSource: DataSource,
  ) {}

  /** Dashboard — credits + upcoming trainings */
  @Get('start/:clientId')
  start(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getStartData(clientId);
  }

  /** Calendar — trainers, types, availability, appointments */
  @Get('calendar/:clientId')
  calendar(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getCalendarData(clientId);
  }

  /** Profile */
  @Get('profile/:clientId')
  profile(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getProfile(clientId);
  }

  /** Credits */
  @Get('credits/:clientId')
  credits(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getCredits(clientId);
  }

  /** Available credit packages (pricing from website) */
  @Get('packages')
  packages() {
    return this.appService.getPackages();
  }

  /** Purchase a credit package (creates credits + invoice) */
  @Post('purchase/:clientId')
  purchase(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: { packageId: number },
  ) {
    return this.appService.purchasePackage(clientId, body.packageId);
  }

  /** Invoices (stub — Bexio integration to be migrated) */
  @Get('invoices/:clientId')
  invoices(@Param('clientId', ParseIntPipe) clientId: number) {
    return [];
  }

  /** Tests / Performance data */
  @Get('tests/:clientId')
  tests(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getTests(clientId);
  }

  /** Body metrics (Körperwerte) */
  @Get('metrics/:clientId')
  metrics(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getMetrics(clientId);
  }

  /** Training reviews — HR data + charts from review module */
  @Get('reviews/:clientId')
  reviews(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getReviews(clientId);
  }

  /** Client files */
  @Get('files/:clientId')
  files(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getFiles(clientId);
  }

  /** Polar status */
  @Get('polar/status/:clientId')
  polarStatus(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getPolarStatus(clientId);
  }

  /** Polar sync (stub) */
  @Post('polar/sync/:clientId')
  polarSync(@Param('clientId', ParseIntPipe) clientId: number) {
    return { success: true, message: 'Polar sync not yet migrated' };
  }

  /** Polar disconnect (stub) */
  @Post('polar/disconnect/:clientId')
  polarDisconnect(@Param('clientId', ParseIntPipe) clientId: number) {
    return { success: true };
  }

  // ── Preferences ───────────────────────────────────────────────────

  /** Get booking preferences (default trainer, type, location) */
  @Get('preferences/:clientId')
  preferences(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getPreferences(clientId);
  }

  /** Save booking preferences (partial update) */
  @Put('preferences/:clientId')
  savePreferences(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: Record<string, string | null>,
  ) {
    return this.appService.savePreferences(clientId, body);
  }

  // ── Appointments ─────────────────────────────────────────────────

  /** Book appointment */
  @Post('appointment/:clientId')
  book(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: any,
  ) {
    return this.appService.bookAppointment(clientId, body);
  }

  /** Cancel appointment */
  @Delete('appointment/:clientId/:appointmentId')
  cancel(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Param('appointmentId', ParseIntPipe) appointmentId: number,
  ) {
    return this.appService.cancelAppointment(clientId, appointmentId);
  }

  // ── Chat ──────────────────────────────────────────────────────────

  /** Chat conversations list (one per trainer) */
  @Get('chat/:clientId/conversations')
  chatConversations(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.chatService.getConversations(clientId);
  }

  /** Chat messages for a specific trainer */
  @Get('chat/:clientId/messages/:trainerId')
  chatMessages(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Param('trainerId', ParseIntPipe) trainerId: number,
  ) {
    return this.chatService.getMessages(clientId, trainerId);
  }

  /** Send a chat message to a trainer */
  @Post('chat/:clientId/messages/:trainerId')
  chatSend(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Param('trainerId', ParseIntPipe) trainerId: number,
    @Body() body: { text: string },
  ) {
    return this.chatService.sendMessage(clientId, trainerId, body.text);
  }

  /** Mark messages from trainer as read */
  @Post('chat/:clientId/messages/:trainerId/read')
  chatMarkRead(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Param('trainerId', ParseIntPipe) trainerId: number,
  ) {
    return this.chatService.markAsRead(clientId, trainerId);
  }

  // ── TEMP DEBUG: Data cleanup ─────────────────────────────────────
  @Get('debug/cleanup')
  async debugCleanup() {
    const log: string[] = [];
    try {
      // 1. Fix booking location_ids
      const activeLocations: any[] = await this.dataSource.query('SELECT id FROM location WHERE active = 1');
      const activeIds = activeLocations.map(r => r.id);
      log.push(`Active locations: ${JSON.stringify(activeIds)}`);

      const [sihl]: any = await this.dataSource.query("SELECT id FROM location WHERE name = 'Sportanlage Sihlhölzli' AND active = 1 LIMIT 1");
      if (sihl && activeIds.length > 0) {
        const ph = activeIds.map(() => '?').join(', ');
        const bookRes = await this.dataSource.query(
          `UPDATE training SET location_id = ? WHERE location_id IS NOT NULL AND location_id NOT IN (${ph})`,
          [sihl.id, ...activeIds],
        );
        log.push(`Booking fix: ${JSON.stringify(bookRes)}`);
      }

      // 2. Dedup availability
      const keepRows: any[] = await this.dataSource.query(
        'SELECT MIN(id) as keep_id FROM trainer_availability GROUP BY trainer_id, date, location_id, `from`, `to`',
      );
      const keepIds = keepRows.map(r => r.keep_id);
      log.push(`Keep ${keepIds.length} unique availability IDs`);

      if (keepIds.length > 0) {
        const kph = keepIds.map(() => '?').join(', ');
        const dedupRes = await this.dataSource.query(
          `DELETE FROM trainer_availability WHERE id NOT IN (${kph})`,
          keepIds,
        );
        log.push(`Dedup: ${JSON.stringify(dedupRes)}`);
      }

      // 3. Remove subsets
      const subsetRows: any[] = await this.dataSource.query(
        'SELECT sub.id as sub_id FROM trainer_availability sub INNER JOIN trainer_availability parent ON sub.trainer_id = parent.trainer_id AND sub.date = parent.date AND sub.location_id = parent.location_id AND sub.`from` >= parent.`from` AND sub.`to` <= parent.`to` AND sub.id != parent.id AND (sub.`from` > parent.`from` OR sub.`to` < parent.`to`)',
      );
      log.push(`Subset rows to remove: ${subsetRows.length}`);
      if (subsetRows.length > 0) {
        const sids = subsetRows.map(r => r.sub_id);
        const sph = sids.map(() => '?').join(', ');
        const subRes = await this.dataSource.query(`DELETE FROM trainer_availability WHERE id IN (${sph})`, sids);
        log.push(`Subset removal: ${JSON.stringify(subRes)}`);
      }

      // 4. Trim training type names
      await this.dataSource.query("UPDATE training_type SET name_de = TRIM(name_de) WHERE name_de LIKE '% '");
      log.push('Trimmed training type names');

      return { success: true, log };
    } catch (err: any) {
      return { success: false, error: err.message, stack: err.stack?.split('\n').slice(0, 5), log };
    }
  }
}
