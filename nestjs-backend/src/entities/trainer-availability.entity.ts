import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Trainer } from './trainer.entity';

@Entity({ name: 'trainer_availability' })
export class TrainerAvailability {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'trainer_id' })
  trainerId: number;

  @Column({ name: 'location_id', default: 1 })
  locationId: number = 1;

  @Column({ name: 'training_type_id', default: 1 })
  trainingTypeId: number = 1;

  @Column({ type: 'date' })
  date: string;

  @Column({ name: 'from', type: 'time' })
  from: string;

  @Column({ name: 'to', type: 'time', nullable: true })
  to: string;

  @ManyToOne(() => Trainer, (t) => t.availabilities)
  @JoinColumn({ name: 'trainer_id' })
  trainer: Trainer;
}
