import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';
import { Trainer } from './trainer.entity';

@Entity({ name: 'feedback' })
export class Feedback {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ name: 'trainer_id', nullable: true })
  trainerId: number;

  @Column({ name: 'text', type: 'text', nullable: true })
  message: string;

  @Column({ name: 'read_client', default: 0 })
  readClient: number;

  @Column({ name: 'read_trainer', default: 0 })
  readTrainer: number;

  @Column({ name: 'is_circle', default: 0 })
  isCircle: number;

  @Column({ type: 'date', nullable: true })
  date: string;

  @ManyToOne(() => Client)
  @JoinColumn({ name: 'client_id' })
  client: Client;

  @ManyToOne(() => Trainer)
  @JoinColumn({ name: 'trainer_id' })
  trainer: Trainer;
}
