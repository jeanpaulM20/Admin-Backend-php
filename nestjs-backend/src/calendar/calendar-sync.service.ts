import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Cron } from '@nestjs/schedule';
import { CalendarConnection } from './entities/calendar-connection.entity';
import { CalendarConfig } from './calendar.config';
import { CalendarOAuthService } from './calendar-oauth.service';
import { CalendarFeedService } from './calendar-feed.service';

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

  /** Trainer, deren Abgleich gerade läuft — verhindert überlappende Läufe
   *  (Cron alle 15 Min UND manueller syncNow) und damit Doppel-Sperren. */
  private readonly running = new Set<number>();

  constructor(
    @InjectRepository(CalendarConnection)
    private readonly repo: Repository<CalendarConnection>,
    private readonly oauth: CalendarOAuthService,
    private readonly feeds: CalendarFeedService,
  ) {}

  /** Alle 15 Minuten — kurzfristige Fremdtermine sollen zügig greifen. */
  @Cron('*/15 * * * *', { timeZone: 'Europe/Zurich' })
  async syncAll() {
    // Quellen sind Outlook UND abonnierte Fremdkalender; ein Trainer kann
    // nur das eine, nur das andere oder beides haben.
    const trainerIds = new Set<number>();
    for (const c of await this.repo.find({ where: { provider: 'microsoft' } })) {
      trainerIds.add(c.trainerId);
    }
    for (const id of await this.feeds.activeTrainerIds()) trainerIds.add(id);

    for (const trainerId of trainerIds) {
      try {
        const n = await this.syncTrainerId(trainerId);
        this.log.log(`Trainer ${trainerId}: ${n} Sperrzeiten abgeglichen`);
      } catch (e: any) {
        this.log.error(`Trainer ${trainerId}: ${e?.message ?? e}`);
      }
    }
  }

  /**
   * Vollständiger Abgleich eines Trainers: Abos einlesen, danach Outlook und
   * Abos gemeinsam als Sperreinträge nach Google spiegeln.
   *
   * Ohne Google-Verbindung endet es nach dem Einlesen — die Zeiten stehen dann
   * trotzdem in `external_busy` und wirken in App und Konfliktprüfung.
   */
  async syncTrainerId(trainerId: number): Promise<number> {
    if (this.running.has(trainerId)) {
      this.log.log(`Trainer ${trainerId}: Abgleich läuft bereits, übersprungen`);
      return 0;
    }
    this.running.add(trainerId);
    try {
      await this.feeds.refreshTrainer(trainerId);

      const google = await this.repo.findOne({ where: { trainerId, provider: 'google' } });
      if (!google) return 0;

      const outlook = await this.repo.findOne({ where: { trainerId, provider: 'microsoft' } });
      return await this.runSync(outlook, google, trainerId);
    } finally {
      this.running.delete(trainerId);
    }
  }

  /**
   * Gleicht einen Trainer ab: Outlook lesen, Google-Sperreinträge anpassen.
   * Idempotent — mehrfaches Ausführen ändert nichts am Ergebnis.
   */
  /** Gleicher Zeitpunkt trotz unterschiedlicher Schreibweise
   *  („…Z" vs. „…+02:00", bzw. Datum bei Ganztag). */
  private sameInstant(a: string, b: string): boolean {
    const ta = Date.parse(a), tb = Date.parse(b);
    if (Number.isNaN(ta) || Number.isNaN(tb)) return a === b;
    return ta === tb;
  }

  private async runSync(
    outlook: CalendarConnection | null,
    google: CalendarConnection,
    trainerId: number,
  ): Promise<number> {
    const from = new Date();
    const to = new Date(Date.now() + CalendarConfig.syncDays * 86_400_000);

    // Beide Quellen zusammenführen. Outlook-Kennungen bleiben unverändert,
    // damit bereits angelegte Sperreinträge weiter wiedererkannt werden;
    // Abo-Zeiten bekommen ein eigenes Präfix.
    const busy: BusySlot[] = [];
    if (outlook) busy.push(...(await this.readOutlookBusy(outlook, from, to)));
    for (const slot of await this.feeds.busyFor(trainerId, from, to)) {
      busy.push({
        sourceId: `ics:${slot.feedId}:${slot.uid}@${slot.startsAt.getTime()}`,
        start: slot.startsAt.toISOString(),
        end: slot.endsAt.toISOString(),
        allDay: !!slot.allDay,
      });
    }

    const existing = await this.readGoogleBlockers(google, from, to);

    const seen = new Set<string>();
    let touched = 0;

    for (const slot of busy) {
      seen.add(slot.sourceId);
      const current = existing.get(slot.sourceId);
      if (!current) {
        await this.createGoogleBlocker(google, slot);
        touched++;
      } else if (!this.sameInstant(current.start, slot.start) || !this.sameInstant(current.end, slot.end)) {
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

    if (outlook) {
      outlook.lastSyncAt = new Date();
      outlook.lastSyncError = null;
      await this.repo.save(outlook);
    }
    google.lastSyncAt = new Date();
    google.lastSyncError = null;
    await this.repo.save(google);
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
        // UTC anfordern: Graph liefert die Zeit dann als echte UTC-Wanduhr,
        // die graphTimeToIso mit "Z" korrekt zum Instant macht. Mit einer
        // benannten Zone käme die Lokalzeit OHNE Offset zurück und würde
        // fälschlich als UTC gelesen (Sperren 1–2 h verschoben).
        Prefer: 'outlook.timezone="UTC"',
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
      // Zeit-Termine als UTC-Instant (Z); die Zone steckt bereits im Offset,
      // eine zusätzliche timeZone würde nur zu Widersprüchen führen
      start: slot.allDay ? { date: slot.start.slice(0, 10) } : { dateTime: slot.start },
      end:   slot.allDay ? { date: slot.end.slice(0, 10) }   : { dateTime: slot.end },
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
