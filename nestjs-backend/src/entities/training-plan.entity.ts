import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

@Entity({ name: 'trainingplan' })
export class TrainingPlan {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ name: 'load_duration', nullable: true })
  loadDuration: string;

  @Column({ nullable: true })
  repeat: string;

  @Column({ nullable: true })
  temp: string;

  @Column({ nullable: true })
  rates: string;

  @Column({ nullable: true })
  phase: string;

  @Column({ name: 'personal_week', nullable: true })
  personalWeek: number;

  @Column({ name: 'own_week', nullable: true })
  ownWeek: number;

  @Column({ nullable: true })
  goal: string;

  @Column({ nullable: true, type: 'text' })
  values: string;

  @Column({ name: 'new_pro', nullable: true })
  newPro: string;

  @Column({ nullable: true })
  type: string;

  @ManyToOne(() => Client)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
