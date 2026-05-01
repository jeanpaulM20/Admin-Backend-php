import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

/**
 * Property names are kept in snake_case to match the MySQL column names
 * AND the JSON keys expected by the Flutter trainer-app (Performance.fromJson).
 */
@Entity({ name: 'performance_test' })
export class PerformanceTest {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  client_id: number;

  @Column({ type: 'datetime', nullable: true })
  date: string;

  // Stabilitaetsmessungen
  @Column({ type: 'float', nullable: true })
  points: number;

  @Column({ type: 'float', nullable: true })
  hamstrings: number;

  @Column({ type: 'float', nullable: true })
  calfs: number;

  @Column({ type: 'float', nullable: true })
  adductors: number;

  // Kraftmessungen
  @Column({ type: 'float', nullable: true })
  pullups: number;

  @Column({ type: 'float', nullable: true })
  trunk_bending: number;

  @Column({ type: 'float', nullable: true })
  pushups: number;

  @Column({ type: 'float', nullable: true })
  forearm_support: number;

  @Column({ type: 'float', nullable: true })
  side_support: number;

  @Column({ type: 'float', nullable: true })
  squat_on_wall: number;

  // Motorik / Koordination
  @Column({ type: 'float', nullable: true })
  sensomotoric: number;

  @Column({ type: 'float', nullable: true })
  symmetry: number;

  @Column({ type: 'float', nullable: true })
  reaction: number;

  @Column({ type: 'float', nullable: true })
  counter_movement_jump: number;

  @Column({ type: 'float', nullable: true })
  tapping: number;

  // Sprint
  @Column({ type: 'float', nullable: true })
  sprint_10: number;

  @Column({ type: 'float', nullable: true })
  sprint_20: number;

  @Column({ type: 'float', nullable: true })
  sprint_30: number;

  // Legacy column from PHP
  @Column({ type: 'float', nullable: true })
  straight_thigh_extensors: number;

  @ManyToOne(() => Client)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
