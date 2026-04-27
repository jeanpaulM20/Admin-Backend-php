import { Entity, PrimaryGeneratedColumn, Column, OneToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

@Entity({ name: 'account' })
export class Account {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'client_id', unique: true })
  clientId: number;

  @Column({ nullable: true })
  status: string;

  @Column({ name: 'date_of_joining', nullable: true })
  dateOfJoining: string;

  @Column({ nullable: true })
  device: string;

  @Column({ name: 'interval_distance', nullable: true })
  intervalDistance: number;

  @Column({ name: 'interval_repeats', nullable: true })
  intervalRepeats: number;

  @Column({ name: 'interval_zone', nullable: true })
  intervalZone: string;

  @Column({ name: 'running_zone', nullable: true })
  runningZone: string;

  @OneToOne(() => Client, (c) => c.account)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
