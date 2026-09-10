import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, Repository } from 'typeorm';
import { CalendarFeed } from './entities/calendar-feed.entity';
import { ExternalBusy } from './entities/external-busy.entity';
import { CalendarConfig } from './calendar.config';
import { parseIcsBusy, IcsBusy } from './ics-parser';

/**
 * Abonnierte Fremdkalender einlesen (Phase 2).
 *
 * Ein Abo ist eine iCal-Adresse. Der Dienst holt sie regelmässig, löst
 * Serientermine auf und schreibt die belegten Zeiträume nach `external_busy` —
 * ohne Betreff, nur Zeitfenster. Von dort aus bedienen sich die Anzeige im
 * Kalender, die Konfliktprüfung der Buchung und der Google-Abgleich.
 */
@Injectable()
export class CalendarFeedService {
  private readonly log = new Logger('CalendarFeed');

  constructor(
    @InjectRepository(CalendarFeed)
    private readonly feeds: Repository<CalendarFeed>,
    @InjectRepository(ExternalBusy)
    private readonly busy: Repository<ExternalBusy>,
  ) {}

  /** Zeitfenster, das gespiegelt wird: ab jetzt für die konfigurierten Tage. */
  private window(): { from: Date; to: Date } {
    const from = new Date();
    return { from, to: new Date(from.getTime() + CalendarConfig.syncDays * 86_400_000) };
  }

  // ── Verwaltung ─────────────────────────────────────────────────────────────

