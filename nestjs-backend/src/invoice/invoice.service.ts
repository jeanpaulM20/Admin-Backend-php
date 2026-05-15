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
   * Returns all invoices for a given client.
   */
  async getInvoices(clientId: number) {
    const rows: any[] = await this.dataSource.query(
      `SELECT invoice_number, package_name, amount, credits, duration_months, status, created_at
       FROM invoice WHERE client_id = ? ORDER BY created_at DESC`,
      [clientId],
    );
    return rows.map((r) => {
      const createdAt = r.created_at ? new Date(r.created_at) : new Date();
      const dueDate = new Date(createdAt.getTime() + 7 * 24 * 60 * 60 * 1000);
      return {
        invoiceNumber: r.invoice_number,
        packageName: r.package_name,
        amount: parseFloat(r.amount),
        credits: r.credits,
        durationMonths: r.duration_months,
        status: r.status,
        currency: 'CHF',
        transactionDate: createdAt.toISOString(),
        dueDate: dueDate.toISOString(),
      };
    });
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

  /** Format number Swiss-style: 6'900.00 */
  private formatCHF(n: number): string {
    const [intPart, decPart] = n.toFixed(2).split('.');
    const formatted = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, '’');
    return `${formatted}.${decPart}`;
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
    const amountStr = this.formatCHF(data.amount);
    const lektionenLabel = data.credits === 1 ? 'Lektion' : 'Lektionen';
    const monateLabel = data.durationMonths === 1 ? 'Monat' : 'Monate';

    return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><style>
  body { font-family: Arial, Helvetica, sans-serif; color: #1a1a1a; max-width: 640px; margin: 0 auto; padding: 32px 24px; font-size: 14px; line-height: 1.5; }
  .header { text-align: right; margin-bottom: 32px; }
  .logo { font-size: 20px; font-weight: bold; letter-spacing: 0.5px; }
  .meta-section { display: table; width: 100%; margin-bottom: 28px; }
  .meta-left, .meta-right { display: table-cell; vertical-align: top; }
  .meta-left { width: 50%; }
  .meta-right { width: 50%; text-align: right; padding-top: 4px; }
  .invoice-title { font-size: 18px; font-weight: bold; margin: 0 0 10px; }
  .meta-row { margin-bottom: 2px; font-size: 14px; }
  .meta-label { color: #555; }
  table { width: 100%; border-collapse: collapse; margin: 24px 0 6px; }
  th { font-weight: bold; font-size: 13px; padding: 6px 8px; border-top: 1px solid #1a1a1a; border-bottom: 1px solid #1a1a1a; }
  th.r { text-align: right; }
  td { padding: 8px 8px 4px; font-size: 13px; vertical-align: top; }
  td.r { text-align: right; }
  .desc-sub { font-size: 12px; color: #444; line-height: 1.4; margin-top: 2px; }
  .incl-section td { padding-top: 12px; }
  .incl-title { font-size: 13px; margin-bottom: 4px; }
  .incl-item { font-size: 12px; color: #444; margin-bottom: 2px; }
  .total-row td { font-weight: bold; font-size: 14px; padding: 8px; border-top: 1px solid #1a1a1a; border-bottom: 1px solid #1a1a1a; }
  .vat-note { text-align: right; font-size: 11px; color: #555; margin: 4px 0 24px; }
  .payment-text { font-size: 14px; margin: 24px 0; line-height: 1.6; }
  .signature { font-size: 14px; margin: 20px 0 40px; }
  .divider { border: none; border-top: 1px solid #1a1a1a; margin: 0 0 12px; }
  .footer-section { display: table; width: 100%; font-size: 12px; color: #444; }
  .footer-col { display: table-cell; vertical-align: top; }
  .footer-col.addr { width: 30%; }
  .footer-col.contact { width: 35%; }
  .footer-col.bank { width: 35%; }
</style></head>
<body>
  <div class="header">
    <div class="logo">SIHLHEALTH GmbH</div>
  </div>

  <div class="meta-section">
    <div class="meta-left">
      <div class="invoice-title">Rechnung</div>
      <div class="meta-row"><span class="meta-label">Datum:</span> ${dateStr}</div>
      <div class="meta-row"><span class="meta-label">Rechnungs-Nr.:</span> ${data.invoiceNumber}</div>
    </div>
    <div class="meta-right">
      <div style="font-size:14px">${data.clientName}</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="text-align:left">Beschreibung</th>
        <th class="r">Menge</th>
        <th class="r">Einheit</th>
        <th class="r">Preis CHF</th>
        <th class="r">Betrag CHF</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>
          <strong>${data.packageName} Abonnement</strong>
          <div class="desc-sub">
            ${data.credits} Pers&ouml;nliches Fitness- und Gesundheitstraining ${lektionenLabel} 50 Minuten pro Lektion<br>
            ${data.durationMonths} ${monateLabel} Laufzeit
          </div>
        </td>
        <td class="r">1</td>
        <td class="r">${data.credits}</td>
        <td class="r">${amountStr}</td>
        <td class="r">${amountStr}</td>
      </tr>
      <tr class="incl-section">
        <td colspan="5">
          <div class="incl-title">Inklusive:</div>
          <div class="incl-item">+ Leistungsanalyse</div>
          <div class="incl-item">+ Training Service</div>
        </td>
      </tr>
      <tr class="total-row">
        <td colspan="4"><strong>Rechnungsbetrag CHF</strong></td>
        <td class="r"><strong>${amountStr}</strong></td>
      </tr>
    </tbody>
  </table>

  <div class="vat-note">SIHLHEALTH GmbH ist nicht MWST-pflichtig.</div>

  <div class="payment-text">
    Ich bedanke mich f&uuml;r Ihre &Uuml;berweisung innerhalb von <strong>7 Tagen</strong> bis zum ${dueDateStr}.<br>
    Freundliche Gr&uuml;sse
  </div>

  <div class="signature">Jean-Paul Mvongo</div>

  <hr class="divider">

  <div class="footer-section">
    <div class="footer-col addr">
      Jean-Paul Mvongo<br>
      Nidelbadstrasse 50<br>
      8038 Z&uuml;rich
    </div>
    <div class="footer-col contact">
      Tel.: +41 79 522 30 83<br>
      E-Mail: jean-paul.mvongo@sihltraining.ch<br>
      Web: www.sihltraining.ch
    </div>
    <div class="footer-col bank">
      Bank: UBS SWITZERLAND AG<br>
      IBAN: CH26 0020 6206 5500 3901 Z<br>
      BIC: UBSWCHZH80A<br>
      Verwendungszweck: ${data.invoiceNumber}
    </div>
  </div>
</body>
</html>`;
  }
}
