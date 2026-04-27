import {
  Entity, PrimaryGeneratedColumn, Column, ManyToOne, ManyToMany, JoinTable, JoinColumn,
} from 'typeorm';
import { Client } from './client.entity';
import { Trainer } from './trainer.entity';
import { Exerciseset } from './exercise-set.entity';

@Entity({ name: 'trainingplan' })
export class TrainingPlan {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  name: string;

  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ name: 'trainer_id', nullable: true })
  trainerId: number;

  @Column({ nullable: true, type: 'text' })
  description: string;

  @Column({ name: 'created_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' })
  createdAt: Date;

  @ManyToOne(() => Client)
  @JoinColumn({ name: 'client_id' })
  client: Client;

  @ManyToOne(() => Trainer)
  @JoinColumn({ name: 'trainer_id' })
  trainer: Trainer;

  @ManyToMany(() => Exerciseset)
  @JoinTable({ name: 'trainingplan_exerciseset' })
  exercisesets: Exerciseset[];
}
