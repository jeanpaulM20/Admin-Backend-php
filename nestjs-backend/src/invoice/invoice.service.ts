import { Injectable, Logger } from '@nestjs/common';
import { DataSource } from 'typeorm';
import * as nodemailer from 'nodemailer';
import * as PDFDocument from 'pdfkit';
import * as https from 'https';

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

  // ── QR-Rechnung (Swiss QR Bill) ─────────────────────────────────
  private static readonly QR_API_URL = 'https://qr-rechnung-api.ch/api/v1/qr-bill/create';
  private static readonly CREDITOR = {
    Account: 'CH260020620655003901Z',
    CreditorName: 'SIHLHEALTH GmbH',
    CreditorStreetName: 'Nidelbadstrasse',
    CreditorHouseNumber: '50',
    CreditorZip: '8038',
    CreditorTown: 'Zurich',
    CreditorCountryCode: 'CH',
  };

  /**
   * Generates a Swiss QR bill payment slip via qr-rechnung-api.ch.
   * Returns base64-encoded PNG or null if API key is missing / call fails.
   */
  async generateQrBill(data: {
    amount: number;
    invoiceNumber: string;
    debtorName?: string;
  }): Promise<{ base64: string } | { error: string }> {
    const apiKey = process.env.QR_BILL_API_KEY;
    if (!apiKey) {
      this.logger.warn('QR_BILL_API_KEY not set — QR bill skipped');
      return { error: 'QR_BILL_API_KEY not configured' };
    }

    const params = new URLSearchParams({
      ...InvoiceService.CREDITOR,
      Amount: data.amount.toFixed(2),
      Currency: 'CHF',
      UnstructuredMessage: `Rechnung ${data.invoiceNumber}`,
      GraphicsFormat: 'PNG',
      OutputSize: 'bill-with-separator',
      Language: 'DE',
    });
    if (data.debtorName) {
      params.set('DebtorName', data.debtorName);
    }

    try {
      const body = params.toString();
      const url = new URL(InvoiceService.QR_API_URL);
      const result = await new Promise<any>((resolve, reject) => {
        const req = https.request({
          hostname: url.hostname,
          port: 443,
          path: url.pathname,
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Content-Length': Buffer.byteLength(body),
            'X-API-Key': apiKey,
          },
        }, (res) => {
          const chunks: Buffer[] = [];
          res.on('data', (c) => chunks.push(c));
          res.on('end', () => {
            const raw = Buffer.concat(chunks).toString();
            try { resolve(JSON.parse(raw)); }
            catch { reject(new Error(`QR API: invalid JSON (status ${res.statusCode}): ${raw.substring(0, 200)}`)); }
          });
        });
        req.on('error', (e) => reject(new Error(`QR API request error: ${e.message}`)));
        req.write(body);
        req.end();
      });

      if (result.base64Content) {
        this.logger.log(`QR bill generated for ${data.invoiceNumber}`);
        return { base64: result.base64Content };
      }
      const msg = `QR API: ${result.message ?? 'no base64Content in response'}`;
      this.logger.warn(msg);
      return { error: msg };
    } catch (err: any) {
      this.logger.warn(`QR bill generation failed: ${err.message}`);
      return { error: err.message };
    }
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

    // Generate QR bill payment slip (non-blocking — PDF still sent if QR fails)
    const qrResult = await this.generateQrBill({
      amount: data.amount,
      invoiceNumber: data.invoiceNumber,
      debtorName: data.clientName,
    });
    const qrBase64 = 'base64' in qrResult ? qrResult.base64 : null;
    const pdfBuffer = await this.buildInvoicePdf(data, qrBase64);

    try {
      await transporter.sendMail({
        from: `"SIHLHEALTH GmbH" <${fromEmail}>`,
        to: data.clientEmail,
        subject: `Rechnung ${data.invoiceNumber} – ${data.packageName}`,
        html,
        attachments: [
          {
            filename: `Rechnung_${data.invoiceNumber}.pdf`,
            content: pdfBuffer,
            contentType: 'application/pdf',
          },
        ],
      });
      this.logger.log(`Invoice email sent to ${data.clientEmail} with PDF attachment`);
      return true;
    } catch (err: any) {
      this.logger.warn(`Failed to send invoice email: ${err.message}`);
      return false;
    }
  }

  /** Format number Swiss-style: 6'900.00 */
  private formatCHF(n: number): string {
    const [intPart, decPart] = n.toFixed(2).split('.');
    const formatted = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, "'");
    return `${formatted}.${decPart}`;
  }

  /**
   * Generates a professional PDF invoice matching the RTF template.
   * Uses PDFKit with built-in Helvetica fonts (supports WinAnsi/Latin-1 incl. umlauts).
   * All positioned text uses lineBreak:false to prevent cursor-driven page breaks.
   */
  private async buildInvoicePdf(data: {
    invoiceNumber: string;
    clientName: string;
    packageName: string;
    credits: number;
    durationMonths: number;
    amount: number;
  }, qrBase64?: string | null): Promise<Buffer> {
    const today = new Date();
    const dateStr = today.toLocaleDateString('de-CH', { day: '2-digit', month: '2-digit', year: 'numeric' });
    const dueDate = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000);
    const dueDateStr = dueDate.toLocaleDateString('de-CH', { day: '2-digit', month: '2-digit', year: 'numeric' });
    const amountStr = this.formatCHF(data.amount);
    const lektionenLabel = data.credits === 1 ? 'Lektion' : 'Lektionen';
    const monateLabel = data.durationMonths === 1 ? 'Monat' : 'Monate';

    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({
        size: 'A4',
        margins: { top: 50, bottom: 50, left: 50, right: 50 },
        autoFirstPage: true,
        bufferPages: true,
        info: {
          Title: `Rechnung ${data.invoiceNumber}`,
          Author: 'SIHLHEALTH GmbH',
          Creator: 'Sihl Training',
        },
      });

      const chunks: Buffer[] = [];
      doc.on('data', (chunk: Buffer) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const pageWidth = doc.page.width - 100; // 495pt usable
      const leftX = 50;
      const rightEdge = 545;
      // Shorthand: positioned text that must NOT advance the cursor
      const NB = { lineBreak: false } as const;

      // ─── HEADER: SIHLHEALTH GmbH (right-aligned) ───
      doc.fontSize(18).font('Helvetica-Bold')
        .text('SIHLHEALTH GmbH', leftX, 50, { align: 'right', width: pageWidth, lineBreak: false });

      // ─── META SECTION ───
      let y = 110;
      doc.fontSize(16).font('Helvetica-Bold')
        .text('Rechnung', leftX, y, NB);
      y += 24;
      doc.fontSize(10).font('Helvetica')
        .text(`Datum: ${dateStr}`, leftX, y, NB);
      y += 14;
      doc.text(`Rechnungs-Nr.: ${data.invoiceNumber}`, leftX, y, NB);

      // Client name (right side)
      doc.fontSize(10).font('Helvetica')
        .text(data.clientName, 300, 134, { align: 'right', width: rightEdge - 300, lineBreak: false });

      // ─── TABLE ───
      y = 185;
      const colX = { desc: leftX, menge: 310, einheit: 360, preis: 410, betrag: 475 };

      // Top border
      doc.moveTo(leftX, y).lineTo(rightEdge, y).lineWidth(0.5).stroke();
      y += 5;

      // Table header row
      doc.fontSize(9).font('Helvetica-Bold');
      doc.text('Beschreibung', colX.desc, y, NB);
      doc.text('Menge', colX.menge, y, { width: 45, align: 'right', lineBreak: false });
      doc.text('Einheit', colX.einheit, y, { width: 45, align: 'right', lineBreak: false });
      doc.text('Preis CHF', colX.preis, y, { width: 60, align: 'right', lineBreak: false });
      doc.text('Betrag CHF', colX.betrag, y, { width: 70, align: 'right', lineBreak: false });
      y += 14;

      // Bottom border of header
      doc.moveTo(leftX, y).lineTo(rightEdge, y).lineWidth(0.5).stroke();
      y += 8;

      // ─── Line item: description ───
      const itemStartY = y;
      doc.fontSize(9).font('Helvetica-Bold')
        .text(`${data.packageName} Abonnement`, colX.desc, y, { width: 250, lineBreak: false });
      y += 14;

      doc.fontSize(8).font('Helvetica');
      const descLine1 = `${data.credits} Persönliches Fitness- und Gesundheitstraining`;
      const descLine2 = `${lektionenLabel} 50 Minuten pro Lektion`;
      const descLine3 = `${data.durationMonths} ${monateLabel} Laufzeit`;
      doc.text(descLine1, colX.desc, y, { width: 250, lineBreak: false });
      y += 10;
      doc.text(descLine2, colX.desc, y, { width: 250, lineBreak: false });
      y += 10;
      doc.text(descLine3, colX.desc, y, { width: 250, lineBreak: false });

      // Right-side numeric values (vertically centered with item start)
      const valY = itemStartY;
      doc.fontSize(9).font('Helvetica');
      doc.text('1', colX.menge, valY, { width: 45, align: 'right', lineBreak: false });
      doc.text(`${data.credits}`, colX.einheit, valY, { width: 45, align: 'right', lineBreak: false });
      doc.text(amountStr, colX.preis, valY, { width: 60, align: 'right', lineBreak: false });
      doc.text(amountStr, colX.betrag, valY, { width: 70, align: 'right', lineBreak: false });

      y += 18;

      // ─── Inklusive section ───
      doc.fontSize(9).font('Helvetica')
        .text('Inklusive:', colX.desc, y, NB);
      y += 13;
      doc.fontSize(8);
      doc.text('+ Leistungsanalyse', colX.desc, y, NB);
      y += 11;
      doc.text('+ Training Service', colX.desc, y, NB);
      y += 20;

      // ─── Total row ───
      doc.moveTo(leftX, y).lineTo(rightEdge, y).lineWidth(0.5).stroke();
      y += 6;
      doc.fontSize(10).font('Helvetica-Bold');
      doc.text('Rechnungsbetrag CHF', colX.desc, y, NB);
      doc.text(amountStr, colX.betrag, y, { width: 70, align: 'right', lineBreak: false });
      y += 15;
      doc.moveTo(leftX, y).lineTo(rightEdge, y).lineWidth(0.5).stroke();

      // ─── VAT note ───
      y += 6;
      doc.fontSize(7).font('Helvetica')
        .text('SIHLHEALTH GmbH ist nicht MWST-pflichtig.', leftX, y, { align: 'right', width: pageWidth, lineBreak: false });

      // ─── Payment text ───
      y += 28;
      doc.fontSize(10).font('Helvetica')
        .text(`Ich bedanke mich für Ihre Überweisung innerhalb von`, leftX, y, NB);
      y += 14;
      doc.font('Helvetica-Bold').text('7 Tagen ', leftX, y, NB);
      const w7 = doc.widthOfString('7 Tagen ');
      doc.font('Helvetica').text(`bis zum ${dueDateStr}.`, leftX + w7, y, NB);
      y += 18;
      doc.text('Freundliche Grüsse', leftX, y, NB);

      // ─── Signature ───
      y += 24;
      doc.fontSize(10).font('Helvetica')
        .text('Jean-Paul Mvongo', leftX, y, NB);

      // ─── FOOTER (fixed at bottom of page 1) ───
      const footerY = doc.page.height - 75;
      doc.moveTo(leftX, footerY).lineTo(rightEdge, footerY).lineWidth(0.5).stroke();

      const fY = footerY + 8;
      doc.fontSize(8).font('Helvetica');

      // Col 1: Address
      doc.text('Jean-Paul Mvongo', leftX, fY, NB);
      doc.text('Nidelbadstrasse 50', leftX, fY + 11, NB);
      doc.text('8038 Zürich', leftX, fY + 22, NB);

      // Col 2: Contact
      doc.text('Tel.: +41 79 522 30 83', 210, fY, NB);
      doc.text('E-Mail: jean-paul.mvongo@sihltraining.ch', 210, fY + 11, NB);
      doc.text('Web: www.sihltraining.ch', 210, fY + 22, NB);

      // Col 3: Bank
      doc.text('Bank: UBS SWITZERLAND AG', 400, fY, NB);
      doc.text('IBAN: CH26 0020 6206 5500 3901 Z', 400, fY + 11, NB);
      doc.text('BIC: UBSWCHZH80A', 400, fY + 22, NB);

      // ─── PAGE 2: QR Payment Slip (if available) ───
      if (qrBase64) {
        doc.addPage({ size: 'A4', margins: { top: 0, bottom: 0, left: 0, right: 0 } });
        try {
          const qrImageBuffer = Buffer.from(qrBase64, 'base64');
          // Place the QR payment slip at the bottom of the A4 page
          // Standard Swiss QR bill payment part is 105mm high = ~298pt
          const qrHeight = 298;
          const qrY = doc.page.height - qrHeight;
          doc.image(qrImageBuffer, 0, qrY, { width: doc.page.width });
        } catch (imgErr: any) {
          this.logger.warn(`Failed to embed QR image in PDF: ${imgErr.message}`);
        }
      }

      doc.end();
    });
  }

  /** Builds a concise HTML email body — the full invoice is in the PDF attachment. */
  private buildInvoiceHtml(data: {
    invoiceNumber: string;
    clientName: string;
    packageName: string;
    credits: number;
    durationMonths: number;
    amount: number;
  }): string {
    const amountStr = this.formatCHF(data.amount);
    const today = new Date();
    const dueDate = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000);
    const dueDateStr = dueDate.toLocaleDateString('de-CH', { day: '2-digit', month: '2-digit', year: 'numeric' });

    return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><style>
  body { font-family: Arial, Helvetica, sans-serif; color: #1a1a1a; max-width: 580px; margin: 0 auto; padding: 28px 20px; font-size: 14px; line-height: 1.6; }
  .logo { font-size: 18px; font-weight: bold; margin-bottom: 24px; }
  .summary { background: #f7f7f5; padding: 18px 20px; border-radius: 8px; margin: 20px 0; }
  .summary-row { display: flex; justify-content: space-between; margin-bottom: 4px; }
  .summary-label { color: #555; }
  .summary-value { font-weight: bold; }
  .amount { font-size: 18px; font-weight: bold; margin-top: 8px; }
  .note { font-size: 12px; color: #888; margin-top: 20px; }
  .footer { margin-top: 28px; font-size: 12px; color: #888; border-top: 1px solid #ddd; padding-top: 14px; }
</style></head>
<body>
  <div class="logo">SIHLHEALTH GmbH</div>

  <p>Guten Tag ${data.clientName},</p>

  <p>vielen Dank f&uuml;r Ihren Einkauf. Anbei finden Sie Ihre Rechnung als PDF.</p>

  <div class="summary">
    <div class="summary-row"><span class="summary-label">Rechnung:</span> <span class="summary-value">${data.invoiceNumber}</span></div>
    <div class="summary-row"><span class="summary-label">Paket:</span> <span>${data.packageName} Abonnement</span></div>
    <div class="summary-row"><span class="summary-label">Lektionen:</span> <span>${data.credits} &times; 50 Min. Personal Training</span></div>
    <div class="summary-row"><span class="summary-label">Laufzeit:</span> <span>${data.durationMonths} ${data.durationMonths === 1 ? 'Monat' : 'Monate'}</span></div>
    <div class="amount">CHF ${amountStr}</div>
  </div>

  <p>Bitte &uuml;berweisen Sie den Betrag innerhalb von <strong>7 Tagen</strong> (bis ${dueDateStr}).<br>
  Alle Zahlungsdetails finden Sie in der beigef&uuml;gten Rechnung.</p>

  <p>Freundliche Gr&uuml;sse<br>Jean-Paul Mvongo</p>

  <div class="footer">
    SIHLHEALTH GmbH &middot; Nidelbadstrasse 50 &middot; 8038 Z&uuml;rich<br>
    jean-paul.mvongo@sihltraining.ch &middot; www.sihltraining.ch
  </div>
</body>
</html>`;
  }
}
