import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, CreateDateColumn, UpdateDateColumn } from 'typeorm';
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

  /** Display name of the plan (stored in DB column "new_pro") */
  @Column({ name: 'new_pro', nullable: true })
  name: string;

  @Column({ nullable: true })
  type: string;

  /** 'draft' = trainer still editing; 'published' = released to the client */
  @Column({ default: 'draft' })
  status: string;

  /** Set on first publish — anchors the client's free-access window */
  @Column({ name: 'published_at', type: 'datetime', nullable: true })
  publishedAt: Date;

  /** Auto-set on first save */
  @CreateDateColumn({ name: 'created_at', type: 'datetime', nullable: true })
  createdAt: Date;

  /** Auto-updated on every save — used for sorting newest first */
  @UpdateDateColumn({ name: 'updated_at', type: 'datetime', nullable: true })
  updatedAt: Date;

  @ManyToOne(() => Client)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
