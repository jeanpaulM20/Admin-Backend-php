import {
  Controller, Get, Post, Put, Delete, Param, Body, Query,
  ParseIntPipe, NotFoundException,
} from '@nestjs/common';
import { ClientAppService } from './client-app.service';
import { ClientChatService } from './client-chat.service';
import { InvoiceService } from '../invoice/invoice.service';
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
    private readonly invoiceService: InvoiceService,
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

  /** Invoices */
  @Get('invoices/:clientId')
  invoices(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.invoiceService.getInvoices(clientId);
  }

  /** QR payment slip for a specific invoice (returns base64 PNG) */
  @Get('invoice-qr/:invoiceNumber')
  async invoiceQr(
    @Param('invoiceNumber') invoiceNumber: string,
    @Query('amount') amount: string,
  ) {
    const numAmount = parseFloat(amount);
    if (!numAmount || numAmount <= 0) {
      return { success: false, error: 'Invalid amount' };
    }
    const qrResult = await this.invoiceService.generateQrBill({
      amount: numAmount,
      invoiceNumber,
    });
    if ('error' in qrResult) {
      return { success: false, error: qrResult.error };
    }
    return { success: true, base64: qrResult.base64 };
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
}
