import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Trainer } from './trainer.entity';

@Entity({ name: 'trainer_availability' })
export class TrainerAvailability {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'trainer_id' })
  trainerId: number;

  @Column()
  weekday: number;

  @Column({ type: 'time' })
  starttime: string;

  @Column({ type: 'time' })
  endtime: string;

  @ManyToOne(() => Trainer, (t) => t.availabilities)
  @JoinColumn({ name: 'trainer_id' })
  trainer: Trainer;
}
