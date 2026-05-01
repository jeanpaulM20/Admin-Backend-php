import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

/**
 * Property names are kept in snake_case to match the MySQL column names
 * AND the JSON keys expected by the Flutter trainer-app (Performance.fromJson).
 *
 * All measurement columns are NOT NULL in the production DB (no default),
 * so we use TypeScript property initialisers (= 0) so that TypeORM always
 * includes them in INSERT statements.
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
  @Column({ type: 'float' })
  points: number = 0;

  @Column({ type: 'float' })
  hamstrings: number = 0;

  @Column({ type: 'float' })
  calfs: number = 0;

  @Column({ type: 'float' })
  adductors: number = 0;

  // Kraftmessungen
  @Column({ type: 'float' })
  pullups: number = 0;

  @Column({ type: 'float' })
  trunk_bending: number = 0;

  @Column({ type: 'float' })
  pushups: number = 0;

  @Column({ type: 'float' })
  forearm_support: number = 0;

  @Column({ type: 'float' })
  side_support: number = 0;

  @Column({ type: 'float' })
  squat_on_wall: number = 0;

  // Motorik / Koordination
  @Column({ type: 'float' })
  sensomotoric: number = 0;

  @Column({ type: 'float' })
  symmetry: number = 0;

  @Column({ type: 'float' })
  reaction: number = 0;

  @Column({ type: 'float' })
  counter_movement_jump: number = 0;

  @Column({ type: 'float' })
  tapping: number = 0;

  // Sprint
  @Column({ type: 'float' })
  sprint_10: number = 0;

  @Column({ type: 'float' })
  sprint_20: number = 0;

  @Column({ type: 'float' })
  sprint_30: number = 0;

  // Legacy column from PHP
  @Column({ type: 'float' })
  straight_thigh_extensors: number = 0;

  @ManyToOne(() => Client)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
