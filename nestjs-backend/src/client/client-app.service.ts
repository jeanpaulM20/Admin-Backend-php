import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, MoreThanOrEqual, In, LessThan, MoreThan } from 'typeorm';
import { Client } from '../entities/client.entity';
import { Training, TrainingStatus } from '../entities/training.entity';
import { TrainerAvailability } from '../entities/trainer-availability.entity';
import { Trainer } from '../entities/trainer.entity';
import { ClientCredits, TrainingType, PerformanceTest, File as ClientFile } from '../entities/remaining.entities';
import { Metric } from '../entities/metric.entity';
import { ReviewPhoto } from '../entities/review-photo.entity';
import { Location } from '../entities/location.entity';
import { ReviewService } from '../review/review.service';
import { InvoiceService } from '../invoice/invoice.service';
import { EntitlementService } from '../entitlement/entitlement.service';
import { ExternalBusy } from '../calendar/entities/external-busy.entity';
import { wallClockToInstant } from '../calendar/ics-parser';
import {
  SLOT_MINUTES, MIN_ADVANCE_HOURS, DEFAULT_BUFFER_MINUTES, isIsoDay, parseClock, formatClock,
  matchingWindow, trainerConflict, overlaps, toLocalSegments,
} from './booking/domain/booking-rules';

@Injectable()
export class ClientAppService {
  constructor(
    @InjectRepository(Client) private readonly clientRepo: Repository<Client>,
    @InjectRepository(Training) private readonly trainingRepo: Repository<Training>,
    @InjectRepository(Trainer) private readonly trainerRepo: Repository<Trainer>,
    @InjectRepository(TrainerAvailability) private readonly availRepo: Repository<TrainerAvailability>,
    @InjectRepository(ClientCredits) private readonly creditsRepo: Repository<ClientCredits>,
    @InjectRepository(TrainingType) private readonly typeRepo: Repository<TrainingType>,
    @InjectRepository(Location) private readonly locationRepo: Repository<Location>,
    @InjectRepository(PerformanceTest) private readonly perfTestRepo: Repository<PerformanceTest>,
    @InjectRepository(ClientFile) private readonly fileRepo: Repository<ClientFile>,
    @InjectRepository(Metric) private readonly metricRepo: Repository<Metric>,
    @InjectRepository(ReviewPhoto) private readonly photoRepo: Repository<ReviewPhoto>,
    @InjectRepository(ExternalBusy) private readonly externalBusyRepo: Repository<ExternalBusy>,
    private readonly dataSource: DataSource,
    private readonly reviewService: ReviewService,
    private readonly invoiceService: InvoiceService,
    private readonly entitlementService: EntitlementService,
  ) {}

  private static readonly TZ = 'Europe/Zurich';

  /** Today's date (YYYY-MM-DD) in Swiss timezone */
  private swissToday(): string {
    return new Date().toLocaleDateString('en-CA', { timeZone: ClientAppService.TZ });
  }

