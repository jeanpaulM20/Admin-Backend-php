import { Injectable } from '@nestjs/common';
import { Subject, Observable } from 'rxjs';
import { filter, map } from 'rxjs/operators';

export interface RealtimeEvent {
  /** Channel name, e.g. 'client_42'. */
  channel: string;
  /** Event type, e.g. 'plan_updated' | 'chat'. */
  type: string;
  data?: any;
}

/**
 * In-memory pub/sub hub backing the SSE endpoint. Single-instance only —
 * if the backend is ever scaled horizontally this needs a shared bus
 * (e.g. Redis pub/sub) so events reach clients connected to other instances.
 */
@Injectable()
export class RealtimeService {
  private readonly stream$ = new Subject<RealtimeEvent>();

  emit(channel: string, type: string, data?: any): void {
    this.stream$.next({ channel, type, data });
  }

  /** Convenience: emit to a specific client's channel. */
  emitToClient(clientId: number, type: string, data?: any): void {
    this.emit(`client_${clientId}`, type, data);
  }

  /** SSE-shaped stream for one channel. */
  channel(channel: string): Observable<{ data: any }> {
    return this.stream$.pipe(
      filter((e) => e.channel === channel),
      map((e) => ({ data: { type: e.type, ...(e.data !== undefined ? { data: e.data } : {}) } })),
    );
  }
}
