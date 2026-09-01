import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Cron } from '@nestjs/schedule';
import { CalendarConnection } from './entities/calendar-connection.entity';
import { CalendarConfig } from './calendar.config';
import { CalendarOAuthService } from './calendar-oauth.service';

/** Ein Termin, wie er für den Abgleich gebraucht wird — ohne Inhalte. */
interface BusySlot {
  sourceId: string;   // Termin-ID beim Anbieter
  start: string;      // ISO 8601
  end: string;
  allDay: boolean;
}

/**
 * Phase 1: Termine der Klinik aus Outlook als Sperreinträge in den
 * Google-Kalender spiegeln. Dadurch blendet die Google-Terminplanung
 * auf der Website diese Zeiten selbstständig aus.
 *
 * Bewusst nur die ZEIT: Betreff, Teilnehmer und Notizen der Klinik-Termine
 * verlassen Outlook nie.
 */
@Injectable()
export class CalendarSyncService {
  private readonly log = new Logger('CalendarSync');

  constructor(
    @InjectRepository(CalendarConnection)
    private readonly repo: Repository<CalendarConnection>,
    private readonly oauth: CalendarOAuthService,
  ) {}

  /** Alle 15 Minuten — kurzfristige Klinik-Termine sollen zügig greifen. */
  @Cron('*/15 * * * *', { timeZone: 'Europe/Zurich' })
  async syncAll() {
    const outlookConns = await this.repo.find({ where: { provider: 'microsoft' } });
    for (const outlook of outlookConns) {
      const google = await this.repo.findOne({
        where: { trainerId: outlook.trainerId, provider: 'google' },
      });
      if (!google) continue; // ohne Google-Ziel gibt es nichts zu spiegeln
      try {
        const n = await this.syncTrainer(outlook, google);
        this.log.log(`Trainer ${outlook.trainerId}: ${n} Sperrzeiten abgeglichen`);
      } catch (e: any) {
        this.log.error(`Trainer ${outlook.trainerId}: ${e?.message ?? e}`);
        outlook.lastSyncError = String(e?.message ?? e).slice(0, 250);
        await this.repo.save(outlook);
      }
    }
  }

  /**
   * Gleicht einen Trainer ab: Outlook lesen, Google-Sperreinträge anpassen.
   * Idempotent — mehrfaches Ausführen ändert nichts am Ergebnis.
   */
  async syncTrainer(outlook: CalendarConnection, google: CalendarConnection): Promise<number> {
    const from = new Date();
    const to = new Date(Date.now() + CalendarConfig.syncDays * 86_400_000);

    const busy = await this.readOutlookBusy(outlook, from, to);
    const existing = await this.readGoogleBlockers(google, from, to);

    const seen = new Set<string>();
    let touched = 0;

    for (const slot of busy) {
      seen.add(slot.sourceId);
      const current = existing.get(slot.sourceId);
      if (!current) {
        await this.createGoogleBlocker(google, slot);
        touched++;
      } else if (current.start !== slot.start || current.end !== slot.end) {
        await this.updateGoogleBlocker(google, current.googleId, slot);
        touched++;
      }
    }

    // In Outlook gelöschte Termine geben die Zeit wieder frei
    for (const [sourceId, entry] of existing) {
      if (!seen.has(sourceId)) {
        await this.deleteGoogleBlocker(google, entry.googleId);
        touched++;
      }
    }

    outlook.lastSyncAt = new Date();
    outlook.lastSyncError = null;
    await this.repo.save(outlook);
    return touched;
  }

  // ── Outlook (Microsoft Graph) — nur lesen ────────────────────────

