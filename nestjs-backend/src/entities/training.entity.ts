import {
  Entity, PrimaryGeneratedColumn, Column, ManyToOne, ManyToMany, JoinTable, JoinColumn,
} from 'typeorm';
import { Trainer } from './trainer.entity';
import { Client } from './client.entity';
import { Exerciseset } from './exercise-set.entity';

export enum TrainingStatus {
  BOOKED = 'booked',
  ATTENDED = 'attended',
  CANCELLED = 'cancelled',
  MISSED = 'missed',
}

@Entity({ name: 'training' })
export class Training {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'trainer_id' })
  trainerId: number;

  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ type: 'date' })
  date: string;

  @Column({ type: 'time' })
  starttime: string;

  @Column({ type: 'varchar', default: TrainingStatus.BOOKED })
  status: TrainingStatus;

  @Column({ name: 'cancelled_at', type: 'datetime', nullable: true })
  cancelledAt: Date;

  @Column({ name: 'training_type_id', nullable: true })
  trainingTypeId: number;

  @ManyToOne(() => Trainer, (t) => t.trainings)
  @JoinColumn({ name: 'trainer_id' })
  trainer: Trainer;

  @ManyToOne(() => Client, (c) => c.trainings)
  @JoinColumn({ name: 'client_id' })
  client: Client;

  @ManyToMany(() => Exerciseset)
  @JoinTable({ name: 'training_exerciseset' })
  exercisesets: Exerciseset[];
}
