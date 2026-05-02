import { Controller, All, Req, Res } from '@nestjs/common';
import { Request, Response } from 'express';
import { Public } from '../auth/decorators/public.decorator';

/**
 * Proxies client-app-specific routes to the PHP backend.
 *
 * These endpoints only exist in PHP (Yii) and haven't been migrated to NestJS yet.
 * The proxy forwards the request (incl. X-Auth-Token) to apps.sihltraining.ch
 * and streams the PHP response back to the client.
 *
 * Routes handled:
 *   /api/client/start/:id
 *   /api/client/calendar/:id
 *   /api/client/profile/:id
 *   /api/client/credits/:id
 *   /api/client/invoices/:id
 *   /api/client/tests/:id
 *   /api/client/appointment/:id (GET, POST, DELETE)
 *   /api/token  (legacy PHP login)
 */
const PHP_BACKEND = process.env.PHP_BACKEND_URL ?? 'https://apps.sihltraining.ch';

@Controller()
export class ClientPhpProxyController {

  @Public()
  @All('api/client/start/*')
  proxyStart(@Req() req: Request, @Res() res: Response) {
    return this.proxy(req, res);
  }

  @Public()
  @All('api/client/calendar/*')
  proxyCalendar(@Req() req: Request, @Res() res: Response) {
    return this.proxy(req, res);
  }

  @Public()
  @All('api/client/profile/*')
  proxyProfile(@Req() req: Request, @Res() res: Response) {
    return this.proxy(req, res);
  }

  @Public()
  @All('api/client/credits/*')
  proxyCredits(@Req() req: Request, @Res() res: Response) {
    return this.proxy(req, res);
  }

  @Public()
  @All('api/client/invoices/*')
  proxyInvoices(@Req() req: Request, @Res() res: Response) {
    return this.proxy(req, res);
  }

  @Public()
  @All('api/client/tests/*')
  proxyTests(@Req() req: Request, @Res() res: Response) {
    return this.proxy(req, res);
  }

  @Public()
  @All('api/client/appointment/*')
  proxyAppointment(@Req() req: Request, @Res() res: Response) {
    return this.proxy(req, res);
  }

  @Public()
  @All('api/client/appointment')
  proxyAppointmentBase(@Req() req: Request, @Res() res: Response) {
    return this.proxy(req, res);
  }

  @Public()
  @All('api/token')
  proxyLegacyToken(@Req() req: Request, @Res() res: Response) {
    return this.proxy(req, res);
  }

  private async proxy(req: Request, res: Response) {
    const url = `${PHP_BACKEND}/${req.originalUrl.replace(/^\//, '')}`;
    const headers: Record<string, string> = {
      'Content-Type': req.headers['content-type'] ?? 'application/json',
      'Accept': 'application/json',
    };
    // Forward auth token
    const authToken = req.headers['x-auth-token'];
    if (authToken) headers['X-Auth-Token'] = String(authToken);

    try {
      const fetchOpts: RequestInit = {
        method: req.method,
        headers,
      };
      if (['POST', 'PUT', 'PATCH'].includes(req.method) && req.body) {
        fetchOpts.body = JSON.stringify(req.body);
      }

      const phpRes = await fetch(url, fetchOpts);
      const body = await phpRes.text();

      // Forward status + content-type
      res.status(phpRes.status);
      const ct = phpRes.headers.get('content-type');
      if (ct) res.setHeader('Content-Type', ct);
      res.send(body);
    } catch (err: any) {
      console.error(`[PHP-PROXY] ${req.method} ${url} →`, err.message);
      res.status(502).json({ error: 'PHP backend unreachable', detail: err.message });
    }
  }
}
