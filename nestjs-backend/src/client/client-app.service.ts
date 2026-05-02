import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThanOrEqual, In } from 'typeorm';
import { Client } from '../entities/client.entity';
import { Training, TrainingStatus } from '../entities/training.entity';
import { TrainerAvailability } from '../entities/trainer-availability.entity';
import { Trainer } from '../entities/trainer.entity';
import { ClientCredits, TrainingType, PerformanceTest, File as ClientFile } from '../entities/remaining.entities';
import { Location } from '../entities/location.entity';

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
        relations: ['trainer'],
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

    const [trainingTypes, availability, trainings, locations] = await Promise.all([
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
        where: {
          clientId,
          date: MoreThanOrEqual(today),
        },
        relations: ['trainer'],
        order: { date: 'ASC', starttime: 'ASC' },
      }),
      this.locationRepo.find({ where: { active: 1 } }),
    ]);

    return {
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
    const totalCredits = creditRows.reduce(
      (sum, r) => sum + ((r.paid ?? 0) - (r.attended ?? 0)),
      0,
    );

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

  /** Book a training appointment */
  async bookAppointment(clientId: number, body: any) {
    const training = this.trainingRepo.create({
      clientId,
      trainerId: body.trainer_id ?? body.trainerId,
      trainingTypeId: body.training_type_id ?? body.trainingTypeId,
      locationId: body.location_id ?? body.locationId ?? 1,
      date: body.date,
      starttime: body.starttime ?? body.time_from ?? body.from,
      duration: body.duration ?? 60,
      status: TrainingStatus.BOOKED,
    });
    const saved = await this.trainingRepo.save(training);
    return this.mapTraining(saved);
  }

  /** Cancel appointment */
  async cancelAppointment(clientId: number, appointmentId: number) {
    const training = await this.trainingRepo.findOne({
      where: { id: appointmentId, clientId },
    });
    if (!training) throw new NotFoundException('Training not found');

    training.status = TrainingStatus.CANCELLED;
    training.cancelledAt = new Date().toISOString();
    training.cancelledByClientId = clientId;
    await this.trainingRepo.save(training);
    return { success: true };
  }

  /** Client files */
  async getFiles(clientId: number) {
    const files = await this.fileRepo.find({
      where: { clientId },
      order: { date: 'DESC' },
    });
    return files.map((f) => ({
      id: f.id,
      name: f.name,
      file: f.file,
      date: f.date,
    }));
  }

  /** Polar status (stub – Polar integration to be migrated) */
  getPolarStatus(_clientId: number) {
    return { connected: false, connectUrl: null };
  }

  // ── Helpers ──────────────────────────────────────────────────────

  private async getTotalCredits(clientId: number): Promise<number> {
    const rows = await this.creditsRepo.find({ where: { clientId } });
    return rows.reduce((sum, r) => sum + ((r.paid ?? 0) - (r.attended ?? 0)), 0);
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
      location_id: t.locationId,
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
