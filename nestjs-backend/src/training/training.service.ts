import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, MoreThanOrEqual, LessThanOrEqual, In } from 'typeorm';
import { Training, TrainingStatus } from '../entities/training.entity';
import { Location } from '../entities/location.entity';
import { PushService } from '../push/push.service';

@Injectable()
export class TrainingService {
  private readonly logger = new Logger(TrainingService.name);

  constructor(
    @InjectRepository(Training)
    private readonly repo: Repository<Training>,
    @InjectRepository(Location)
    private readonly locationRepo: Repository<Location>,
    private readonly pushService: PushService,
  ) {}

  private formatTraining(t: Training) {
    const typeName = t.trainingType?.name_de ?? t.trainingType?.name_en ?? null;
    return {
      ...t,
      training_type: typeName,
      type_name: typeName,
      type_abbr: t.trainingType?.abbr ?? null,
      location_name: t.location?.name ?? null,
      training_plan_name: t.trainingPlan?.name ?? null,
    };
  }

  async findAll(clientId?: number, trainerId?: number, dateFrom?: string, dateTo?: string) {
    const where: any = {};
    if (clientId) where.clientId = clientId;
    if (trainerId) where.trainerId = trainerId;

    if (dateFrom && dateTo) {
      where.date = Between(dateFrom, dateTo);
    } else if (dateFrom) {
      where.date = MoreThanOrEqual(dateFrom);
    } else if (dateTo) {
      where.date = LessThanOrEqual(dateTo);
    }

    const rows = await this.repo.find({
      where,
      relations: ['trainer', 'client', 'trainingType', 'location', 'trainingPlan'],
      order: { date: 'ASC', starttime: 'ASC' },
    });
    return rows.map((t) => this.formatTraining(t));
  }

  async findOne(id: number, includeExercises = false) {
    const relations = ['trainer', 'client', 'trainingType', 'location', 'trainingPlan'];
    if (includeExercises) relations.push('exercisesets');
    const training = await this.repo.findOne({
      where: { id },
      relations,
    });
    if (!training) throw new NotFoundException(`Training ${id} not found`);
    return this.formatTraining(training);
  }

  create(data: Partial<Training>) {
    return this.repo.save(this.repo.create(data));
  }

  // ── Validated booking by trainer ────────────────────────────────────────

