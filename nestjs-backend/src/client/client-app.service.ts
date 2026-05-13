import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThanOrEqual, In } from 'typeorm';
import { Client } from '../entities/client.entity';
import { Training, TrainingStatus } from '../entities/training.entity';
import { TrainerAvailability } from '../entities/trainer-availability.entity';
import { Trainer } from '../entities/trainer.entity';
import { ClientCredits, TrainingType, PerformanceTest, File as ClientFile } from '../entities/remaining.entities';
import { Metric } from '../entities/metric.entity';
import { Location } from '../entities/location.entity';
import { ReviewService } from '../review/review.service';

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
    private readonly reviewService: ReviewService,
  ) {}

  /** Dashboard: credits + upcoming appointments */
  async getStartData(clientId: number) {
    const today = new Date().toISOString().slice(0, 10);

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
      firstname: client?.firstname ?? '',
      lastname: client?.lastname ?? '',
      credits,
      appointments: trainings.map((t) => this.mapTraining(t)),
    };
  }

  /** Calendar: trainers, types, availability, appointments */
  async getCalendarData(clientId: number) {
    const today = new Date().toISOString().slice(0, 10);

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
        firstname: t.firstname,
        lastname: t.lastname,
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
      locations: locations.map((l) => ({ id: l.id, name: l.name, address: l.address })),
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
      firstname: client.firstname,
      lastname: client.lastname,
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
    const BUFFER_MINUTES = 30; // Buffer between trainings at different locations

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
    const today = new Date().toISOString().slice(0, 10);
    if (date < today) {
      throw new BadRequestException(
        'Buchungen in der Vergangenheit sind nicht möglich.',
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

    // ── 6. No trainer conflict (with location buffer) ─────────────
    const trainerTrainings = await this.trainingRepo.find({
      where: {
        trainerId,
        date,
        status: In([TrainingStatus.BOOKED, TrainingStatus.ATTENDED]),
      },
    });

    for (const t of trainerTrainings) {
      const [eH, eM] = (t.starttime || '00:00').split(':').map(Number);
      const existStart = eH * 60 + eM;
      const existEnd = existStart + (t.duration || DURATION);

      // Buffer: 30 min if different location, 0 if same
      const sameLocation =
        locationId != null &&
        t.locationId != null &&
        Number(t.locationId) === locationId;
      const buffer = sameLocation ? 0 : BUFFER_MINUTES;

      if (reqStart < existEnd + buffer && existStart < reqEnd + buffer) {
        if (buffer > 0) {
          throw new BadRequestException(
            'Trainer hat einen Termin an einem anderen Standort. ' +
              '30 Minuten Pufferzeit zwischen verschiedenen Standorten erforderlich.',
          );
        }
        throw new BadRequestException(
          'Trainer ist zu dieser Zeit bereits gebucht.',
        );
      }
    }

    // ── 7. Check client has available credits ─────────────────────
    const creditPacks = await this.creditsRepo.find({
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
      await this.creditsRepo.save(pack);
      usedPackId = pack.id;
      creditDeducted = true;
      break;
    }

    if (!creditDeducted) {
      throw new BadRequestException(
        'Keine verfügbaren Credits. Bitte neue Credits kaufen.',
      );
    }

    // ── 8. Create training ────────────────────────────────────────
    const training = this.trainingRepo.create({
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
    const saved = await this.trainingRepo.save(training) as Training;

    // Load relations for full response
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

    // Refund credit if one was charged
    if (training.creditsCharged && training.creditsCharged > 0) {
      // Try to refund to the exact pack that was charged
      if (training.creditPackId) {
        const originalPack = await this.creditsRepo.findOne({
          where: { id: training.creditPackId },
        });
        if (originalPack && (originalPack.attended ?? 0) > 0) {
          originalPack.attended = (originalPack.attended ?? 0) - 1;
          await this.creditsRepo.save(originalPack);
        }
      } else {
        // Fallback for older bookings without creditPackId
        const creditPacks = await this.creditsRepo.find({
          where: { clientId },
          order: { expires: 'ASC' },
        });
        for (const pack of creditPacks) {
          if ((pack.attended ?? 0) > 0) {
            pack.attended = (pack.attended ?? 0) - 1;
            await this.creditsRepo.save(pack);
            break;
          }
        }
      }
    }

    training.status = TrainingStatus.CANCELLED;
    training.cancelledAt = new Date().toISOString();
    training.cancelledByClientId = clientId;
    training.creditsCharged = 0;
    await this.trainingRepo.save(training);
    return { success: true };
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
            return `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
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
      notes: t.text,
      trainer: t.trainer
        ? {
            id: t.trainer.id,
            firstname: t.trainer.firstname,
            lastname: t.trainer.lastname,
            picture: t.trainer.picture,
          }
        : undefined,
    };
  }
}