  private async readOutlookBusy(conn: CalendarConnection, from: Date, to: Date): Promise<BusySlot[]> {
    const token = await this.oauth.validAccessToken(conn);
    const params = new URLSearchParams({
      startDateTime: from.toISOString(),
      endDateTime: to.toISOString(),
      $select: 'id,start,end,isAllDay,showAs,isCancelled',
      $top: '250',
      $orderby: 'start/dateTime',
    });
    const path = conn.calendarId
      ? `/me/calendars/${encodeURIComponent(conn.calendarId)}/calendarView`
      : '/me/calendarView';

    const res = await fetch(`${CalendarConfig.microsoft.apiBase}${path}?${params}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Prefer: 'outlook.timezone="Europe/Zurich"',
      },
    });
    if (!res.ok) throw new Error(`Outlook antwortet ${res.status}: ${(await res.text()).slice(0, 160)}`);

    const json = (await res.json()) as { value?: any[] };
    return (json.value ?? [])
      // Abgesagtes und als "frei" markiertes belegt keine Zeit
      .filter((e) => !e.isCancelled && e.showAs !== 'free')
      .map((e) => ({
        sourceId: String(e.id),
        start: this.graphTimeToIso(e.start),
        end: this.graphTimeToIso(e.end),
        allDay: !!e.isAllDay,
      }))
      .filter((s) => s.start && s.end);
  }

  /** Graph liefert Zeit ohne Zonen-Suffix; die Zone steht daneben. */
  private graphTimeToIso(t: { dateTime?: string; timeZone?: string } | undefined): string {
    if (!t?.dateTime) return '';
    const raw = t.dateTime.replace(/\.\d+$/, '');
    return raw.endsWith('Z') || /[+-]\d{2}:\d{2}$/.test(raw) ? raw : `${raw}Z`;
  }

  // ── Google Kalender — Sperreinträge verwalten ────────────────────

  private googleUrl(conn: CalendarConnection, suffix = ''): string {
    const cal = encodeURIComponent(conn.calendarId || 'primary');
    return `${CalendarConfig.google.apiBase}/calendars/${cal}/events${suffix}`;
  }

  /** Liest die von uns angelegten Einträge, erkennbar am eigenen Kennzeichen. */
  private async readGoogleBlockers(
    conn: CalendarConnection, from: Date, to: Date,
  ): Promise<Map<string, { googleId: string; start: string; end: string }>> {
    const token = await this.oauth.validAccessToken(conn);
    const params = new URLSearchParams({
      timeMin: from.toISOString(),
      timeMax: to.toISOString(),
      singleEvents: 'true',
      maxResults: '2500',
      privateExtendedProperty: `${CalendarConfig.markerKey}=1`,
    });

    const res = await fetch(`${this.googleUrl(conn)}?${params}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw new Error(`Google antwortet ${res.status}: ${(await res.text()).slice(0, 160)}`);

    const json = (await res.json()) as { items?: any[] };
    const map = new Map<string, { googleId: string; start: string; end: string }>();
    for (const item of json.items ?? []) {
      const sourceId = item.extendedProperties?.private?.sihlmoveSource;
      if (!sourceId) continue;
      map.set(sourceId, {
        googleId: item.id,
        start: item.start?.dateTime ?? item.start?.date ?? '',
        end: item.end?.dateTime ?? item.end?.date ?? '',
      });
    }
    return map;
  }

  private blockerBody(slot: BusySlot) {
    return {
      summary: 'Belegt (Klinik)',
      description: 'Automatisch aus dem Outlook-Kalender übernommen. Nicht bearbeiten — Änderungen werden überschrieben.',
      transparency: 'opaque',   // zählt als belegt
      visibility: 'private',
      reminders: { useDefault: false },
      start: slot.allDay ? { date: slot.start.slice(0, 10) } : { dateTime: slot.start, timeZone: 'Europe/Zurich' },
      end:   slot.allDay ? { date: slot.end.slice(0, 10) }   : { dateTime: slot.end,   timeZone: 'Europe/Zurich' },
      extendedProperties: {
        private: { [CalendarConfig.markerKey]: '1', sihlmoveSource: slot.sourceId },
      },
    };
  }

  private async createGoogleBlocker(conn: CalendarConnection, slot: BusySlot) {
    const token = await this.oauth.validAccessToken(conn);
    const res = await fetch(this.googleUrl(conn), {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(this.blockerBody(slot)),
    });
    if (!res.ok) throw new Error(`Sperreintrag anlegen: ${res.status} ${(await res.text()).slice(0, 160)}`);
  }

  private async updateGoogleBlocker(conn: CalendarConnection, googleId: string, slot: BusySlot) {
    const token = await this.oauth.validAccessToken(conn);
    const res = await fetch(this.googleUrl(conn, `/${encodeURIComponent(googleId)}`), {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(this.blockerBody(slot)),
    });
    if (!res.ok) throw new Error(`Sperreintrag ändern: ${res.status} ${(await res.text()).slice(0, 160)}`);
  }

  private async deleteGoogleBlocker(conn: CalendarConnection, googleId: string) {
    const token = await this.oauth.validAccessToken(conn);
    const res = await fetch(this.googleUrl(conn, `/${encodeURIComponent(googleId)}`), {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    // 410 = bereits gelöscht, für uns das gewünschte Ergebnis
    if (!res.ok && res.status !== 404 && res.status !== 410) {
      throw new Error(`Sperreintrag löschen: ${res.status}`);
    }
  }
}
