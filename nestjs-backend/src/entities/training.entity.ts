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

  @Column({ name: 'type_id', nullable: true })
  trainingTypeId: number;

  @Column({ name: 'location_id', nullable: true })
  locationId: number;

  @Column({ type: 'date' })
  date: string;

  @Column({ type: 'time' })
  starttime: string;

  @Column({ nullable: true })
  duration: number;

  @Column({ nullable: true })
  text: string;

  @Column({ type: 'varchar', default: TrainingStatus.BOOKED })
  status: TrainingStatus;

  @Column({ name: 'cancelled_at', nullable: true })
  cancelledAt: string;

  @Column({ name: 'cancelled_by_client_rel', nullable: true })
  cancelledByClientId: number;

  @Column({ name: 'cancelled_by_trainer_rel', nullable: true })
  cancelledByTrainerId: number;

  @Column({ name: 'credits_charged', nullable: true })
  creditsCharged: number;

  @ManyToOne(() => Trainer, (t) => t.trainings)
  @JoinColumn({ name: 'trainer_id' })
  trainer: Trainer;

  @ManyToOne(() => Client, (c) => c.trainings)
  @JoinColumn({ name: 'client_id' })
  client: Client;

  @ManyToMany(() => Exerciseset)
  @JoinTable({
    name: 'tbl_training_exerciseset',
    joinColumn: { name: 'training_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'exerciseset_id', referencedColumnName: 'id' },
  })
  exercisesets: Exerciseset[];
}
