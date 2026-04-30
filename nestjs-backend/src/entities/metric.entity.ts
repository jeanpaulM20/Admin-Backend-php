import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

@Entity({ name: 'metric' })
export class Metric {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ type: 'date' })
  date: string;

  @Column({ type: 'float', nullable: true })
  weight: number;

  @Column({ type: 'float', nullable: true })
  sys: number;

  @Column({ type: 'float', nullable: true })
  dia: number;

  @Column({ name: 'calm_pulse', type: 'float', nullable: true })
  calmPulse: number;

  @Column({ name: 'body_fat_kg', type: 'float', nullable: true })
  bodyFatKg: number;

  @Column({ name: 'body_fat_perc', type: 'float', nullable: true })
  bodyFatPerc: number;

  @Column({ name: 'waist_circumference', type: 'float', nullable: true })
  waistCircumference: number;

  @Column({ type: 'float', nullable: true })
  bcm: number;

  @ManyToOne(() => Client, (c) => c.metrics)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
