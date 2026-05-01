import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

@Entity({ name: 'performance_test' })
export class PerformanceTest {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'client_id' })
  clientId: number;

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

  @Column({ name: 'trunk_bending', type: 'float', nullable: true })
  trunkBending: number;

  @Column({ type: 'float', nullable: true })
  pushups: number;

  @Column({ name: 'forearm_support', type: 'float', nullable: true })
  forearmSupport: number;

  @Column({ name: 'side_support', type: 'float', nullable: true })
  sideSupport: number;

  @Column({ name: 'squat_on_wall', type: 'float', nullable: true })
  squatOnWall: number;

  // Motorik / Koordination
  @Column({ type: 'float', nullable: true })
  sensomotoric: number;

  @Column({ type: 'float', nullable: true })
  symmetry: number;

  @Column({ type: 'float', nullable: true })
  reaction: number;

  @Column({ name: 'counter_movement_jump', type: 'float', nullable: true })
  counterMovementJump: number;

  @Column({ type: 'float', nullable: true })
  tapping: number;

  // Sprint
  @Column({ name: 'sprint_10', type: 'float', nullable: true })
  sprint10: number;

  @Column({ name: 'sprint_20', type: 'float', nullable: true })
  sprint20: number;

  @Column({ name: 'sprint_30', type: 'float', nullable: true })
  sprint30: number;

  // Legacy column from PHP (may exist in DB)
  @Column({ name: 'straight_thigh_extensors', type: 'float', nullable: true })
  straightThighExtensors: number;

  @ManyToOne(() => Client)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