  async createByTrainer(trainerId: number, body: any): Promise<any> {
    const DURATION = 60;

    // ── 1. Validate input ────────────────────────────────────────
    const clientId = Number(body.client_id ?? body.clientId);
    const trainingTypeId = Number(body.training_type_id ?? body.trainingTypeId) || null;
    const locationId = body.location_id ?? body.locationId
      ? Number(body.location_id ?? body.locationId)
      : null;
    const date: string = body.date;
    const starttime: string = body.starttime ?? body.time_from ?? body.from;
    const duration = Number(body.duration) || DURATION;
    const text: string = body.text || null;
    const trainingPlanId = body.training_plan_id ?? body.trainingPlanId
      ? Number(body.training_plan_id ?? body.trainingPlanId)
      : null;

    if (!clientId || !date || !starttime) {
      throw new BadRequestException('Client, Datum und Startzeit sind erforderlich.');
    }

    // ── 2. Parse time ────────────────────────────────────────────
    const [reqH, reqM] = starttime.split(':').map(Number);
    if (isNaN(reqH) || isNaN(reqM)) {
      throw new BadRequestException('Ungültiges Zeitformat.');
    }
    const reqStart = reqH * 60 + reqM;
    const reqEnd = reqStart + duration;

    // ── 3. No double booking for client ──────────────────────────
    const clientTrainings = await this.repo.find({
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
        throw new BadRequestException('Kunde hat bereits einen Termin zu dieser Zeit.');
      }
    }

    // ── 4. Trainer conflict check ────────────────────────────────
    // Online coaching workouts (plan assignments without location) don't
    // block the trainer's calendar — the client trains independently.
    // Only in-person sessions trigger the trainer-conflict check.
    const isOnlineCoaching = !!trainingPlanId && !locationId;

    if (!isOnlineCoaching) {
      const trainerTrainings = await this.repo.find({
        where: {
          trainerId,
          date,
          status: In([TrainingStatus.BOOKED, TrainingStatus.ATTENDED]),
        },
      });

      const allLocations = await this.locationRepo.find();
      const locationMap = new Map(allLocations.map((l) => [l.id, l]));
      const reqLocation = locationId ? locationMap.get(locationId) : null;
      const reqBuffer = reqLocation?.bufferMinutes ?? 30;

      for (const t of trainerTrainings) {
        // Skip online coaching sessions when checking conflicts
        if (t.trainingPlanId && !t.locationId) continue;

        const [eH, eM] = (t.starttime || '00:00').split(':').map(Number);
        const existStart = eH * 60 + eM;
        const existEnd = existStart + (t.duration || DURATION);

        const sameLocation =
          locationId != null && t.locationId != null && Number(t.locationId) === locationId;
        let buffer = 0;
        if (!sameLocation) {
          const existLocation = t.locationId ? locationMap.get(Number(t.locationId)) : null;
          const existBuffer = existLocation?.bufferMinutes ?? 30;
          buffer = Math.max(reqBuffer, existBuffer);
        }

        if (reqStart < existEnd + buffer && existStart < reqEnd + buffer) {
          if (buffer > 0) {
            throw new BadRequestException(
              `Trainer hat einen Termin an einem anderen Standort. ${buffer} Min. Pufferzeit erforderlich.`,
            );
          }
          throw new BadRequestException('Trainer ist zu dieser Zeit bereits gebucht.');
        }
      }
    }

    // ── 5. Save training ──────────────────────────────────────────
    const training = this.repo.create({
      trainerId,
      clientId,
      trainingTypeId,
      locationId,
      trainingPlanId,
      date,
      starttime,
      duration,
      text,
      status: TrainingStatus.BOOKED,
    } as Partial<Training>);
    let saved: Training;
    try {
      saved = await this.repo.save(training as Training);
    } catch (err: any) {
      throw new BadRequestException(`Training konnte nicht gespeichert werden: ${err.message}`);
    }

    // ── 6. Push notification to client ────────────────────────────
    const formatted = await this.findOne(saved.id);
    const locationName = formatted.location_name || '';
    const typeName = formatted.type_name || 'Training';
    const planName = formatted.training_plan_name || null;

    // Plan assignment = online coaching workout (no location)
    // In-person training = with location
    const notifBody = planName
      ? `${planName} am ${date} um ${starttime} Uhr`
      : `${typeName} am ${date} um ${starttime} Uhr${locationName ? ' — ' + locationName : ''}`;

    this.pushService.sendToClient(clientId, {
      title: planName ? 'Neues Workout geplant' : 'Neuer Termin',
      body: notifBody,
      url: `/api/training/${saved.id}/ical`,
    }).catch((err) => {
      this.logger.warn(`Push notification failed for client ${clientId}: ${err.message}`);
    });

    this.logger.log(`Training created by trainer ${trainerId} for client ${clientId}: ${date} ${starttime}`);
    return formatted;
  }

  // Wrap createByTrainer with error logging to surface real errors
  async createByTrainerSafe(trainerId: number, body: any): Promise<any> {
    try {
      return await this.createByTrainer(trainerId, body);
    } catch (err: any) {
      this.logger.error(
        `createByTrainer FAILED — trainerId=${trainerId} body=${JSON.stringify(body)} err=${err.message} stack=${err.stack?.substring(0, 500)}`,
      );
      throw err;
    }
  }

  // ── CRUD ────────────────────────────────────────────────────────────────

  async update(id: number, data: Partial<Training>) {
    await this.findOne(id);
    await this.repo.update(id, data);
    return this.findOne(id);
  }

  async cancel(id: number) {
    const training = await this.findOne(id);
    if (training.status === TrainingStatus.ATTENDED) {
      throw new BadRequestException('Abgeschlossene Trainings können nicht abgesagt werden');
    }
    if (training.status === TrainingStatus.CANCELLED) {
      throw new BadRequestException('Training ist bereits abgesagt');
    }
    try {
      await this.repo
        .createQueryBuilder()
        .update(Training)
        .set({
          status: TrainingStatus.CANCELLED,
          cancelledAt: new Date().toISOString().slice(0, 19).replace('T', ' '),
        } as any)
        .where('id = :id', { id })
        .execute();
    } catch (err: any) {
      this.logger.error(`Cancel failed for training ${id}: ${err.message}`);
      throw new BadRequestException(`Training konnte nicht abgesagt werden: ${err.message}`);
    }
    return this.findOne(id);
  }

  async remove(id: number) {
    const raw = await this.repo.findOne({
      where: { id },
      relations: ['trainer', 'client', 'trainingType', 'location'],
    });
    if (!raw) throw new NotFoundException(`Training ${id} not found`);
    return this.repo.remove(raw);
  }
}
