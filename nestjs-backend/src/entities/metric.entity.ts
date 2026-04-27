import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

@Entity({ name: 'metric' })
export class Metric {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ type: 'float', nullable: true })
  weight: number;

  @Column({ type: 'float', nullable: true })
  height: number;

  @Column({ name: 'body_fat', type: 'float', nullable: true })
  bodyFat: number;

  @Column({ name: 'muscle_mass', type: 'float', nullable: true })
  muscleMass: number;

  @Column({ type: 'date', nullable: true })
  date: string;

  @Column({ name: 'created_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' })
  createdAt: Date;

  @ManyToOne(() => Client, (c) => c.metrics)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
