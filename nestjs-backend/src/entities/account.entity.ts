import { Entity, PrimaryGeneratedColumn, Column, OneToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

@Entity({ name: 'account' })
export class Account {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ name: 'hr_zone1', type: 'int', nullable: true })
  hrZone1: number;

  @Column({ name: 'hr_zone2', type: 'int', nullable: true })
  hrZone2: number;

  @Column({ name: 'hr_zone3', type: 'int', nullable: true })
  hrZone3: number;

  @Column({ name: 'hr_zone4', type: 'int', nullable: true })
  hrZone4: number;

  @Column({ name: 'hr_zone5', type: 'int', nullable: true })
  hrZone5: number;

  @Column({ nullable: true })
  language: string;

  @OneToOne(() => Client, (c) => c.account)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
