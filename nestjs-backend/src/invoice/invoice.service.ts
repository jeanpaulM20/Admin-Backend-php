import { Injectable, Logger } from '@nestjs/common';
import { DataSource } from 'typeorm';
import * as nodemailer from 'nodemailer';

@Injectable()
export class InvoiceService {
  private readonly logger = new Logger('InvoiceService');

  constructor(private readonly dataSource: DataSource) {}

  /**
   * Creates an invoice record and returns the invoice number.
   */
  async createInvoice(data: {
    clientId: number;
    packageName: string;
    amount: number;
    credits: number;
    durationMonths: number;
  }): Promise<string> {
    // Get next invoice number (R + sequential)
    const [maxRow]: any = await this.dataSource.query(
      "SELECT MAX(id) as maxId FROM invoice",
    );
    const nextId = (maxRow?.maxId ?? 1500) + 1;
    const invoiceNumber = `R${nextId}`;

    await this.dataSource.query(
      `INSERT INTO invoice (invoice_number, client_id, package_name, amount, credits, duration_months, status)
       VALUES (?, ?, ?, ?, ?, ?, 'pending')`,
      [invoiceNumber, data.clientId, data.packageName, data.amount, data.credits, data.durationMonths],
    );

    this.logger.log(`Invoice ${invoiceNumber} created for client ${data.clientId}`);
    return invoiceNumber;
  }

  /**
   * Sends an invoice email to the client.
   */
  async sendInvoiceEmail(data: {
    invoiceNumber: string;
    clientName: string;
    clientEmail: string;
    packageName: string;
    credits: number;
    durationMonths: number;
    amount: number;
  }): Promise<boolean> {
    const smtpHost = process.env.SMTP_HOST;
    const smtpPort = parseInt(process.env.SMTP_PORT ?? '587');
    const smtpUser = process.env.SMTP_USER;
    const smtpPass = process.env.SMTP_PASS;
    const fromEmail = process.env.SMTP_FROM ?? 'info@sihltraining.ch';

    if (!smtpHost || !smtpUser || !smtpPass) {
      this.logger.warn('SMTP not configured — invoice email skipped. Set SMTP_HOST, SMTP_USER, SMTP_PASS env vars.');
      return false;
    }

    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465,
      auth: { user: smtpUser, pass: smtpPass },
    });

    const html = this.buildInvoiceHtml(data);

    try {
      await transporter.sendMail({
        from: `"SIHLHEALTH GmbH" <${fromEmail}>`,
        to: data.clientEmail,
        subject: `Rechnung ${data.invoiceNumber} – ${data.packageName}`,
        html,
      });
      this.logger.log(`Invoice email sent to ${data.clientEmail}`);
      return true;
    } catch (err: any) {
      this.logger.warn(`Failed to send invoice email: ${err.message}`);
      return false;
    }
  }

  private buildInvoiceHtml(data: {
    invoiceNumber: string;
    clientName: string;
    packageName: string;
    credits: number;
    durationMonths: number;
    amount: number;
  }): string {
    const today = new Date();
    const dateStr = today.toLocaleDateString('de-CH', { day: '2-digit', month: '2-digit', year: 'numeric' });
    const dueDate = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000);
    const dueDateStr = dueDate.toLocaleDateString('de-CH', { day: '2-digit', month: '2-digit', year: 'numeric' });
    const amountStr = data.amount.toLocaleString('de-CH', { minimumFractionDigits: 2 });

    return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><style>
  body { font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
  .header { border-bottom: 2px solid #c8a964; padding-bottom: 16px; margin-bottom: 24px; }
  .logo { font-size: 22px; font-weight: bold; color: #1a1a1a; }
  .logo span { color: #c8a964; }
  .invoice-title { font-size: 20px; font-weight: bold; margin: 20px 0 16px; }
  .meta { margin-bottom: 20px; }
  .meta-row { display: flex; margin-bottom: 4px; }
  .meta-label { width: 140px; color: #666; }
  table { width: 100%; border-collapse: collapse; margin: 20px 0; }
  th { background: #f5f5f5; text-align: left; padding: 10px; border-bottom: 2px solid #ddd; }
  td { padding: 10px; border-bottom: 1px solid #eee; }
  .total-row td { font-weight: bold; border-top: 2px solid #333; border-bottom: none; }
  .footer { margin-top: 30px; padding-top: 16px; border-top: 1px solid #ddd; font-size: 12px; color: #888; }
  .payment-info { background: #f9f7f2; padding: 16px; border-radius: 8px; margin: 20px 0; }
  .note { font-size: 12px; color: #888; margin-top: 16px; }
</style></head>
<body>
  <div class="header">
    <div class="logo">SIHL<span>HEALTH</span> GmbH</div>
  </div>

  <div class="invoice-title">Rechnung</div>

  <div class="meta">
    <div class="meta-row"><span class="meta-label">Rechnungs-Nr.:</span> <strong>${data.invoiceNumber}</strong></div>
    <div class="meta-row"><span class="meta-label">Datum:</span> ${dateStr}</div>
    <div class="meta-row"><span class="meta-label">Kunde:</span> ${data.clientName}</div>
    <div class="meta-row"><span class="meta-label">Zahlbar bis:</span> ${dueDateStr}</div>
  </div>

  <table>
    <thead>
      <tr><th>Beschreibung</th><th>Menge</th><th style="text-align:right">Betrag CHF</th></tr>
    </thead>
    <tbody>
      <tr>
        <td>
          <strong>Abonnement ${data.packageName}</strong><br>
          <span style="font-size:13px;color:#666">${data.credits} ${data.credits === 1 ? 'Lektion' : 'Lektionen'} &agrave; 60 Min. Personal Training<br>
          G&uuml;ltigkeit: ${data.durationMonths} ${data.durationMonths === 1 ? 'Monat' : 'Monate'}</span>
        </td>
        <td>1</td>
        <td style="text-align:right">${amountStr}</td>
      </tr>
      <tr class="total-row">
        <td colspan="2">Rechnungsbetrag CHF</td>
        <td style="text-align:right">${amountStr}</td>
      </tr>
    </tbody>
  </table>

  <div class="payment-info">
    <strong>Zahlungsinformationen</strong><br><br>
    SIHLHEALTH GmbH<br>
    IBAN: CH00 0000 0000 0000 0000 0 (bitte beim Studio erfragen)<br>
    Verwendungszweck: ${data.invoiceNumber}
  </div>

  <p class="note">SIHLHEALTH GmbH ist nicht MWST-pflichtig.</p>

  <div class="footer">
    SIHLHEALTH GmbH &middot; Z&uuml;rich<br>
    info@sihltraining.ch &middot; sihltraining.ch
  </div>
</body>
</html>`;
  }
}
