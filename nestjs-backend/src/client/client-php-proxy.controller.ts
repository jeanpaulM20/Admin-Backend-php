import {
  Controller, Get, Post, Put, Delete, Param, Body, Query, Res, Req,
  ParseIntPipe, NotFoundException, ForbiddenException,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { ClientAppService } from './client-app.service';
import { ClientChatService } from './client-chat.service';
import { InvoiceService } from '../invoice/invoice.service';
import { SaferpayService } from '../payment/saferpay.service';
import { Public } from '../auth/decorators/public.decorator';

/**
 * Client-app specific endpoints.
 *
 * Auth: all endpoints require a valid x-auth-token.
 * - Client tokens: can only access their own data (clientId must match)
 * - Trainer tokens: can access any client's data
 * - Saferpay callbacks (return/abort/notify) are @Public (server-to-server)
 */
@Controller('api/client')
export class ClientAppController {

  constructor(
    private readonly appService: ClientAppService,
    private readonly chatService: ClientChatService,
    private readonly invoiceService: InvoiceService,
    private readonly saferpayService: SaferpayService,
  ) {}

  /**
   * Verify the authenticated user is allowed to access data for `clientId`.
   * Trainers can access any client. Clients can only access their own data.
   */
  private assertClientAccess(req: Request, clientId: number): void {
    const trainer = (req as any).currentTrainer;
    if (trainer) return; // trainers have full access

    const client = (req as any).currentClient;
    if (!client || client.id !== clientId) {
      throw new ForbiddenException('Zugriff verweigert');
    }
  }

  /** Dashboard — credits + upcoming trainings */
  @Get('start/:clientId')
  start(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.appService.getStartData(clientId);
  }

  /** Calendar — trainers, types, availability, appointments */
  @Get('calendar/:clientId')
  calendar(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.appService.getCalendarData(clientId);
  }

  /** Profile */
  @Get('profile/:clientId')
  profile(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.appService.getProfile(clientId);
  }

  /** Credits */
  @Get('credits/:clientId')
  credits(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.appService.getCredits(clientId);
  }

  /** Available credit packages (pricing from website — read-only, no clientId) */
  @Get('packages')
  packages() {
    return this.appService.getPackages();
  }

  /** Purchase a credit package (creates credits + invoice) */
  @Post('purchase/:clientId')
  purchase(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: { packageId: number },
  ) {
    this.assertClientAccess(req, clientId);
    return this.appService.purchasePackage(clientId, body.packageId);
  }

  /** Invoices */
  @Get('invoices/:clientId')
  invoices(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.invoiceService.getInvoices(clientId);
  }

  /** QR payment slip for a specific invoice (returns base64 PNG).
   *  Amount is looked up from the DB — client-supplied amount is ignored for security.
   */
  @Get('invoice-qr/:invoiceNumber')
  async invoiceQr(
    @Req() req: Request,
    @Param('invoiceNumber') invoiceNumber: string,
  ) {
    const invoice = await this.invoiceService.getInvoiceByNumber(invoiceNumber);
    if (!invoice) {
      return { success: false, error: 'Invoice not found' };
    }
    // Verify ownership: client can only access their own invoices
    if (invoice.client_id) {
      this.assertClientAccess(req, invoice.client_id);
    }
    const numAmount = parseFloat(invoice.amount);
    if (!numAmount || numAmount <= 0) {
      return { success: false, error: 'Invalid invoice amount' };
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
  tests(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.appService.getTests(clientId);
  }

  /** Body metrics (Körperwerte) */
  @Get('metrics/:clientId')
  metrics(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.appService.getMetrics(clientId);
  }

  /** Training reviews — HR data + charts from review module */
  @Get('reviews/:clientId')
  reviews(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.appService.getReviews(clientId);
  }

  /** Client files */
  @Get('files/:clientId')
  files(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.appService.getFiles(clientId);
  }

  /** Polar status */
  @Get('polar/status/:clientId')
  polarStatus(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.appService.getPolarStatus(clientId);
  }

  /** Polar sync (stub) */
  @Post('polar/sync/:clientId')
  polarSync(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return { success: true, message: 'Polar sync not yet migrated' };
  }

  /** Polar disconnect (stub) */
  @Post('polar/disconnect/:clientId')
  polarDisconnect(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return { success: true };
  }

  // ── Preferences ───────────────────────────────────────────────────

  /** Get booking preferences (default trainer, type, location) */
  @Get('preferences/:clientId')
  preferences(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.appService.getPreferences(clientId);
  }

  /** Save booking preferences (partial update) */
  @Put('preferences/:clientId')
  savePreferences(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: Record<string, string | null>,
  ) {
    this.assertClientAccess(req, clientId);
    return this.appService.savePreferences(clientId, body);
  }

  // ── Appointments ─────────────────────────────────────────────────

  /** Book appointment */
  @Post('appointment/:clientId')
  book(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: any,
  ) {
    this.assertClientAccess(req, clientId);
    return this.appService.bookAppointment(clientId, body);
  }

  /** Cancel appointment */
  @Delete('appointment/:clientId/:appointmentId')
  cancel(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
    @Param('appointmentId', ParseIntPipe) appointmentId: number,
  ) {
    this.assertClientAccess(req, clientId);
    return this.appService.cancelAppointment(clientId, appointmentId);
  }

  // ── Saferpay Online Payment ────────────────────────────────────────

  /** Check whether Saferpay online payment is available */
  @Get('payment/available')
  paymentAvailable() {
    return { available: this.saferpayService.isConfigured() };
  }

  /**
   * Initialize a Saferpay payment for a package purchase.
   * Creates invoice + credits first, then starts payment.
   * Returns { redirectUrl } for Flutter to open in WebView/browser.
   */
  @Post('payment/initialize/:clientId')
  async paymentInitialize(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: { packageId: number },
  ) {
    this.assertClientAccess(req, clientId);
    if (!this.saferpayService.isConfigured()) {
      return { success: false, error: 'Online-Zahlung nicht verfügbar' };
    }

    // 1. Execute purchase (creates credits + invoice with status 'pending')
    const purchaseResult = await this.appService.purchasePackage(clientId, body.packageId);
    if (!purchaseResult.success) {
      return { success: false, error: purchaseResult.message ?? 'Kauf fehlgeschlagen' };
    }

    // 2. Get invoice details
    const invoice = await this.invoiceService.getInvoiceByNumber(purchaseResult.invoiceNumber);
    if (!invoice) {
      return { success: false, error: 'Rechnung nicht gefunden' };
    }

    // 3. Initialize Saferpay payment
    const result = await this.saferpayService.initialize({
      invoiceNumber: purchaseResult.invoiceNumber,
      amount: parseFloat(invoice.amount),
      description: `SIHLHEALTH – ${invoice.package_name}`,
      clientId,
    });

    if ('error' in result) {
      return { success: false, error: result.error, invoiceNumber: purchaseResult.invoiceNumber };
    }

    // 4. Store token for later assert
    await this.invoiceService.storePaymentToken(purchaseResult.invoiceNumber, result.token);

    return {
      success: true,
      redirectUrl: result.redirectUrl,
      invoiceNumber: purchaseResult.invoiceNumber,
    };
  }

  /**
   * Return URL — user is redirected here after successful payment.
   * Asserts + captures the payment, then shows a simple HTML result page.
   * @Public because user is redirected here from Saferpay (no auth header).
   */
  @Public()
  @Get('payment/return')
  async paymentReturn(
    @Query('invoiceNumber') invoiceNumber: string,
    @Query('clientId') clientId: string,
    @Res() res: Response,
  ) {
    let status = 'success';
    let message = 'Zahlung erfolgreich! Du kannst dieses Fenster schliessen und zur App zurueckkehren.';

    try {
      // 1. Get stored token
      const invoice = await this.invoiceService.getInvoiceByNumber(invoiceNumber);
      if (!invoice?.saferpay_token) {
        status = 'error';
        message = 'Zahlungstoken nicht gefunden.';
      } else {
        // 2. Assert payment
        const assertResult = await this.saferpayService.assert(invoice.saferpay_token);
        if ('error' in assertResult) {
          status = 'error';
          message = `Zahlungsverifikation fehlgeschlagen: ${assertResult.error}`;
        } else {
          // 3. Capture if only authorized
          if (assertResult.status === 'AUTHORIZED') {
            const captureResult = await this.saferpayService.capture(assertResult.transactionId);
            if ('error' in captureResult) {
              status = 'error';
              message = `Zahlungsabschluss fehlgeschlagen: ${captureResult.error}`;
            }
          }

          if (status === 'success') {
            // 4. Mark invoice as paid
            const method = assertResult.brand ?? assertResult.paymentMethod ?? 'online';
            await this.invoiceService.markInvoicePaid(invoiceNumber, method);
          }
        }
      }
    } catch (err: any) {
      status = 'error';
      message = `Fehler: ${err.message}`;
    }

    return res.type('html').send(this.buildResultPage(status, message, invoiceNumber));
  }

  /** Abort URL — user cancelled the payment. @Public (redirect from Saferpay). */
  @Public()
  @Get('payment/abort')
  async paymentAbort(
    @Query('invoiceNumber') invoiceNumber: string,
    @Query('clientId') clientId: string,
    @Res() res: Response,
  ) {
    return res.type('html').send(this.buildResultPage(
      'cancelled',
      'Zahlung abgebrochen. Du kannst dieses Fenster schliessen und es erneut versuchen.',
      invoiceNumber,
    ));
  }

  /** HTML-escape to prevent XSS */
  private esc(s: string): string {
    return (s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  /** Generates a simple branded HTML result page */
  private buildResultPage(status: string, message: string, invoiceNumber: string): string {
    const icon = status === 'success' ? '&#10004;' : status === 'cancelled' ? '&#10060;' : '&#9888;';
    const color = status === 'success' ? '#22c55e' : status === 'cancelled' ? '#f97316' : '#ef4444';
    const title = status === 'success' ? 'Zahlung erfolgreich' : status === 'cancelled' ? 'Zahlung abgebrochen' : 'Fehler';
    const safeTitle = this.esc(title);
    const safeMessage = this.esc(message);
    const safeInvoice = this.esc(invoiceNumber);
    return `<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${safeTitle} – SIHLHEALTH</title>
<style>
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0a0a0a;color:#e5e5e5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif}
.card{text-align:center;padding:40px;max-width:420px;background:#171717;border-radius:16px;border:1px solid #262626}
.icon{font-size:48px;margin-bottom:16px;color:${color}}
h1{font-size:22px;margin:0 0 12px;font-weight:700}
p{font-size:14px;color:#a3a3a3;line-height:1.6;margin:0 0 20px}
.inv{font-size:12px;color:#525252;margin-top:8px}
</style></head><body>
<div class="card">
<div class="icon">${icon}</div>
<h1>${safeTitle}</h1>
<p>${safeMessage}</p>
<div class="inv">Rechnung: ${safeInvoice}</div>
</div></body></html>`;
  }

  /** Notification URL — server-to-server callback from Saferpay. @Public. */
  @Public()
  @Post('payment/notify')
  async paymentNotify(
    @Query('invoiceNumber') invoiceNumber: string,
  ) {
    // Saferpay sends a notification when payment status changes.
    // We use the return URL flow as primary, this is a fallback.
    try {
      const invoice = await this.invoiceService.getInvoiceByNumber(invoiceNumber);
      if (!invoice?.saferpay_token || invoice.status === 'paid') {
        return { ok: true };
      }

      const assertResult = await this.saferpayService.assert(invoice.saferpay_token);
      if ('error' in assertResult) return { ok: false };

      if (assertResult.status === 'AUTHORIZED') {
        await this.saferpayService.capture(assertResult.transactionId);
      }

      const method = assertResult.brand ?? assertResult.paymentMethod ?? 'online';
      await this.invoiceService.markInvoicePaid(invoiceNumber, method);

      return { ok: true };
    } catch {
      return { ok: false };
    }
  }

  /**
   * Flutter polls this after WebView closes to check payment status.
   */
  @Get('payment/status/:invoiceNumber')
  async paymentStatus(
    @Req() req: Request,
    @Param('invoiceNumber') invoiceNumber: string,
  ) {
    const invoice = await this.invoiceService.getInvoiceByNumber(invoiceNumber);
    if (!invoice) {
      return { success: false, error: 'Rechnung nicht gefunden' };
    }
    // Verify ownership: client can only check their own invoices
    if (invoice.client_id) {
      this.assertClientAccess(req, invoice.client_id);
    }
    return {
      success: true,
      status: invoice.status, // 'pending' or 'paid'
      invoiceNumber: invoice.invoice_number,
    };
  }

  // ── Chat ──────────────────────────────────────────────────────────

  /** Chat conversations list (one per trainer) */
  @Get('chat/:clientId/conversations')
  chatConversations(@Req() req: Request, @Param('clientId', ParseIntPipe) clientId: number) {
    this.assertClientAccess(req, clientId);
    return this.chatService.getConversations(clientId);
  }

  /** Chat messages for a specific trainer */
  @Get('chat/:clientId/messages/:trainerId')
  chatMessages(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
    @Param('trainerId', ParseIntPipe) trainerId: number,
  ) {
    this.assertClientAccess(req, clientId);
    return this.chatService.getMessages(clientId, trainerId);
  }

  /** Send a chat message to a trainer */
  @Post('chat/:clientId/messages/:trainerId')
  chatSend(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
    @Param('trainerId', ParseIntPipe) trainerId: number,
    @Body() body: { text: string },
  ) {
    this.assertClientAccess(req, clientId);
    return this.chatService.sendMessage(clientId, trainerId, body.text);
  }

  /** Mark messages from trainer as read */
  @Post('chat/:clientId/messages/:trainerId/read')
  chatMarkRead(
    @Req() req: Request,
    @Param('clientId', ParseIntPipe) clientId: number,
    @Param('trainerId', ParseIntPipe) trainerId: number,
  ) {
    this.assertClientAccess(req, clientId);
    return this.chatService.markAsRead(clientId, trainerId);
  }
}
