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

    const credits = await this.getTotalCredits(clientId);

    return {
      id: client.id,
      firstname: client.firstname,
      lastname: client.lastname,
      email: client.email,
      phone: client.phone,
      photo: client.picture,
      birthday: client.birthday,
      gender: client.gender,
      credits,
    };
  }

  /** Credits list */
  async getCredits(clientId: number) {
    const credits = await this.creditsRepo.find({ where: { clientId } });
    return credits.map((c) => ({
      id: c.id,
      paid: c.paid,
      attended: c.attended,
      remaining: (c.paid ?? 0) - (c.attended ?? 0),
      startdate: c.startdate,
      expires: c.expires,
    }));
  }

  /** Performance tests */
  async getTests(clientId: number) {
    return this.perfTestRepo.find({
      where: { client_id: clientId },
      order: { date: 'DESC' },
    });
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