  /** Parse a date + time that is stored in Swiss local time into a UTC Date */
  private swissDateTime(dateStr: string, timeStr: string): Date {
    const [y, mo, d] = dateStr.split('-').map(Number);
    const [h, mi] = timeStr.split(':').map(Number);
    const asUtcMs = Date.UTC(y, mo - 1, d, h, mi, 0);
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: ClientAppService.TZ,
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit',
      hour12: false,
    }).formatToParts(new Date(asUtcMs));
    const p = (type: string) =>
      parseInt(parts.find((pt) => pt.type === type)!.value, 10);
    const offsetMs =
      Date.UTC(p('year'), p('month') - 1, p('day'), p('hour'), p('minute'), p('second')) - asUtcMs;
    return new Date(asUtcMs - offsetMs);
  }

  /** Dashboard: credits + upcoming appointments */
  async getStartData(clientId: number) {
    const today = this.swissToday();

    const [client, credits, trainings] = await Promise.all([
      this.clientRepo.findOne({ where: { id: clientId } }),
      this.getTotalCredits(clientId),
      this.trainingRepo.find({
        where: {
          clientId,
          date: MoreThanOrEqual(today),
          status: In([TrainingStatus.BOOKED, TrainingStatus.ATTENDED]),
        },
        relations: ['trainer', 'trainingType', 'location'],
        order: { date: 'ASC', starttime: 'ASC' },
        take: 10,
      }),
    ]);

    return {
      firstname: (client?.firstname ?? '').trim(),
      lastname: (client?.lastname ?? '').trim(),
      credits,
      appointments: trainings.map((t) => this.mapTraining(t)),
    };
  }

  /** Calendar: trainers, types, availability, appointments */
  async getCalendarData(clientId: number) {
    const today = this.swissToday();

    // Get client's assigned trainers
    const client = await this.clientRepo.findOne({
      where: { id: clientId },
      relations: ['trainers'],
    });
    if (!client) throw new NotFoundException(`Client ${clientId} not found`);

    const trainerIds = client.trainers?.map((t) => t.id) ?? [];

    const [trainingTypes, availability, trainings, locations, credits, trainerTrainings, externalBusy] =
      await Promise.all([
        this.typeRepo.find(),
        trainerIds.length
          ? this.availRepo.find({
              where: {
                trainerId: In(trainerIds),
                date: MoreThanOrEqual(today),
              },
              order: { date: 'ASC', from: 'ASC' },
            })
          : Promise.resolve([]),
        this.trainingRepo.find({
          where: { clientId },
          relations: ['trainer', 'trainingType', 'location'],
          order: { date: 'ASC', starttime: 'ASC' },
        }),
        this.locationRepo.find({ where: { active: 1 } }),
        this.getTotalCredits(clientId),
        // Fetch all trainer bookings (for buffer-time / slot calculation)
        trainerIds.length
          ? this.trainingRepo.find({
              where: {
                trainerId: In(trainerIds),
                date: MoreThanOrEqual(today),
                status: In([TrainingStatus.BOOKED, TrainingStatus.ATTENDED]),
              },
              order: { date: 'ASC', starttime: 'ASC' },
            })
          : Promise.resolve([]),
        // Termine aus verbundenen Fremdkalendern belegen den Trainer ebenfalls
        trainerIds.length
          ? this.externalBusyRepo.find({
              where: { trainerId: In(trainerIds), endsAt: MoreThan(new Date()) },
            })
          : Promise.resolve([]),
      ]);

    // Fremdtermine als Tagesstücke in Zürcher Zeit, wie eine Buchung ohne Standort
    const externalBookings = externalBusy.flatMap((e) =>
      toLocalSegments(e.startsAt, e.endsAt, ClientAppService.TZ)
        .filter((seg) => seg.date >= today)
        .map((seg, i) => ({
          id: `ext-${e.id}-${i}`,
          trainer_id: e.trainerId,
          date: seg.date,
          starttime: formatClock(seg.startMin),
          duration: seg.endMin - seg.startMin,
          location_id: null,
          status: 'external',
        })),
    );

    return {
      credits,
      trainers: (client.trainers ?? []).map((t) => ({
        id: t.id,
        firstname: (t.firstname ?? '').trim(),
        lastname: (t.lastname ?? '').trim(),
        picture: t.picture,
        color: t.color,
      })),
      training_types: trainingTypes.map((tt) => ({
        id: tt.id,
        name: tt.nameDe ?? tt.nameEn ?? '',
        duration: tt.duration,
      })),
      availability: availability.map((a) => ({
        id: a.id,
        trainer_id: a.trainerId,
        date: a.date,
        from: a.from,
        to: a.to,
        training_type_id: a.trainingTypeId,
        location_id: a.locationId,
      })),
      appointments: trainings.map((t) => this.mapTraining(t)),
      // All trainer bookings for buffer/conflict display in client
      // status 'external' = Fremdkalender: blockiert ohne Puffer
      trainer_bookings: [
        ...trainerTrainings.map((t) => ({
          id: t.id,
          trainer_id: t.trainerId,
          date: t.date,
          starttime: t.starttime,
          duration: t.duration || 60,
          location_id: t.locationId,
          status: t.status,
        })),
        ...externalBookings,
      ],
      locations: locations.map((l) => ({
        id: l.id,
        name: l.name,
        address: l.address,
        buffer_minutes: l.bufferMinutes ?? 30,
      })),
    };
  }

  /** Profile */
  async getProfile(clientId: number) {
    const client = await this.clientRepo.findOne({
      where: { id: clientId },
      relations: ['account'],
    });
    if (!client) throw new NotFoundException(`Client ${clientId} not found`);

    const creditRows = await this.creditsRepo.find({ where: { clientId } });
    const totalCredits = await this.getTotalCredits(clientId);

    return {
      id: client.id,
      firstname: (client.firstname ?? '').trim(),
      lastname: (client.lastname ?? '').trim(),
      email: client.email,
      phone: client.phone,
      photo: client.picture,
      birthday: client.birthday,
      gender: client.gender,
      credits: totalCredits,
      creditPacks: creditRows.map((c) => ({
        title: `Credit-Paket #${c.id}`,
        prepaidCredits: c.paid ?? 0,
        spentCredits: c.attended ?? 0,
        startdate: c.startdate,
        expiryDate: c.expires,
      })),
    };
  }

  /** Credits list – returns client's credit packs with remaining balances */
  async getCredits(clientId: number) {
    const credits = await this.creditsRepo.find({ where: { clientId } });
    // Guthaben aus einem Online-Coaching-Kauf ist über coaching_invoice_number
    // verknüpft (Spalte per Startmigration; roh gelesen, damit ein Fehlen der
    // Spalte die Guthaben-Liste nicht bricht)
    let coachingIds = new Set<number>();
    try {
      const rows: { id: number }[] = await this.dataSource.query(
        'SELECT id FROM client_credits WHERE client_id = ? AND coaching_invoice_number IS NOT NULL',
        [clientId],
      );
      coachingIds = new Set(rows.map((r) => Number(r.id)));
    } catch {
      // Spalte (noch) nicht vorhanden → alles gilt als Lektionen-Guthaben
    }
    return credits.map((c) => ({
      id: c.id,
      kind: coachingIds.has(c.id) ? 'coaching' : 'credits',
      title: `Credit-Paket #${c.id}`,
      paid: c.paid ?? 0,
      attended: c.attended ?? 0,
      remaining: (c.paid ?? 0) - (c.attended ?? 0),
      startdate: c.startdate,
      expires: c.expires,
    }));
  }

  /**
   * Available packages. Without `kind` returns credit packs (preserves the
   * existing credits screen); pass kind='coaching' for online-coaching tiers.
   */
  async getPackages(kind?: string) {
    try {
      const wantKind = kind ?? 'credits';
      const rows: any[] = await this.dataSource.query(
        "SELECT * FROM credit_package WHERE active = 1 AND COALESCE(kind, 'credits') = ? ORDER BY sort_order",
        [wantKind],
      );
      return rows.map((r) => ({
        id: r.id,
        name: r.name,
        credits: r.credits,
        price: parseFloat(r.price),
        pricePerSession: r.price_per_session ? parseFloat(r.price_per_session) : null,
        durationMonths: r.duration_months,
        description: r.description,
        includes: r.includes,
        kind: r.kind ?? 'credits',
      }));
    } catch {
      return [];
    }
  }

  /** Online-coaching subscription status — single source for the client state machine. */
  async getSubscriptionStatus(clientId: number) {
    return this.entitlementService.getStatus(clientId);
  }

  /**
   * Activate the one-time free 1-month trial (self-service, no payment).
   * Returns the fresh status so the client app can update immediately.
   */
  async activateTrial(clientId: number) {
    await this.entitlementService.activateTrial(clientId);
    return this.entitlementService.getStatus(clientId);
  }

  /**
   * Purchase a credit package — creates credits + invoice inside a
   * single DB transaction (atomic: both succeed or both roll back).
   * Email is sent AFTER commit so a mail failure can't undo the purchase.
   */
  async purchasePackage(clientId: number, packageId: number) {
    const logger = new (require('@nestjs/common').Logger)('PurchasePackage');
    try {
      // 1. Load client (read-only, outside transaction)
      logger.log(`Loading client ${clientId}`);
      const client = await this.clientRepo.findOne({ where: { id: clientId } });
      if (!client) throw new NotFoundException('Client not found');

      // 2. Load package (read-only, outside transaction)
      logger.log(`Loading package ${packageId}`);
      const [pkg]: any = await this.dataSource.query(
        'SELECT * FROM credit_package WHERE id = ? AND active = 1',
        [packageId],
      );
      if (!pkg) throw new NotFoundException('Package not found');

      const credits = pkg.credits;
      const price = parseFloat(pkg.price);
      const durationMonths = pkg.duration_months;
      const packageName = pkg.name;

      // 3. Calculate dates — Swiss-time, month-end safe (shared with the manual
      //    activation path so both produce identical, correct validTo dates).
      const { validFrom: startDate, validTo: expiresStr } =
        this.entitlementService.computePeriod(durationMonths ?? 1);

      // 4. Transaction: create credits + invoice atomically
      const queryRunner = this.dataSource.createQueryRunner();
      await queryRunner.connect();
      await queryRunner.startTransaction();

      let invoiceNumber: string;
      try {
        // 4a. Create client_credits entry
        logger.log(`Creating credits: paid=${credits}, start=${startDate}, expires=${expiresStr}`);
        const creditsInsert: any = await queryRunner.query(
          `INSERT INTO client_credits (client_id, training_type_id, paid, attended, abbonement_id, sold_by_id, startdate, expires, sell_date)
           VALUES (?, NULL, ?, 0, NULL, NULL, ?, ?, ?)`,
          [clientId, credits, startDate, expiresStr, startDate],
        );
        const creditsId: number | undefined = creditsInsert?.insertId;

        // 4b. Create invoice (uses same queryRunner → same transaction)
        logger.log('Creating invoice');
        invoiceNumber = await this.invoiceService.createInvoice(
          { clientId, packageName, amount: price, credits, durationMonths: durationMonths ?? 1 },
          queryRunner,
        );

        // 4c. Coaching package → also create the subscription entitlement period
        if (pkg.kind === 'coaching') {
          // Guthaben-Eintrag mit dem Abo verknüpfen (App trennt Coaching von Lektionen)
          if (creditsId) {
            await queryRunner.query(
              'UPDATE client_credits SET coaching_invoice_number = ? WHERE id = ?',
              [invoiceNumber, creditsId],
            );
          }
          const tier = (durationMonths ?? 1) >= 12 ? 'yearly' : 'monthly';
          // Cancel any existing active subscription first (trial or paid) so a
          // purchase/renewal never leaves two overlapping active rows.
          await queryRunner.query(
            `UPDATE coaching_subscription SET status = 'cancelled'
             WHERE client_id = ? AND status = 'active'`,
            [clientId],
          );
          logger.log(`Creating coaching subscription: tier=${tier}, valid ${startDate}..${expiresStr}`);
          await queryRunner.query(
            `INSERT INTO coaching_subscription
               (client_id, package_id, tier, status, valid_from, valid_to, invoice_number)
             VALUES (?, ?, ?, 'active', ?, ?, ?)`,
            [clientId, packageId, tier, startDate, expiresStr, invoiceNumber],
          );
        } else if (Number(pkg.includes_coaching) === 1) {
          // 4d. Lektionen-Paket mit inklusivem Online-Coaching (Advanced):
          //     Coaching für dieselbe Laufzeit freischalten. Bewusst OHNE
          //     invoice_number — sonst gälte die Rechnung als Coaching-Beleg
          //     (ohne Einzahlungsschein) und die Startmigration würde die
          //     Lektionen als Coaching-Guthaben markieren.
          const [covering]: any = await queryRunner.query(
            `SELECT id FROM coaching_subscription
             WHERE client_id = ? AND status = 'active' AND valid_to >= ?
             LIMIT 1`,
            [clientId, expiresStr],
          );
          if (!covering) {
            // Kürzer laufende aktive Abos ablösen — nie zwei aktive Zeilen
            await queryRunner.query(
              `UPDATE coaching_subscription SET status = 'cancelled'
               WHERE client_id = ? AND status = 'active'`,
              [clientId],
            );
            logger.log(`Including coaching: valid ${startDate}..${expiresStr}`);
            await queryRunner.query(
              `INSERT INTO coaching_subscription
                 (client_id, package_id, tier, status, valid_from, valid_to, invoice_number)
               VALUES (?, ?, 'included', 'active', ?, ?, NULL)`,
              [clientId, packageId, startDate, expiresStr],
            );
          }
        }

        await queryRunner.commitTransaction();
        logger.log(`Transaction committed: credits + invoice ${invoiceNumber}`);
      } catch (txErr) {
        await queryRunner.rollbackTransaction();
        logger.error(`Transaction rolled back: ${(txErr as any).message}`);
        throw txErr;
      } finally {
        await queryRunner.release();
      }

      // 5. Send invoice email (AFTER commit — mail failure won't undo purchase)
      const clientName = `${client.firstname} ${client.lastname}`.trim();
      logger.log(`Sending email to ${client.email}`);
      const emailSent = await this.invoiceService.sendInvoiceEmail({
        invoiceNumber,
        clientName,
        clientEmail: client.email,
        packageName,
        credits,
        durationMonths: durationMonths ?? 1,
        amount: price,
      });

      return {
        success: true,
        invoiceNumber,
        emailSent,
        message: emailSent
          ? `Rechnung ${invoiceNumber} wurde an ${client.email} gesendet.`
          : `Paket gebucht. Rechnung ${invoiceNumber} erstellt (E-Mail-Versand nicht konfiguriert).`,
      };
    } catch (err: any) {
      logger.error(`Purchase failed: ${err.message}`, err.stack);
      throw err;
    }
  }

  /** Performance tests – transformed into sectioned format for Flutter */
  async getTests(clientId: number) {
    const rows = await this.perfTestRepo.find({
      where: { client_id: clientId },
      order: { date: 'DESC' },
    });

    if (!rows.length) return [];

    // Metric definitions: column → { label, unit, section }
    const metricDefs: Record<
      string,
      { label: string; unit: string; section: string }
    > = {
      pushups: { label: 'Liegestütze', unit: 'Wdh.', section: 'Kraft' },
      pullups: { label: 'Klimmzüge', unit: 'Wdh.', section: 'Kraft' },
      trunk_bending: { label: 'Rumpfbeuge', unit: 'cm', section: 'Kraft' },
      forearm_support: {
        label: 'Unterarmstütz',
        unit: 'Sek.',
        section: 'Kraft',
      },
      squat_on_wall: { label: 'Wandhocke', unit: 'Sek.', section: 'Kraft' },
      sprint_10: { label: 'Sprint 10m', unit: 'Sek.', section: 'Ausdauer' },
      sprint_20: { label: 'Sprint 20m', unit: 'Sek.', section: 'Ausdauer' },
      sprint_30: { label: 'Sprint 30m', unit: 'Sek.', section: 'Ausdauer' },
      tapping: { label: 'Tapping', unit: 'Wdh.', section: 'Ausdauer' },
      hamstrings: {
        label: 'Oberschenkelrückseite',
        unit: '°',
        section: 'Beweglichkeit',
      },
      calfs: { label: 'Waden', unit: '°', section: 'Beweglichkeit' },
      adductors: {
        label: 'Adduktoren',
        unit: '°',
        section: 'Beweglichkeit',
      },
      straight_thigh_extensors: {
        label: 'Oberschenkelstrecker',
        unit: '°',
        section: 'Beweglichkeit',
      },
      sensomotoric: {
        label: 'Sensomotorik',
        unit: 'Pkt.',
        section: 'Koordination',
      },
      symmetry: { label: 'Symmetrie', unit: 'Pkt.', section: 'Koordination' },
      reaction: { label: 'Reaktion', unit: 'ms', section: 'Koordination' },
      counter_movement_jump: {
        label: 'CMJ',
        unit: 'cm',
        section: 'Koordination',
      },
      side_support: {
        label: 'Seitstütz',
        unit: 'Sek.',
        section: 'Koordination',
      },
      points: {
        label: 'Gesamtpunkte',
        unit: 'Pkt.',
        section: 'Gesamtbewertung',
      },
    };

    // Ordered section names
    const sectionOrder = [
      'Kraft',
      'Ausdauer',
      'Beweglichkeit',
      'Koordination',
      'Gesamtbewertung',
    ];

    // Build per-metric data (latest, previous, history)
    const sectionMap = new Map<
      string,
      {
        key: string;
        value: string | null;
        previousValue: string | null;
        change: string;
        unit: string;
        history: { date: string; value: string }[];
        hasAnyValue: boolean;
      }[]
    >();

    for (const section of sectionOrder) {
      sectionMap.set(section, []);
    }

    for (const [column, def] of Object.entries(metricDefs)) {
      // Collect all non-null values (rows are sorted DESC by date)
      const history: { date: string; value: string }[] = [];
      for (const row of rows) {
        const raw = row[column];
        if (raw != null) {
          const formatted = this.formatMetricValue(Number(raw));
          history.push({ date: row.date, value: formatted });
        }
      }

      const latest = history.length > 0 ? history[0].value : null;
      const previous = history.length > 1 ? history[1].value : null;

      let change = '';
      if (latest != null && previous != null) {
        const diff = Number(latest) - Number(previous);
        change = diff > 0 ? `+${this.formatMetricValue(diff)}` : this.formatMetricValue(diff);
      } else if (latest != null) {
        change = 'neu';
      }

      // History for charts should be chronological (oldest first)
      const chronological = [...history].reverse();

      sectionMap.get(def.section)!.push({
        key: def.label,
        value: latest,
        previousValue: previous,
        change,
        unit: def.unit,
        history: chronological,
        hasAnyValue: history.length > 0,
      });
    }

    // Build result, skipping sections where ALL metrics have no data
    const result: {
      section: string;
      data: {
        key: string;
        value: string | null;
        previousValue: string | null;
        change: string;
        unit: string;
        history: { date: string; value: string }[];
      }[];
    }[] = [];

    for (const section of sectionOrder) {
      const metrics = sectionMap.get(section)!;
      // Only include metrics that have at least one value
      const withData = metrics.filter((m) => m.hasAnyValue);
      if (!withData.length) continue;

      result.push({
        section,
        data: withData.map(({ hasAnyValue: _, ...rest }) => rest),
      });
    }

    return result;
  }

  /** Body metrics (Körperwerte) – sectioned format matching getTests output */
  async getMetrics(clientId: number) {
    const rows = await this.metricRepo.find({
      where: { client_id: clientId },
      order: { date: 'DESC' },
    });

    if (!rows.length) return [];

    // Metric field definitions
    const metricDefs: Record<string, { label: string; unit: string }> = {
      weight: { label: 'Gewicht', unit: 'kg' },
      body_fat_perc: { label: 'Körperfett', unit: '%' },
      body_fat_kg: { label: 'Fettmasse', unit: 'kg' },
      bcm: { label: 'BCM', unit: 'kg' },
      waist_circumference: { label: 'Bauchumfang', unit: 'cm' },
      calm_pulse: { label: 'Ruhepuls', unit: 'bpm' },
      sys: { label: 'Blutdruck (sys)', unit: 'mmHg' },
      dia: { label: 'Blutdruck (dia)', unit: 'mmHg' },
    };

    const items: {
      key: string;
      value: string | null;
      previousValue: string | null;
      change: string;
      unit: string;
      history: { date: string; value: string }[];
    }[] = [];

    for (const [column, def] of Object.entries(metricDefs)) {
      const history: { date: string; value: string }[] = [];
      for (const row of rows) {
        const raw = row[column];
        if (raw != null && Number(raw) > 0) {
          history.push({ date: row.date, value: this.formatMetricValue(Number(raw)) });
        }
      }

      if (history.length === 0) continue;

      const latest = history[0].value;
      const previous = history.length > 1 ? history[1].value : null;

      let change = '';
      if (latest != null && previous != null) {
        const diff = Number(latest) - Number(previous);
        change = diff > 0
          ? `+${this.formatMetricValue(diff)}`
          : this.formatMetricValue(diff);
      }

      // Chronological for chart
      const chronological = [...history].reverse();

      items.push({
        key: def.label,
        value: latest,
        previousValue: previous,
        change,
        unit: def.unit,
        history: chronological,
      });
    }

    if (items.length === 0) return [];

    return [{ section: 'Körperwerte', data: items }];
  }

  /** Book a training appointment — with full validation */
  async bookAppointment(clientId: number, body: any) {
    const DURATION = SLOT_MINUTES; // Training dauert immer 60 Minuten

    // ── 1. Eingaben prüfen ─────────────────────────────────────────
    const trainerId = Number(body.trainer_id ?? body.trainerId);
    const requestedTypeId = Number(body.training_type_id ?? body.trainingTypeId);
    const rawLocation = body.location_id ?? body.locationId;
    const requestedLocationId = rawLocation != null && rawLocation !== '' ? Number(rawLocation) : null;
    const date = body.date;
    const starttime = body.starttime ?? body.time_from ?? body.from;

    if (!trainerId || !requestedTypeId || !date || !starttime) {
      throw new BadRequestException(
        'Trainer, Trainingsart, Datum und Startzeit sind erforderlich.',
      );
    }
    const reqStart = parseClock(starttime);
    if (!isIsoDay(date) || reqStart == null
        || (requestedLocationId != null && !Number.isInteger(requestedLocationId))) {
      throw new BadRequestException('Ungültiges Datum oder ungültige Uhrzeit.');
    }
    const reqEnd = reqStart + DURATION;
    const startClock = formatClock(reqStart);

    // ── 2. Nicht in der Vergangenheit, mindestens 12 Stunden vorher ──
    if (date < this.swissToday()) {
      throw new BadRequestException('Buchungen in der Vergangenheit sind nicht möglich.');
    }
    const appointmentDate = this.swissDateTime(date, startClock);
    const hoursUntilAppointment = (appointmentDate.getTime() - Date.now()) / (1000 * 60 * 60);
    if (hoursUntilAppointment < MIN_ADVANCE_HOURS) {
      throw new BadRequestException(
        `Buchungen müssen mindestens ${MIN_ADVANCE_HOURS} Stunden im Voraus erfolgen.`,
      );
    }

    // ── 3. Nur bei eigenen Trainern buchen ─────────────────────────
    const client = await this.clientRepo.findOne({ where: { id: clientId }, relations: ['trainers'] });
    if (!client) throw new NotFoundException(`Client ${clientId} not found`);
    if (!(client.trainers ?? []).some((t) => t.id === trainerId)) {
      throw new BadRequestException('Bei diesem Trainer kannst du keine Termine buchen.');
    }

    // ── 4. Muss in eine Verfügbarkeit passen (ohne Verfügbarkeit: nicht buchbar)
    const availability = await this.availRepo.find({ where: { trainerId, date } });
    const window = matchingWindow(
      availability.map((a) => ({
        from: a.from, to: a.to,
        locationId: a.locationId ?? null, trainingTypeId: a.trainingTypeId ?? null,
      })),
      reqStart, reqEnd, requestedLocationId,
    );
    if (!window) {
      throw new BadRequestException('Zu dieser Zeit ist der Trainer nicht verfügbar.');
    }
    // Standort und Trainingsart kommen aus der Verfügbarkeit, sofern dort gesetzt
    const locationId = window.locationId ?? requestedLocationId;
    const trainingTypeId = window.trainingTypeId ?? requestedTypeId;

    const allLocations = await this.locationRepo.find();
    if (locationId != null && !allLocations.some((l) => l.id === locationId && l.active === 1)) {
      throw new BadRequestException('Dieser Standort ist nicht buchbar.');
    }
    const buffers = new Map(allLocations.map((l) => [l.id, l.bufferMinutes ?? DEFAULT_BUFFER_MINUTES]));

    // ── 5. Fremdkalender des Trainers ──────────────────────────────
    const [yy, mm, dd] = date.split('-').map(Number);
    const reqStartAt = wallClockToInstant(yy, mm, dd, Math.floor(reqStart / 60), reqStart % 60);
    const reqEndAt = new Date(reqStartAt.getTime() + DURATION * 60_000);
    const external = await this.externalBusyRepo.findOne({
      where: { trainerId, startsAt: LessThan(reqEndAt), endsAt: MoreThan(reqStartAt) },
    });
    if (external) {
      throw new BadRequestException('Der Trainer ist zu dieser Zeit bereits belegt.');
    }

    // ── 6. Konflikte prüfen + Guthaben abbuchen + Termin anlegen ───
    // In einer Transaktion mit Sperren auf Trainer und Guthaben: zwei
    // gleichzeitige Buchungen laufen nacheinander und sehen sich gegenseitig.
    const coachingIds = await this.coachingCreditIds(clientId);
    const saved = await this.dataSource.transaction(async (manager) => {
      await manager.query('SELECT id FROM trainer WHERE id = ? FOR UPDATE', [trainerId]);
      const creditPacks = await manager.find(ClientCredits, {
        where: { clientId },
        order: { expires: 'ASC' },
        lock: { mode: 'pessimistic_write' },
      });

      const activeStatus = In([TrainingStatus.BOOKED, TrainingStatus.ATTENDED]);
      const toRange = (t: Training) => {
        const start = parseClock(t.starttime) ?? 0;
        return { start, end: start + (t.duration || DURATION), locationId: t.locationId ?? null };
      };

      // Keine Doppelbuchung des Kunden
      const clientTrainings = await manager.find(Training, {
        where: { clientId, date, status: activeStatus },
        lock: { mode: 'pessimistic_read' },
      });
      if (clientTrainings.some((t) => overlaps({ start: reqStart, end: reqEnd }, toRange(t)))) {
        throw new BadRequestException('Du hast bereits einen Termin zu dieser Zeit.');
      }

      // Keine Überschneidung beim Trainer (mit Puffer je Standort)
      const trainerTrainings = await manager.find(Training, {
        where: { trainerId, date, status: activeStatus },
        lock: { mode: 'pessimistic_read' },
      });
      const conflict = trainerConflict(
        { start: reqStart, end: reqEnd, locationId },
        trainerTrainings.map(toRange),
        buffers,
      );
      if (conflict) {
        throw new BadRequestException(
          conflict.buffer > 0
            ? `Trainer hat einen Termin an einem anderen Standort. ${conflict.buffer} Minuten Pufferzeit erforderlich.`
            : 'Trainer ist zu dieser Zeit bereits gebucht.',
        );
      }

      // Lektionen-Guthaben abbuchen (Coaching-Einträge zählen nicht)
      const todayDate = new Date();
      todayDate.setHours(0, 0, 0, 0);
      let usedPackId: number | null = null;
      for (const pack of creditPacks) {
        if (coachingIds.has(pack.id)) continue;
        const remaining = (pack.paid ?? 0) - (pack.attended ?? 0);
        if (remaining <= 0) continue;

        // Skip expired packs
        if (pack.expires) {
          const expiryDate = new Date(pack.expires);
          expiryDate.setHours(23, 59, 59, 999);
          if (expiryDate < todayDate) continue;
        }

        // Skip packs not yet active
        if (pack.startdate) {
          const startDate = new Date(pack.startdate);
          startDate.setHours(0, 0, 0, 0);
          if (startDate > todayDate) continue;
        }

        pack.attended = (pack.attended ?? 0) + 1;
        await manager.save(pack);
        usedPackId = pack.id;
        break;
      }

      if (usedPackId == null) {
        throw new BadRequestException(
          'Kein Guthaben für Lektionen. Pakete findest du im Profil unter „Lektionen & Guthaben“.',
        );
      }

      const training = manager.create(Training, {
        clientId,
        trainerId,
        trainingTypeId,
        locationId: locationId ?? undefined,
        date,
        starttime: startClock,
        duration: DURATION,
        status: TrainingStatus.BOOKED,
        creditsCharged: 1,
        creditPackId: usedPackId,
      });
      return await manager.save(training) as Training;
    });

    // Load relations for full response (outside transaction)
    const full = await this.trainingRepo.findOne({
      where: { id: saved.id },
      relations: ['trainer', 'trainingType', 'location'],
    });

    return this.mapTraining(full ?? saved);
  }

  /** Cancel appointment — with credit refund */
  async cancelAppointment(clientId: number, appointmentId: number) {
    const training = await this.trainingRepo.findOne({
      where: { id: appointmentId, clientId },
    });
    if (!training) throw new NotFoundException('Termin nicht gefunden.');

    if (training.status === TrainingStatus.CANCELLED) {
      throw new BadRequestException('Termin ist bereits abgesagt.');
    }
    if (training.status === TrainingStatus.ATTENDED) {
      throw new BadRequestException('Absolvierte Termine können nicht storniert werden.');
    }
    if (training.status === TrainingStatus.MISSED) {
      throw new BadRequestException('Verpasste Termine können nicht storniert werden.');
    }

    // Spät (weniger als 12 Stunden vorher): Lektion verfällt. Begonnene oder
    // vergangene Termine lassen sich nicht mehr absagen.
    const appointmentDate = this.swissDateTime(training.date, training.starttime);
    const hoursUntilAppointment =
      (appointmentDate.getTime() - Date.now()) / (1000 * 60 * 60);
    if (hoursUntilAppointment <= 0) {
      throw new BadRequestException('Vergangene Termine können nicht abgesagt werden.');
    }
    const isLateCancellation = hoursUntilAppointment < MIN_ADVANCE_HOURS;

    // Refund + status update in a single transaction to prevent partial state
    await this.dataSource.transaction(async (manager) => {
      // Refund credit only for timely cancellations (>= 12 hours before)
      if (training.creditsCharged && training.creditsCharged > 0 && !isLateCancellation) {
        // Try to refund to the exact pack that was charged
        if (training.creditPackId) {
          const originalPack = await manager.findOne(ClientCredits, {
            where: { id: training.creditPackId },
          });
          if (originalPack && (originalPack.attended ?? 0) > 0) {
            originalPack.attended = (originalPack.attended ?? 0) - 1;
            await manager.save(originalPack);
          }
        } else {
          // Fallback for older bookings without creditPackId
          const creditPacks = await manager.find(ClientCredits, {
            where: { clientId },
            order: { expires: 'ASC' },
          });
          for (const pack of creditPacks) {
            if ((pack.attended ?? 0) > 0) {
              pack.attended = (pack.attended ?? 0) - 1;
              await manager.save(pack);
              break;
            }
          }
        }
      }

      training.status = TrainingStatus.CANCELLED;
      training.cancelledAt = new Date().toISOString();
      training.cancelledByClientId = clientId;
      if (!isLateCancellation) {
        training.creditsCharged = 0;
      }
      // Late cancellation: creditsCharged stays 1 (penalty)
      await manager.save(training);
    });

    return {
      success: true,
      lateCancellation: isLateCancellation,
      creditRefunded: !isLateCancellation,
    };
  }

  /** Client files — returns proxy download URLs (no direct URLs exposed) */
  async getFiles(clientId: number) {
    const files = await this.fileRepo.find({
      where: { clientId },
      order: { date: 'DESC' },
    });
    return files.map((f) => ({
      id: f.id,
      name: f.name,
      file: f.file ? `/api/file/${f.id}/download` : null,
      date: f.date,
      client_id: f.clientId,
    }));
  }

  /** Training reviews — transformed for Flutter TrainingReview model */
  async getReviews(clientId: number) {
    const reviews = await this.reviewService.findByClient(clientId);

    // For each review, load timeseries and compute HR stats
    const results = await Promise.all(
      reviews.map(async (review) => {
        const timeseries = await this.reviewService.getTimeseries(review.id);

        // Build chart data: { t: timestamp, v: heart rate value }
        const chart = timeseries
          .filter((ts) => ts.value != null)
          .map((ts) => ({
            t: ts.timestamp ?? '',
            v: ts.value,
          }));

        // Compute HR stats from timeseries
        const hrValues = chart.map((p) => p.v).filter((v) => v > 0);
        const hrMax = hrValues.length ? Math.max(...hrValues) : null;
        const hrAvg = review.heart_rate
          ? Math.round(review.heart_rate)
          : hrValues.length
            ? Math.round(hrValues.reduce((a, b) => a + b, 0) / hrValues.length)
            : null;

        // App-Aufzeichnungen tragen ihr Datum direkt, gebuchte Trainings via Relation
        const trainingDate = review.date ?? review.training?.date ?? '';

        return {
          id: review.id,
          date: trainingDate,
          trainingType: review.training_type ?? review.type ?? '',
          duration: review.duration,
          hrMax,
          hrAvg,
          hrr: null, // Heart Rate Recovery – requires specific protocol data
          hrv: null, // Heart Rate Variability – requires R-R interval data
          source: review.source ?? null,
          distance: review.distance ?? null,          // Meter (App-Aufzeichnungen)
          elevationGain: review.elevation_gain ?? null,
          chart,
        };
      }),
    );

    return results;
  }

  /** App-recorded workout upload: validates + persists review & HR series */
  async createWorkout(clientId: number, body: any) {
    // Idempotenz: dieselbe Aufzeichnung (UUID vom Client) darf nur einmal
    // entstehen — ein Nachreichen aus der Warteschlange nach Timeout/Abbruch
    // liefert dann die bestehende id statt ein zweites Training anzulegen.
    const rawRid = String(body?.clientRecordingId ?? '').trim();
    const clientRecordingId = /^[A-Za-z0-9-]{8,36}$/.test(rawRid) ? rawRid : null;
    if (clientRecordingId) {
      const existing = await this.dataSource.query(
        'SELECT id FROM review WHERE client_id = ? AND client_recording_id = ? LIMIT 1',
        [clientId, clientRecordingId]);
      if (existing.length) {
        return { success: true, id: existing[0].id, duplicate: true };
      }
    }

    const trainingType = String(body?.trainingType ?? '').trim() || 'Training';
    const date = String(body?.startedAt ?? '').trim();
    if (!date || Number.isNaN(Date.parse(date))) {
      throw new Error('startedAt (ISO-Datum) fehlt oder ist ungueltig');
    }
    const duration =
      typeof body?.duration === 'string' && /^\d{2}:\d{2}:\d{2}$/.test(body.duration)
        ? body.duration
        : null;

    const rawSeries: any[] = Array.isArray(body?.hrSeries) ? body.hrSeries : [];
    if (rawSeries.length > 50000) {
      throw new Error('hrSeries zu gross (max. 50000 Punkte)');
    }
    const hrSeries = rawSeries
      .map((p) => ({
        t: String(p?.t ?? ''),
        v: Math.round(Number(p?.v ?? 0)),
      }))
      .filter((p) => p.t && !Number.isNaN(Date.parse(p.t)) && p.v > 20 && p.v < 250);

    const hrValues = hrSeries.map((p) => p.v);
    const heartRate = hrValues.length
      ? Math.round(hrValues.reduce((a, b) => a + b, 0) / hrValues.length)
      : null;
    const kcal = Number.isFinite(Number(body?.kcal)) && Number(body.kcal) > 0
      ? Math.round(Number(body.kcal))
      : null;

    // GPS-Track (Phase 2) — optional, gefiltert und begrenzt
    const rawTrack: any[] = Array.isArray(body?.gpsTrack) ? body.gpsTrack : [];
    if (rawTrack.length > 30000) {
      throw new Error('gpsTrack zu gross (max. 30000 Punkte)');
    }
    const gpsTrack = rawTrack
      .map((p) => ({
        t: String(p?.t ?? ''),
        lat: Number(p?.lat),
        lon: Number(p?.lon),
        ele: Number.isFinite(Number(p?.ele)) ? Number(p.ele) : null,
        acc: Number.isFinite(Number(p?.acc)) ? Number(p.acc) : null,
      }))
      .filter(
        (p) =>
          p.t && !Number.isNaN(Date.parse(p.t)) &&
          Number.isFinite(p.lat) && Number.isFinite(p.lon) &&
          Math.abs(p.lat) <= 90 && Math.abs(p.lon) <= 180,
      );

    const distanceMeters =
      Number.isFinite(Number(body?.distanceMeters)) && Number(body.distanceMeters) > 0
        ? Math.round(Number(body.distanceMeters))
        : null;
    const elevationGain =
      Number.isFinite(Number(body?.elevationGain)) && Number(body.elevationGain) >= 0
        ? Math.round(Number(body.elevationGain))
        : null;

    let review;
    try {
      review = await this.reviewService.createWorkout({
        clientId,
        clientRecordingId,
        date: new Date(date).toISOString().slice(0, 19).replace('T', ' '),
        trainingType,
        duration,
        heartRate,
        kcal,
        distanceMeters,
        elevationGain,
        hrSeries,
        gpsTrack,
      });
    } catch (e: any) {
      // Wettlauf zweier gleichzeitiger Uploads: der Unique-Index gewinnt,
      // der Verlierer bekommt die bereits angelegte id zurück
      if (clientRecordingId && String(e?.code ?? e?.message).includes('ER_DUP_ENTRY')) {
        const existing = await this.dataSource.query(
          'SELECT id FROM review WHERE client_id = ? AND client_recording_id = ? LIMIT 1',
          [clientId, clientRecordingId]);
        if (existing.length) return { success: true, id: existing[0].id, duplicate: true };
      }
      throw e;
    }

    return {
      success: true,
      id: review.id,
      hrMax: hrValues.length ? Math.max(...hrValues) : null,
      hrAvg: heartRate,
      points: hrSeries.length,
      trackPoints: gpsTrack.length,
    };
  }

  /** GPS-Track einer Aufzeichnung (fürs Karten-/Höhenprofil-Detail) */
  async getWorkoutTrack(clientId: number, reviewId: number) {
    const rows = await this.reviewService.getTrackForClient(clientId, reviewId);
    return rows.map((r) => ({
      t: r.timestamp,
      lat: r.lat,
      lon: r.lon,
      ele: r.ele ?? null,
    }));
  }

  // ── Touren-Discovery (T1, s. client-ios/KONZEPT-TOUREN.md) ────────
  // Proxy + Cache vor der Overpass API: markierte OSM-Routen-Relationen
  // (Wanderland/Veloland etc.). Cache ist Pflicht (Overpass fair use).

  // ── Trainings-Galerie (F1) ───────────────────────────────────────────

  /** Foto zu einer Aufzeichnung speichern (ein Bild je Training). */
  async saveWorkoutPhoto(clientId: number, reviewId: number, base64: string, mime: string) {
    const owns = await this.dataSource.query(
      'SELECT id FROM review WHERE id = ? AND client_id = ? LIMIT 1', [reviewId, clientId]);
    if (!owns.length) throw new Error('Aufzeichnung nicht gefunden');

    const bytes = Buffer.from(String(base64).replace(/^data:[^,]+,/, ''), 'base64');
    if (!bytes.length) throw new Error('Leeres Bild');
    if (bytes.length > 3 * 1024 * 1024) throw new Error('Bild zu gross (max. 3 MB)');

    // Ein Foto je Training: ein vorhandenes wird ersetzt — in EINER
    // Transaktion, damit ein fehlschlagender Insert das alte Foto nicht
    // bereits gelöscht zurücklässt
    const saved = await this.photoRepo.manager.transaction(async (m) => {
      const repo = m.getRepository(ReviewPhoto);
      await repo.delete({ reviewId });
      return repo.save({
        reviewId, clientId,
        mime: mime === 'image/png' ? 'image/png' : 'image/jpeg',
        bytes, createdAt: new Date(),
      });
    });
    return { success: true, photoId: saved.id };
  }

  /** Galerie-Einträge des Kunden — Metadaten inkl. Trainingswerte. */
  async getWorkoutPhotos(clientId: number, activity?: string, reviewId?: number) {
    // Filter in SQL, nicht nach dem LIMIT — sonst zeigte die Galerie für
    // seltene Aktivitäten fälschlich „leer" und das Detail fand ältere
    // Fotos nicht mehr (und bot an, sie zu überschreiben)
    const where: string[] = ['p.client_id = ?'];
    const params: any[] = [clientId];
    if (activity) { where.push('LOWER(r.training_type) = LOWER(?)'); params.push(activity); }
    if (reviewId) { where.push('p.review_id = ?'); params.push(reviewId); }
    const rows = await this.dataSource.query(
      `SELECT p.id AS photoId, p.review_id AS reviewId,
              r.training_type AS activity, r.date AS date, r.duration AS duration,
              r.distance AS distance, r.elevation_gain AS elevationGain,
              r.heart_rate AS avgHr
         FROM review_photo p
         JOIN review r ON r.id = p.review_id
        WHERE ${where.join(' AND ')}
        ORDER BY r.date DESC
        LIMIT 60`, params);

    return rows
      .map((r: any) => ({
        photoId: r.photoId,
        reviewId: r.reviewId,
        activity: r.activity,
        date: r.date,
        duration: r.duration,
        distanceMeters: r.distance ? Math.round(Number(r.distance)) : null,
        elevationGain: r.elevationGain ?? null,
        avgHr: r.avgHr ? Math.round(Number(r.avgHr)) : null,
      }));
  }

  /** Bilddaten eines Fotos (Ownership geprüft). */
  async getWorkoutPhotoBytes(clientId: number, photoId: number) {
    const photo = await this.photoRepo.findOne({ where: { id: photoId, clientId } });
    if (!photo) throw new Error('Foto nicht gefunden');
    return { mime: photo.mime, bytes: photo.bytes };
  }

  async deleteWorkoutPhoto(clientId: number, photoId: number) {
    const res = await this.photoRepo.delete({ id: photoId, clientId });
    return { success: (res.affected ?? 0) > 0 };
  }

  // ── Helpers ──────────────────────────────────────────────────────

  private async getTotalCredits(clientId: number): Promise<number> {
    const rows = await this.creditsRepo.find({ where: { clientId } });
    const coachingIds = await this.coachingCreditIds(clientId);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    return rows.reduce((sum, r) => {
      // Coaching-Einträge sind kein Lektionen-Guthaben
      if (coachingIds.has(r.id)) return sum;
      // Skip expired packs
      if (r.expires) {
        const expiryDate = new Date(r.expires);
        expiryDate.setHours(23, 59, 59, 999);
        if (expiryDate < today) return sum;
      }
      // Skip packs not yet active
      if (r.startdate) {
        const startDate = new Date(r.startdate);
        startDate.setHours(0, 0, 0, 0);
        if (startDate > today) return sum;
      }
      return sum + ((r.paid ?? 0) - (r.attended ?? 0));
    }, 0);
  }

  /**
   * IDs der Guthaben-Einträge aus einem Online-Coaching-Kauf (über
   * coaching_invoice_number verknüpft). Roh gelesen, damit ein Fehlen der
   * Spalte Guthaben und Buchung nicht bricht.
   */
  private async coachingCreditIds(clientId: number): Promise<Set<number>> {
    try {
      const rows: { id: number }[] = await this.dataSource.query(
        'SELECT id FROM client_credits WHERE client_id = ? AND coaching_invoice_number IS NOT NULL',
        [clientId],
      );
      return new Set(rows.map((r) => Number(r.id)));
    } catch {
      return new Set();
    }
  }

  /** Format a numeric metric: strip trailing .00 decimals for clean display */
  private formatMetricValue(val: number): string {
    // If the value is an integer, return without decimals
    if (Number.isInteger(val)) return String(val);
    // Otherwise keep up to 2 decimal places, trimming trailing zeros
    const fixed = val.toFixed(2).replace(/\.?0+$/, '');
    return fixed;
  }

  private mapTraining(t: Training) {
    const endMinutes =
      t.starttime && t.duration
        ? (() => {
            const [h, m] = t.starttime.split(':').map(Number);
            const total = h * 60 + m + t.duration;
            return `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}:00`;
          })()
        : null;

    return {
      id: t.id,
      date: t.date,
      starttime: t.starttime,
      time_from: t.starttime,
      time_to: endMinutes,
      status: t.status,
      trainer_id: t.trainerId,
      training_type_id: t.trainingTypeId,
      training_type_name: t.trainingType?.name_de ?? t.trainingType?.name_en ?? '',
      location_id: t.locationId,
      location_name: t.location?.name ?? '',
      duration: t.duration,
      credits_charged: t.creditsCharged ?? 0,
      notes: t.text,
      trainer: t.trainer
        ? {
            id: t.trainer.id,
            firstname: (t.trainer.firstname ?? '').trim(),
            lastname: (t.trainer.lastname ?? '').trim(),
            picture: t.trainer.picture,
          }
        : undefined,
    };
  }

  // ── Preferences ──────────────────────────────────────────────────

  /** Known booking preference keys */
  private static readonly PREF_KEYS = ['trainer_id', 'training_type_id', 'location_id'];

  /** Get client booking preferences (trainer, type, location defaults) */
  async getPreferences(clientId: number) {
    try {
      // Raw query — `key` is a MySQL reserved word, bypass TypeORM entity
      const rows: any[] = await this.dataSource.query(
        'SELECT `key`, `value` FROM `preference` WHERE `client_id` = ?',
        [clientId],
      );
      const result: Record<string, number | null> = {};
      for (const key of ClientAppService.PREF_KEYS) {
        const row = rows.find((r: any) => r.key === key);
        const val = row?.value ?? null;
        result[key] = val !== null ? Number(val) : null;
      }
      return result;
    } catch (err: any) {
      // Table may not exist or have wrong schema — try to fix, then return defaults
      if (err?.code === 'ER_BAD_FIELD_ERROR' || err?.code === 'ER_NO_SUCH_TABLE') {
        try {
          await this.dataSource.query(`DROP TABLE IF EXISTS preference`);
          await this.dataSource.query(`
            CREATE TABLE preference (
              id INT AUTO_INCREMENT PRIMARY KEY,
              client_id INT NOT NULL,
              \`key\` VARCHAR(50) DEFAULT NULL,
              \`value\` VARCHAR(255) DEFAULT NULL,
              INDEX idx_pref_client (client_id),
              UNIQUE KEY uk_client_key (client_id, \`key\`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
          `);
        } catch { /* ignore */ }
        return { trainer_id: null, training_type_id: null, location_id: null };
      }
      throw err;
    }
  }

  /** Save client booking preferences (partial update — only provided keys are updated) */
  async savePreferences(clientId: number, prefs: Record<string, string | null>) {
    const saved: Record<string, string | null> = {};

    // Ensure table has correct schema (idempotent)
    try {
      await this.dataSource.query(
        'SELECT `key` FROM `preference` LIMIT 1',
      );
    } catch {
      // Table missing or wrong schema — try to create
      try {
        await this.dataSource.query(`DROP TABLE IF EXISTS preference`);
        await this.dataSource.query(`
          CREATE TABLE preference (
            id INT AUTO_INCREMENT PRIMARY KEY,
            client_id INT NOT NULL,
            \`key\` VARCHAR(50) DEFAULT NULL,
            \`value\` VARCHAR(255) DEFAULT NULL,
            INDEX idx_pref_client (client_id),
            UNIQUE KEY uk_client_key (client_id, \`key\`)
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        `);
      } catch { /* ignore if we can't create */ }
    }

    for (const key of ClientAppService.PREF_KEYS) {
      if (!(key in prefs)) continue;

      const value = prefs[key];

      try {
        const existing: any[] = await this.dataSource.query(
          'SELECT id FROM `preference` WHERE `client_id` = ? AND `key` = ?',
          [clientId, key],
        );

        if (value === null || value === '') {
          if (existing.length > 0) {
            await this.dataSource.query(
              'DELETE FROM `preference` WHERE `client_id` = ? AND `key` = ?',
              [clientId, key],
            );
          }
          saved[key] = null;
        } else if (existing.length > 0) {
          await this.dataSource.query(
            'UPDATE `preference` SET `value` = ? WHERE `client_id` = ? AND `key` = ?',
            [String(value), clientId, key],
          );
          saved[key] = String(value);
        } else {
          await this.dataSource.query(
            'INSERT INTO `preference` (`client_id`, `key`, `value`) VALUES (?, ?, ?)',
            [clientId, key, String(value)],
          );
          saved[key] = String(value);
        }
      } catch {
        saved[key] = null;
      }
    }

    return saved;
  }
}
