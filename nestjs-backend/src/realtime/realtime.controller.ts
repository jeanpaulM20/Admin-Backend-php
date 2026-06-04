import { Controller, Sse, Query, Req, MessageEvent } from '@nestjs/common';
import { Request } from 'express';
import { Observable, merge, interval } from 'rxjs';
import { map } from 'rxjs/operators';
import { RealtimeService } from './realtime.service';

/**
 * Server-Sent Events stream. EventSource can't send headers, so auth uses the
 * `?token=` query param (the global AuthGuard already accepts query tokens).
 *
 *   GET /api/events/stream?channel=client_42&token=<token>
 *
 * Authorization: a client may only listen to their OWN channel; a trainer may
 * listen to any client's channel (so the trainer app receives chat pings too).
 */
@Controller('api/events')
export class RealtimeController {
  constructor(private readonly realtime: RealtimeService) {}

  @Sse('stream')
  stream(@Query('channel') channel: string, @Req() req: Request): Observable<MessageEvent> {
    const trainer = (req as any).currentTrainer;
    const client = (req as any).currentClient;

    // Clients are pinned to their own channel; trainers use the requested one.
    const ch = trainer ? (channel || '') : client ? `client_${client.id}` : '';

    // Heartbeat so idle proxies (Railway/Cloudflare) don't drop the stream.
    const heartbeat = interval(25000).pipe(
      map(() => ({ data: { type: 'ping' } }) as MessageEvent),
    );

    return merge(this.realtime.channel(ch) as Observable<MessageEvent>, heartbeat);
  }
}
