import { Injectable, NotFoundException } from '@nestjs/common';
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
  async generateIcal(trainingId: number): Promise<string> {
    const training = await this.trainingRepo.findOne({
      where: { id: trainingId },
      relations: ['trainer', 'client', 'trainingType', 'location'],
    });

    if (!training) {
      throw new NotFoundException(`Training ${trainingId} not found`);
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

    const event: ics.EventAttributes = {
      uid: `training-${training.id}@sihltraining`,
      start: [year, month, day, hour, minute],
      duration: { minutes: durationMin },
      title: summary,
      description: training.text || undefined,
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