  /**
   * Nur http(s) und keine internen Adressen: die URL wird serverseitig
   * abgerufen, ein Feed auf 127.0.0.1 oder ein Metadaten-Endpunkt der Cloud
   * wäre sonst ein Weg nach innen (SSRF).
   */
  private assertSafeUrl(raw: string): URL {
    let url: URL;
    try {
      url = new URL(raw.trim().replace(/^webcal:\/\//i, 'https://'));
    } catch {
      throw new BadRequestException('Das ist keine gültige Adresse.');
    }
    if (!['http:', 'https:'].includes(url.protocol)) {
      throw new BadRequestException('Nur http- und https-Adressen sind erlaubt.');
    }
    const host = url.hostname.toLowerCase();
    const blocked =
      host === 'localhost' ||
      host.endsWith('.local') ||
      /^(127|10)\./.test(host) ||
      /^192\.168\./.test(host) ||
      /^172\.(1[6-9]|2\d|3[01])\./.test(host) ||
      host === '169.254.169.254' ||
      host === '[::1]';
    if (blocked) throw new BadRequestException('Diese Adresse ist nicht erlaubt.');
    return url;
  }

  /** Adresse für die Anzeige unkenntlich machen — sie bleibt ein Geheimnis. */
  static mask(raw: string): string {
    try {
      const url = new URL(raw);
      const tail = url.pathname.slice(-6);
      return `${url.hostname}/…${tail}`;
    } catch {
      return '…';
    }
  }

  async list(trainerId: number) {
    const rows = await this.feeds.find({ where: { trainerId }, order: { id: 'ASC' } });
    return rows.map((f) => ({
      id: f.id,
      label: f.label,
      source: CalendarFeedService.mask(f.url),
      active: !!f.active,
      lastFetchAt: f.lastFetchAt,
      lastError: f.lastError,
      eventCount: f.eventCount,
    }));
  }

  /** Anlegen und sofort einmal einlesen, damit ein Tippfehler gleich auffällt. */
  async add(trainerId: number, label: string, url: string) {
    this.assertSafeUrl(url);
    const feed = await this.feeds.save(
      this.feeds.create({
        trainerId,
        label: (label || 'Externer Kalender').slice(0, 120),
        url: url.trim().replace(/^webcal:\/\//i, 'https://'),
        active: true,
        eventCount: 0,
      }),
    );
    await this.refresh(feed);
    const fresh = await this.feeds.findOne({ where: { id: feed.id } });
    return {
      id: feed.id,
      label: feed.label,
      source: CalendarFeedService.mask(feed.url),
      active: true,
      lastError: fresh?.lastError ?? null,
      eventCount: fresh?.eventCount ?? 0,
    };
  }

  async remove(trainerId: number, feedId: number) {
    const feed = await this.feeds.findOne({ where: { id: feedId, trainerId } });
    if (!feed) throw new BadRequestException('Abo nicht gefunden.');
    await this.busy.delete({ feedId });
    await this.feeds.delete({ id: feedId });
  }

  // ── Einlesen ───────────────────────────────────────────────────────────────

  /** Alle Abos eines Trainers neu einlesen. Gibt die Zahl der Zeiträume zurück. */
  async refreshTrainer(trainerId: number): Promise<number> {
    const rows = await this.feeds.find({ where: { trainerId, active: true } });
    let total = 0;
    for (const feed of rows) total += await this.refresh(feed);
    return total;
  }

  /**
   * Einen Feed holen, auflösen und die Zeiträume ersetzen.
   * Fehler landen am Feed statt zu werfen — ein kaputtes Abo darf den
   * Abgleich der anderen nicht anhalten.
   */
  async refresh(feed: CalendarFeed): Promise<number> {
    const { from, to } = this.window();
    try {
      const text = await this.fetchIcs(feed.url);
      const slots = parseIcsBusy(text, from, to);
      await this.replace(feed, slots);
      feed.lastFetchAt = new Date();
      feed.lastError = null;
      feed.eventCount = slots.length;
      await this.feeds.save(feed);
      return slots.length;
    } catch (e: any) {
      // Bewusst ohne URL im Text: sie ist ein Geheimnis und Logs sind es nicht.
      const message = String(e?.message ?? e).slice(0, 250);
      this.log.warn(`Abo ${feed.id} (Trainer ${feed.trainerId}): ${message}`);
      feed.lastError = message;
      feed.lastFetchAt = new Date();
      await this.feeds.save(feed);
      return 0;
    }
  }

  private async fetchIcs(url: string): Promise<string> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 20_000);
    try {
      const response = await fetch(url, {
        redirect: 'follow',
        signal: controller.signal,
        headers: {
          // Ohne User-Agent antworten manche Anbieter gar nicht — dieselbe
          // Lektion wie bei Overpass.
          'User-Agent': 'SihlMove-Kalender/1.0',
          Accept: 'text/calendar, text/plain;q=0.9, */*;q=0.5',
        },
      });
      if (!response.ok) {
        throw new Error(`Der Anbieter antwortet mit ${response.status}.`);
      }
      const text = await response.text();
      if (!text.includes('BEGIN:VCALENDAR')) {
        throw new Error('Die Adresse liefert keinen Kalender im iCal-Format.');
      }
      return text;
    } catch (e: any) {
      if (e?.name === 'AbortError') throw new Error('Zeitüberschreitung beim Abruf.');
      throw e;
    } finally {
      clearTimeout(timer);
    }
  }

  /** Zeiträume eines Feeds im Fenster vollständig ersetzen — idempotent. */
  private async replace(feed: CalendarFeed, slots: IcsBusy[]): Promise<void> {
    const { from, to } = this.window();
    await this.busy.delete({ feedId: feed.id, startsAt: Between(from, to) });
    if (!slots.length) return;
    const rows = slots.map((slot) =>
      this.busy.create({
        trainerId: feed.trainerId,
        feedId: feed.id,
        uid: slot.uid.slice(0, 190),
        startsAt: slot.start,
        endsAt: slot.end,
        allDay: slot.allDay,
      }),
    );
    // In Blöcken speichern: ein Jahresplan kann tausende Zeiträume ergeben.
    for (let i = 0; i < rows.length; i += 200) {
      await this.busy.save(rows.slice(i, i + 200));
    }
  }

  // ── Abfrage ────────────────────────────────────────────────────────────────

  /** Belegte Zeiträume eines Trainers, z.B. für Kalenderanzeige und Buchung. */
  async busyFor(trainerId: number, from: Date, to: Date): Promise<ExternalBusy[]> {
    return this.busy.find({
      where: { trainerId, startsAt: Between(from, to) },
      order: { startsAt: 'ASC' },
    });
  }

  /** Trainer, die überhaupt Abos haben — Grundlage für den Zeitplan. */
  async activeTrainerIds(): Promise<number[]> {
    const rows = await this.feeds.find({ where: { active: true }, select: ['trainerId'] });
    return [...new Set(rows.map((r) => r.trainerId))];
  }

  /** Zuordnung Feed-ID → Bezeichnung, für die Anzeige. */
  async labels(trainerId: number): Promise<Map<number, string>> {
    const rows = await this.feeds.find({ where: { trainerId } });
    return new Map(rows.map((f) => [f.id, f.label]));
  }
}
