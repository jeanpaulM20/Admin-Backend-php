import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

/**
 * Property names are kept in snake_case to match the MySQL column names
 * AND the JSON keys expected by the Flutter apps (Metric.fromJson).
 */
@Entity({ name: 'metric' })
export class Metric {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  client_id: number;

  @Column({ type: 'date' })
  date: string;

  @Column({ type: 'float', nullable: true })
  weight: number;

  @Column({ type: 'float', nullable: true })
  sys: number;

  @Column({ type: 'float', nullable: true })
  dia: number;

  @Column({ type: 'float', nullable: true })
  calm_pulse: number;

  @Column({ type: 'float', nullable: true })
  body_fat_kg: number;

  @Column({ type: 'float', nullable: true })
  body_fat_perc: number;

  @Column({ type: 'float', nullable: true })
  waist_circumference: number;

  @Column({ type: 'float', nullable: true })
  bcm: number;

  @ManyToOne(() => Client, (c) => c.metrics)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
