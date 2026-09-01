import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Training } from '../entities/training.entity';
import * as ics from 'ics';

// ─────────────────────────────────────────────────────────────────────────────
// iCalendar service — generates RFC 5545 .ics files for training appointments
// Compatible with Google Calendar, Apple Calendar, Outlook
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class IcalService {
  constructor(
    @InjectRepository(Training)
    private readonly trainingRepo: Repository<Training>,
  ) {}

  /**
   * Generate a .ics file for a single training.
   * Returns the raw iCalendar string.
   */
  /**
   * @param owner Prüfsatz: nur ein am Termin Beteiligter (Kunde oder Trainer)
   *   darf die Datei mit Name, Ort und E-Mail beziehen. Termin-IDs sind
   *   fortlaufend und damit ratbar — ohne diese Prüfung liesse sich jeder
   *   fremde Termin abgreifen.
   */
  async generateIcal(
    trainingId: number,
    owner?: { clientId?: number; trainerId?: number },
  ): Promise<string> {
    const training = await this.trainingRepo.findOne({
      where: { id: trainingId },
      relations: ['trainer', 'client', 'trainingType', 'location', 'trainingPlan'],
    });

    if (!training) {
      throw new NotFoundException(`Training ${trainingId} not found`);
    }

    if (owner) {
      const isOwner =
        (owner.clientId != null && training.clientId === owner.clientId) ||
        (owner.trainerId != null && training.trainerId === owner.trainerId);
      if (!isOwner) {
        throw new ForbiddenException('Kein Zugriff auf diesen Termin.');
      }
    }

    const event = this.buildEvent(training);
    const { error, value } = ics.createEvent(event);

    if (error) {
      throw new Error(`Failed to generate iCal: ${error.message}`);
    }

    return value!;
  }

  /**
   * Generate a .ics file with multiple trainings (e.g. all upcoming for a trainer).
   */
  async generateMultipleIcal(trainingIds: number[]): Promise<string> {
    const trainings = await this.trainingRepo.find({
      where: trainingIds.map((id) => ({ id })),
      relations: ['trainer', 'client', 'trainingType', 'location'],
    });

    if (trainings.length === 0) {
      throw new NotFoundException('No trainings found');
    }

    const events = trainings.map((t) => this.buildEvent(t));
    const { error, value } = ics.createEvents(events);

    if (error) {
      throw new Error(`Failed to generate iCal: ${error.message}`);
    }

    return value!;
  }

  private buildEvent(training: Training): ics.EventAttributes {
    // Parse date and time
    const date = training.date; // 'YYYY-MM-DD'
    const starttime = training.starttime; // 'HH:mm:ss'

    const [year, month, day] = date.split('-').map(Number);
    const [hour, minute] = starttime.split(':').map(Number);

    // Duration in minutes
    const durationMin =
      training.trainingType?.duration ?? training.duration ?? 60;

    // Build summary
    const typeName =
      training.trainingType?.name_de ??
      training.trainingType?.name_en ??
      'Training';
    const clientName = training.client
      ? `${training.client.firstname} ${training.client.lastname}`.trim()
      : null;
    const summary = clientName
      ? `${typeName} — ${clientName}`
      : typeName;

    // Status mapping (RFC 5545)
    const statusMap: Record<string, ics.EventStatus> = {
      booked: 'CONFIRMED',
      attended: 'CONFIRMED',
      missed: 'CANCELLED',
      cancelled: 'CANCELLED',
    };

    const planName = training.trainingPlan?.name;
    const descriptionParts: string[] = [];
    if (planName) descriptionParts.push(`Trainingsplan: ${planName}`);
    if (training.text) descriptionParts.push(training.text);

    const event: ics.EventAttributes = {
      uid: `training-${training.id}@sihltraining`,
      start: [year, month, day, hour, minute],
      startInputType: 'local',
      startOutputType: 'local',
      duration: { minutes: durationMin },
      title: planName ? `${summary} — ${planName}` : summary,
      description: descriptionParts.length > 0 ? descriptionParts.join('\n\n') : undefined,
      status: statusMap[training.status] ?? 'CONFIRMED',
      busyStatus: 'BUSY',
      categories: ['HEALTH', 'FITNESS'],
      productId: 'sihltraining/ics',
      calName: 'Sihl Training',
      alarms: [
        {
          action: 'display',
          description: 'Training in 15 Minuten',
          trigger: { minutes: 15, before: true },
        },
      ],
    };

    // Organizer (trainer)
    if (training.trainer?.email) {
      event.organizer = {
        name: `${training.trainer.firstname} ${training.trainer.lastname}`.trim(),
        email: training.trainer.email,
      };
    }

    // Attendee (client)
    if (training.client?.email) {
      event.attendees = [
        {
          name: clientName || undefined,
          email: training.client.email,
          rsvp: true,
          partstat: 'ACCEPTED',
          role: 'REQ-PARTICIPANT',
        },
      ];
    }

    // Location
    if (training.location?.name) {
      event.location = training.location.address
        ? `${training.location.name}, ${training.location.address}`
        : training.location.name;
    }

    return event;
  }
}
