import { Injectable, Logger } from '@nestjs/common';
import * as https from 'https';

/**
 * Saferpay Payment Page API integration.
 *
 * Flow:
 * 1. Initialize — creates a payment page, returns RedirectUrl + Token
 * 2. User pays on Saferpay-hosted page
 * 3. Assert — confirms payment, returns transaction details
 * 4. Capture — settles the payment (for non-auto-capture methods)
 *
 * Docs: https://docs.saferpay.com/home/integration-guide/licences-and-interfaces/payment-page
 */
@Injectable()
export class SaferpayService {
  private readonly logger = new Logger('SaferpayService');

  private get baseUrl(): string {
    return process.env.SAFERPAY_BASE_URL ?? 'https://test.saferpay.com/api';
  }

  private get customerId(): string {
    return process.env.SAFERPAY_CUSTOMER_ID ?? '';
  }

  private get terminalId(): string {
    return process.env.SAFERPAY_TERMINAL_ID ?? '';
  }

  private get authHeader(): string {
    const user = process.env.SAFERPAY_API_USER ?? '';
    const pass = process.env.SAFERPAY_API_PASS ?? '';
    return 'Basic ' + Buffer.from(`${user}:${pass}`).toString('base64');
  }

  private get appUrl(): string {
    return process.env.APP_URL ?? 'https://admin-backend-php-production.up.railway.app';
  }

  /**
   * Check if Saferpay is configured (all required env vars present).
   */
  isConfigured(): boolean {
    return !!(
      process.env.SAFERPAY_CUSTOMER_ID &&
      process.env.SAFERPAY_TERMINAL_ID &&
      process.env.SAFERPAY_API_USER &&
      process.env.SAFERPAY_API_PASS
    );
  }

  /**
   * Initialize a Payment Page session.
   * Returns { token, redirectUrl } on success or { error } on failure.
   */
  async initialize(data: {
    invoiceNumber: string;
    amount: number;
    currency?: string;
    description: string;
    clientId: number;
  }): Promise<{ token: string; redirectUrl: string } | { error: string }> {
    if (!this.isConfigured()) {
      return { error: 'Saferpay not configured' };
    }

    const requestBody = {
      RequestHeader: {
        SpecVersion: '1.33',
        CustomerId: this.customerId,
        RequestId: `${data.invoiceNumber}-${Date.now()}`,
        RetryIndicator: 0,
      },
      TerminalId: this.terminalId,
      Payment: {
        Amount: {
          Value: Math.round(data.amount * 100).toString(), // in cents
          CurrencyCode: data.currency ?? 'CHF',
        },
        OrderId: data.invoiceNumber,
        Description: data.description,
      },
      ReturnUrl: {
        Url: `${this.appUrl}/api/client/payment/return?invoiceNumber=${data.invoiceNumber}&clientId=${data.clientId}`,
      },
      Abort: {
        Url: `${this.appUrl}/api/client/payment/abort?invoiceNumber=${data.invoiceNumber}&clientId=${data.clientId}`,
      },
      Notification: {
        NotifyUrl: `${this.appUrl}/api/client/payment/notify?invoiceNumber=${data.invoiceNumber}`,
      },
    };

    this.logger.log(`Initializing payment for ${data.invoiceNumber}, CHF ${data.amount}`);
    return this.callApi('/Payment/v1/PaymentPage/Initialize', requestBody);
  }

  /**
   * Assert a completed payment — verifies payment status after redirect.
   * Returns transaction details or error.
   */
  async assert(token: string): Promise<{
    transactionId: string;
    status: string;
    brand?: string;
    paymentMethod?: string;
  } | { error: string }> {
    if (!this.isConfigured()) {
      return { error: 'Saferpay not configured' };
    }

    const requestBody = {
      RequestHeader: {
        SpecVersion: '1.33',
        CustomerId: this.customerId,
        RequestId: `assert-${Date.now()}`,
        RetryIndicator: 0,
      },
      Token: token,
    };

    this.logger.log('Asserting payment...');
    const result = await this.callApiRaw('/Payment/v1/PaymentPage/Assert', requestBody);

    if ('error' in result) {
      return result;
    }

    const tx = result.Transaction;
    if (!tx) {
      return { error: 'No transaction in assert response' };
    }

    return {
      transactionId: tx.Id,
      status: tx.Status, // 'AUTHORIZED' or 'CAPTURED'
      brand: tx.Brand?.Name,
      paymentMethod: result.PaymentMeans?.Brand?.Name ?? tx.Type,
    };
  }

  /**
   * Capture an authorized payment (settle it).
   * Only needed if Assert returned Status='AUTHORIZED' (not 'CAPTURED').
   */
  async capture(transactionId: string): Promise<{ success: true } | { error: string }> {
    if (!this.isConfigured()) {
      return { error: 'Saferpay not configured' };
    }

    const requestBody = {
      RequestHeader: {
        SpecVersion: '1.33',
        CustomerId: this.customerId,
        RequestId: `capture-${Date.now()}`,
        RetryIndicator: 0,
      },
      TransactionReference: {
        TransactionId: transactionId,
      },
    };

    this.logger.log(`Capturing transaction ${transactionId}`);
    const result = await this.callApiRaw('/Payment/v1/Transaction/Capture', requestBody);

    if ('error' in result) {
      return result;
    }
    return { success: true };
  }

  // ── Internal HTTP helper ─────────────────────────────────────────────

  private async callApi(
    endpoint: string,
    body: any,
  ): Promise<{ token: string; redirectUrl: string } | { error: string }> {
    const result = await this.callApiRaw(endpoint, body);
    if ('error' in result) return result;

    if (result.Token && result.RedirectUrl) {
      return { token: result.Token, redirectUrl: result.RedirectUrl };
    }
    return { error: 'Unexpected response from Saferpay' };
  }

  private callApiRaw(endpoint: string, body: any): Promise<any> {
    const payload = JSON.stringify(body);
    const url = new URL(this.baseUrl + endpoint);

    return new Promise((resolve) => {
      const req = https.request(
        {
          hostname: url.hostname,
          port: 443,
          path: url.pathname,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload),
            Accept: 'application/json',
            Authorization: this.authHeader,
          },
        },
        (res) => {
          const chunks: Buffer[] = [];
          res.on('data', (c) => chunks.push(c));
          res.on('end', () => {
            const raw = Buffer.concat(chunks).toString();
            try {
              const parsed = JSON.parse(raw);
              if (res.statusCode && res.statusCode >= 400) {
                const errMsg = parsed.ErrorMessage ?? parsed.ErrorName ?? `HTTP ${res.statusCode}`;
                this.logger.warn(`Saferpay ${endpoint} error: ${errMsg}`);
                resolve({ error: errMsg });
              } else {
                resolve(parsed);
              }
            } catch {
              this.logger.warn(`Saferpay ${endpoint}: invalid JSON (${res.statusCode}): ${raw.substring(0, 200)}`);
              resolve({ error: `Invalid response from Saferpay (${res.statusCode})` });
            }
          });
        },
      );

      req.setTimeout(15000, () => {
        req.destroy();
        this.logger.warn(`Saferpay ${endpoint}: timeout`);
        resolve({ error: 'Saferpay request timed out' });
      });

      req.on('error', (e) => {
        this.logger.warn(`Saferpay ${endpoint}: ${e.message}`);
        resolve({ error: `Saferpay request failed: ${e.message}` });
      });

      req.write(payload);
      req.end();
    });
  }
}
