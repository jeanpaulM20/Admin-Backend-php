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

  /** Online-coaching subscription status for the paywall gate. */
  async getSubscriptionStatus(clientId: number) {
    const sub = await this.entitlementService.getActiveSubscription(clientId);
    if (!sub) return { active: false };
    return {
      active: true,
      tier: sub.tier,
      validFrom: sub.validFrom,
      validTo: sub.validTo,
    };
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

      // 3. Calculate dates
      const now = new Date();
      const startDate = now.toISOString().split('T')[0];
      const expiresDate = new Date(now);
      expiresDate.setMonth(expiresDate.getMonth() + (durationMonths ?? 1));
      const expiresStr = expiresDate.toISOString().split('T')[0];

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

        // Get training date from the relation
        const trainingDate = review.training?.date ?? '';

        return {
          id: review.id,
          date: trainingDate,
          trainingType: review.training_type ?? review.type ?? '',
          duration: review.duration,
          hrMax,
          hrAvg,
          hrr: null, // Heart Rate Recovery – requires specific protocol data
          hrv: null, // Heart Rate Variability – requires R-R interval data
          chart,
        };
      }),
    );

    return results;
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
