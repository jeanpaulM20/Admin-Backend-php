import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, MoreThanOrEqual, In } from 'typeorm';
import { Client } from '../entities/client.entity';
import { Training, TrainingStatus } from '../entities/training.entity';
import { TrainerAvailability } from '../entities/trainer-availability.entity';
import { Trainer } from '../entities/trainer.entity';
import { ClientCredits, TrainingType, PerformanceTest, File as ClientFile } from '../entities/remaining.entities';
import { Metric } from '../entities/metric.entity';
import { Location } from '../entities/location.entity';
import { ReviewService } from '../review/review.service';
import { InvoiceService } from '../invoice/invoice.service';
import { EntitlementService } from '../entitlement/entitlement.service';

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

    const [trainingTypes, availability, trainings, locations, credits, trainerTrainings] =
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
      ]);

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
      trainer_bookings: trainerTrainings.map((t) => ({
        id: t.id,
        trainer_id: t.trainerId,
        date: t.date,
        starttime: t.starttime,
        duration: t.duration || 60,
        location_id: t.locationId,
        status: t.status,
      })),
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
    return credits.map((c) => ({
      id: c.id,
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
        await queryRunner.query(
          `INSERT INTO client_credits (client_id, training_type_id, paid, attended, abbonement_id, sold_by_id, startdate, expires, sell_date)
           VALUES (?, NULL, ?, 0, NULL, NULL, ?, ?, ?)`,
          [clientId, credits, startDate, expiresStr, startDate],
        );

        // 4b. Create invoice (uses same queryRunner → same transaction)
        logger.log('Creating invoice');
        invoiceNumber = await this.invoiceService.createInvoice(
          { clientId, packageName, amount: price, credits, durationMonths: durationMonths ?? 1 },
          queryRunner,
        );

        // 4c. Coaching package → also create the subscription entitlement period
        if (pkg.kind === 'coaching') {
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
    const DURATION = 60; // Training is always 60 minutes
    const MIN_ADVANCE_HOURS = 12; // Minimum hours in advance for booking
    // Buffer is now dynamic per location (3-tier: same=0, different=30, Andere=60)

    // ── 1. Parse & validate input ─────────────────────────────────
    const trainerId = Number(body.trainer_id ?? body.trainerId);
    const trainingTypeId = Number(body.training_type_id ?? body.trainingTypeId);
    const locationId = body.location_id ?? body.locationId
      ? Number(body.location_id ?? body.locationId)
      : null;
    const date: string = body.date;
    const starttime: string = body.starttime ?? body.time_from ?? body.from;

    if (!trainerId || !trainingTypeId || !date || !starttime) {
      throw new BadRequestException(
        'Trainer, Trainingsart, Datum und Startzeit sind erforderlich.',
      );
    }

    // ── 2. Date must not be in the past ───────────────────────────
    const now = new Date();
    const today = this.swissToday();
    if (date < today) {
      throw new BadRequestException(
        'Buchungen in der Vergangenheit sind nicht möglich.',
      );
    }

    // ── 2b. Must book at least 12 hours in advance ──────────────
    const appointmentDate = this.swissDateTime(date, starttime);
    const hoursUntilAppointment =
      (appointmentDate.getTime() - now.getTime()) / (1000 * 60 * 60);
    if (hoursUntilAppointment < MIN_ADVANCE_HOURS) {
      throw new BadRequestException(
        `Buchungen müssen mindestens ${MIN_ADVANCE_HOURS} Stunden im Voraus erfolgen.`,
      );
    }

    // ── 3. Parse requested time window ────────────────────────────
    const [reqH, reqM] = starttime.split(':').map(Number);
    if (isNaN(reqH) || isNaN(reqM)) {
      throw new BadRequestException('Ungültiges Zeitformat.');
    }
    const reqStart = reqH * 60 + reqM;
    const reqEnd = reqStart + DURATION;

    // ── 4. Check trainer has availability on this date ─────────────
    const availability = await this.availRepo.find({
      where: { trainerId, date },
    });

    if (availability.length > 0) {
      const fitsSlot = availability.some((slot) => {
        const [fH, fM] = (slot.from || '00:00').split(':').map(Number);
        const [tH, tM] = (slot.to || '23:59').split(':').map(Number);
        const slotStart = fH * 60 + fM;
        const slotEnd = tH * 60 + tM;
        return reqStart >= slotStart && reqEnd <= slotEnd;
      });
      if (!fitsSlot) {
        throw new BadRequestException(
          'Die gewählte Zeit liegt außerhalb der Trainer-Verfügbarkeit.',
        );
      }
    }

    // ── 5. No double booking for CLIENT ───────────────────────────
    const clientTrainings = await this.trainingRepo.find({
      where: {
        clientId,
        date,
        status: In([TrainingStatus.BOOKED, TrainingStatus.ATTENDED]),
      },
    });

    for (const t of clientTrainings) {
      const [eH, eM] = (t.starttime || '00:00').split(':').map(Number);
      const existStart = eH * 60 + eM;
      const existEnd = existStart + (t.duration || DURATION);
      if (reqStart < existEnd && existStart < reqEnd) {
        throw new BadRequestException(
          'Du hast bereits einen Termin zu dieser Zeit.',
        );
      }
    }

    // ── 6. No trainer conflict (with dynamic 3-tier location buffer) ──
    // Buffer logic:
    //   Same location     → 0 min
    //   Different location → MAX(buffer_a, buffer_b) (typically 30 min)
    //   "Andere" involved  → MAX(buffer_a, buffer_b) = MAX(60, x) = 60 min
    const trainerTrainings = await this.trainingRepo.find({
      where: {
        trainerId,
        date,
        status: In([TrainingStatus.BOOKED, TrainingStatus.ATTENDED]),
      },
    });

    // Load locations to get buffer_minutes values
    const allLocations = await this.locationRepo.find();
    const locationMap = new Map(allLocations.map(l => [l.id, l]));

    // Get buffer_minutes for the requested location
    const reqLocation = locationId ? locationMap.get(locationId) : null;
    const reqBuffer = reqLocation?.bufferMinutes ?? 30;

    for (const t of trainerTrainings) {
      const [eH, eM] = (t.starttime || '00:00').split(':').map(Number);
      const existStart = eH * 60 + eM;
      const existEnd = existStart + (t.duration || DURATION);

      // 3-tier buffer: same location = 0, different = MAX(both buffers)
      const sameLocation =
        locationId != null &&
        t.locationId != null &&
        Number(t.locationId) === locationId;

      let buffer = 0;
      if (!sameLocation) {
        const existLocation = t.locationId ? locationMap.get(Number(t.locationId)) : null;
        const existBuffer = existLocation?.bufferMinutes ?? 30;
        buffer = Math.max(reqBuffer, existBuffer);
      }

      if (reqStart < existEnd + buffer && existStart < reqEnd + buffer) {
        if (buffer > 0) {
          throw new BadRequestException(
            `Trainer hat einen Termin an einem anderen Standort. ` +
              `${buffer} Minuten Pufferzeit erforderlich.`,
          );
        }
        throw new BadRequestException(
          'Trainer ist zu dieser Zeit bereits gebucht.',
        );
      }
    }

    // ── 7+8. Deduct credit + create training in a single transaction ──
    const saved = await this.dataSource.transaction(async (manager) => {
      const creditPacks = await manager.find(ClientCredits, {
        where: { clientId },
        order: { expires: 'ASC' },
      });

      // Find a valid credit pack with remaining balance
      let creditDeducted = false;
      let usedPackId: number | null = null;
      const todayDate = new Date();
      todayDate.setHours(0, 0, 0, 0);

      for (const pack of creditPacks) {
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
        creditDeducted = true;
        break;
      }

      if (!creditDeducted) {
        throw new BadRequestException(
          'Keine verfügbaren Credits. Bitte neue Credits kaufen.',
        );
      }

      const training = manager.create(Training, {
        clientId,
        trainerId,
        trainingTypeId,
        locationId: locationId ?? undefined,
        date,
        starttime,
        duration: DURATION,
        status: TrainingStatus.BOOKED,
        creditsCharged: 1,
        creditPackId: usedPackId ?? undefined,
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

    // Check if this is a late cancellation (less than 12 hours before appointment)
    const MIN_CANCEL_HOURS = 12;
    const now = new Date();
    const appointmentDate = this.swissDateTime(training.date, training.starttime);
    const hoursUntilAppointment =
      (appointmentDate.getTime() - now.getTime()) / (1000 * 60 * 60);
    const isLateCancellation = hoursUntilAppointment < MIN_CANCEL_HOURS;

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

    const review = await this.reviewService.createWorkout({
      clientId,
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

  private tourListCache = new Map<string, { at: number; data: any }>();
  private tourDetailCache = new Map<string, { at: number; data: any }>();
  private static readonly TOUR_TTL_MS = 24 * 60 * 60 * 1000;

  // Overpass-Nutzungsrichtlinie verlangt einen identifizierenden User-Agent —
  // Node-fetch sendet keinen und bekommt sonst 406 Not Acceptable.
  private static readonly OSM_UA = 'SihlClient-Backend/1.0 (sihltraining.ch)';

  private async overpass(query: string): Promise<any> {
    // osm.ch zuerst: Schweizer Instanz, für unser Einzugsgebiet ~10x schneller
    // und ohne die Lastprobleme der Hauptinstanz. Sie deckt aber nur die
    // Schweiz ab und liefert anderswo ein leeres (aber gültiges) Ergebnis —
    // ein leeres Ergebnis probiert darum die nächste Instanz, bevor es zählt.
    const endpoints = [
      'https://overpass.osm.ch/api/interpreter',
      'https://overpass-api.de/api/interpreter',
    ];
    let lastErr: Error = new Error('Overpass nicht erreichbar');
    let emptyResult: any = null;
    for (const endpoint of endpoints) {
      try {
        const res = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': ClientAppService.OSM_UA,
            Accept: 'application/json',
          },
          body: 'data=' + encodeURIComponent(query),
          signal: AbortSignal.timeout(20000),
        });
        if (!res.ok) { lastErr = new Error(`Overpass ${res.status}`); continue; }
        const json = await res.json();
        if ((json?.elements ?? []).length > 0) return json;
        emptyResult = json;
      } catch (err: any) {
        lastErr = err;
      }
    }
    if (emptyResult) return emptyResult;
    throw lastErr;
  }

  private static haversine(aLat: number, aLon: number, bLat: number, bLon: number): number {
    const R = 6371000;
    const dLat = ((bLat - aLat) * Math.PI) / 180;
    const dLon = ((bLon - aLon) * Math.PI) / 180;
    const s =
      Math.sin(dLat / 2) ** 2 +
      Math.cos((aLat * Math.PI) / 180) * Math.cos((bLat * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(s));
  }

  /**
   * Overpass-Selektoren je Aktivität. Finnenbahnen sind in OSM Wege (keine
   * Relationen) und oft nur über den Namen erkennbar — daher zwei Selektoren
   * als Union; ihre IDs bekommen ein "w"-Präfix fürs Detail.
   */
  private static tourSpec(activity: string): { selectors: string[]; osm: string } {
    switch (activity) {
      case 'rad':
      case 'rennrad':
        return { selectors: ['relation["route"="bicycle"]["name"]'], osm: 'bicycle' };
      case 'mtb':
        return { selectors: ['relation["route"="mtb"]["name"]'], osm: 'mtb' };
      case 'joggen':
        return { selectors: ['relation["route"="running"]["name"]'], osm: 'running' };
      case 'vitaparcours':
        return { selectors: ['relation["route"="fitness_trail"]["name"]'], osm: 'fitness_trail' };
      case 'finnenbahn':
        return {
          selectors: ['way["leisure"="track"]["sport"="running"]', 'way["name"~"[Ff]innenbahn"]'],
          osm: 'finnenbahn',
        };
      default:
        return { selectors: ['relation["route"="hiking"]["name"]'], osm: 'hiking' };
    }
  }

  /** Markierte OSM-Routen im Umkreis (gecacht, Raster 0.01°). */
  async getTours(lat: number, lon: number, radiusKm: number, activity: string) {
    const spec = ClientAppService.tourSpec(activity);
    const r = Math.min(Math.max(radiusKm, 1), 30);
    const key = `${spec.osm}:${lat.toFixed(2)}:${lon.toFixed(2)}:${Math.round(r)}`;
    const hit = this.tourListCache.get(key);
    if (hit && Date.now() - hit.at < ClientAppService.TOUR_TTL_MS) return hit.data;

    const around = `(around:${Math.round(r * 1000)},${lat},${lon})`;
    const query = `[out:json][timeout:25];
(${spec.selectors.map((sel) => sel + around + ';').join('')});
out tags center 80;`;
    const json = await this.overpass(query);

    const tours = (json?.elements ?? [])
      .filter((e: any) => e?.center && (e?.tags?.name || spec.osm === 'finnenbahn'))
      .map((e: any) => {
        const distKm = parseFloat(String(e.tags?.distance ?? '').replace(',', '.')) || null;
        return {
          id: (e.type === 'way' ? 'w' : '') + e.id,
          name: String(e.tags?.name ?? 'Finnenbahn'),
          ref: e.tags?.ref ?? null,
          activity: spec.osm,
          network: e.tags?.network ?? null,    // lwn/rwn/nwn = lokal/regional/national
          distanceKm: distKm,
          durationMin: distKm ? ClientAppService.tourDuration(distKm, spec.osm) : null,
          difficulty: distKm ? ClientAppService.tourDifficulty(distKm) : null,
          lat: e.center.lat,
          lon: e.center.lon,
        };
      })
      .sort((a: any, b: any) =>
        ClientAppService.haversine(lat, lon, a.lat, a.lon) -
        ClientAppService.haversine(lat, lon, b.lat, b.lon));

    this.tourListCache.set(key, { at: Date.now(), data: tours });
    return tours;
  }

  /** Geometrie + berechnete Werte einer Route (gecacht). */
  async getTourDetail(id: string) {
    const hit = this.tourDetailCache.get(id);
    if (hit && Date.now() - hit.at < ClientAppService.TOUR_TTL_MS) return hit.data;

    const isWay = id.startsWith('w');
    const numId = parseInt(isWay ? id.slice(1) : id, 10);
    if (!Number.isFinite(numId)) throw new Error('Ungueltige Touren-ID');
    const json = await this.overpass(
      `[out:json][timeout:60];${isWay ? 'way' : 'relation'}(${numId});out geom;`);
    const rel = (json?.elements ?? [])[0];
    if (!rel) throw new Error('Tour nicht gefunden');

    // Geometrie: Wege (Finnenbahnen) tragen sie direkt, Relationen über ihre
    // Member-Wege (Reihenfolge in OSM nicht garantiert — wir liefern Segmente;
    // Länge = Summe, korrekt unabhängig von Ordnung)
    const rawSegments: any[][] = isWay
      ? [rel.geometry ?? []]
      : (rel.members ?? [])
          .filter((m: any) => m.type === 'way' && Array.isArray(m.geometry))
          .map((m: any) => m.geometry);
    const segments: { lat: number; lon: number }[][] = [];
    let distanceM = 0;
    for (const geometry of rawSegments) {
      if (geometry.length < 2) continue;
      const seg = geometry.map((g: any) => ({ lat: g.lat, lon: g.lon }));
      for (let i = 1; i < seg.length; i++) {
        distanceM += ClientAppService.haversine(seg[i - 1].lat, seg[i - 1].lon, seg[i].lat, seg[i].lon);
      }
      segments.push(seg);
    }
    // Payload begrenzen: lange Segmente ausdünnen (max ~4000 Punkte gesamt)
    const total = segments.reduce((n, s) => n + s.length, 0);
    const stride = Math.max(1, Math.ceil(total / 4000));
    const slim = segments.map((seg) =>
      seg.filter((_, i) => i % stride === 0 || i === seg.length - 1));

    const distKm = distanceM / 1000;
    const routeTag = rel.tags?.route;
    const osmRoute = isWay
      ? 'finnenbahn'
      : ['bicycle', 'mtb', 'running', 'fitness_trail'].includes(routeTag)
        ? routeTag
        : 'hiking';
    const detail = {
      id,
      name: rel.tags?.name ?? 'Route',
      ref: rel.tags?.ref ?? null,
      activity: osmRoute,
      network: rel.tags?.network ?? null,
      operator: rel.tags?.operator ?? null,
      description: rel.tags?.description ?? null,
      distanceKm: Math.round(distKm * 10) / 10,
      durationMin: ClientAppService.tourDuration(distKm, osmRoute),
      difficulty: ClientAppService.tourDifficulty(distKm),
      segments: slim,
    };
    this.tourDetailCache.set(id, { at: Date.now(), data: detail });
    return detail;
  }

  /**
   * Rundtouren-Generator (T4): Wegpunkte auf einem Kreis durch den Start,
   * Routing über die freie BRouter-Instanz (OSM, inkl. Höhendaten).
   */
  async generateRoundtrip(lat: number, lon: number, distanceKm: number, activity: string, seed?: number) {
    const dist = Math.min(Math.max(distanceKm, 3), 60);
    const profile = activity === 'rad' ? 'trekking' : 'hiking-beta';
    const bearing = ((seed ?? Math.floor(Math.random() * 360)) % 360) * (Math.PI / 180);

    // Kreis mit Umfang ≈ Zieldistanz, Start liegt AUF dem Kreis
    const rKm = dist / (2 * Math.PI);
    const latKm = 110.574;
    const lonKm = 111.32 * Math.cos((lat * Math.PI) / 180);
    const cLat = lat + (rKm / latKm) * Math.cos(bearing);
    const cLon = lon + (rKm / lonKm) * Math.sin(bearing);
    const points: [number, number][] = [[lon, lat]];
    for (let i = 1; i < 4; i++) {
      const phi = bearing + Math.PI + (i * 2 * Math.PI) / 4;
      points.push([
        cLon + (rKm / lonKm) * Math.sin(phi),
        cLat + (rKm / latKm) * Math.cos(phi),
      ]);
    }
    points.push([lon, lat]);

    const lonlats = points.map((p) => `${p[0].toFixed(6)},${p[1].toFixed(6)}`).join('|');
    const url = `https://brouter.de/brouter?lonlats=${lonlats}&profile=${profile}&alternativeidx=0&format=geojson`;
    const res = await fetch(url, {
      headers: { 'User-Agent': ClientAppService.OSM_UA },
      signal: AbortSignal.timeout(30000),
    });
    if (!res.ok) throw new Error(`Routing fehlgeschlagen (${res.status})`);
    const geo = await res.json();
    const feature = geo?.features?.[0];
    const coords: number[][] = feature?.geometry?.coordinates ?? [];
    if (coords.length < 2) throw new Error('Keine Route gefunden');

    const props = feature.properties ?? {};
    const lengthM = parseFloat(props['track-length'] ?? '0') || 0;
    const ascend = parseInt(props['filtered ascend'] ?? '0', 10) || 0;

    // Geordnete Route → ein Segment; auf ≤2000 Punkte ausdünnen
    const stride = Math.max(1, Math.ceil(coords.length / 2000));
    const segment = coords
      .filter((_, i) => i % stride === 0 || i === coords.length - 1)
      .map((c) => ({ lat: c[1], lon: c[0], ele: c[2] ?? null }));

    const distOut = lengthM / 1000;
    return {
      id: `rt-${Date.now()}`,
      name: `Rundtour · ${distOut.toFixed(1)} km`,
      activity: activity === 'rad' ? 'bicycle' : 'hiking',
      generated: true,
      distanceKm: Math.round(distOut * 10) / 10,
      elevationGain: ascend,
      durationMin: ClientAppService.tourDurationWithClimb(distOut, ascend, profile === 'trekking'),
      difficulty: ClientAppService.tourDifficulty(distOut),
      segments: [segment],
    };
  }

  /** SAC-Formel MIT Höhenmetern: t = max(a,b) + min(a,b)/2. */
  private static tourDurationWithClimb(distKm: number, ascendM: number, bike: boolean): number {
    const horiz = bike ? distKm / 15 : distKm / 4.2;
    const climb = ascendM / (bike ? 600 : 400);
    const hours = Math.max(horiz, climb) + Math.min(horiz, climb) / 2;
    return Math.round(hours * 60);
  }

  /** SAC-Basisformel ohne Höhenmeter (T1; Höhenprofil folgt mit ORS). */
  private static tourDuration(distKm: number, osmRoute: string): number {
    const kmh =
      osmRoute === 'bicycle' ? 15 :
      osmRoute === 'mtb' ? 12 :
      osmRoute === 'running' || osmRoute === 'finnenbahn' ? 8 :
      4.2; // hiking, fitness_trail
    return Math.round((distKm / kmh) * 60);
  }

  private static tourDifficulty(distKm: number): string {
    if (distKm < 8) return 'Leicht';
    if (distKm < 16) return 'Mittel';
    return 'Schwer';
  }

  /** Polar status (stub – Polar integration to be migrated) */
  getPolarStatus(_clientId: number) {
    return { connected: false, connectUrl: null };
  }

  // ── Helpers ──────────────────────────────────────────────────────

  private async getTotalCredits(clientId: number): Promise<number> {
    const rows = await this.creditsRepo.find({ where: { clientId } });
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    return rows.reduce((sum, r) => {
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
