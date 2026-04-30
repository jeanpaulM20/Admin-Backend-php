import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

@Entity({ name: 'client_access_token' })
export class Clientaccesstoken {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ unique: true })
  token: string;

  @Column({ nullable: true })
  date: string;

  @Column({ nullable: true })
  sort: number;

  @ManyToOne(() => Client, (c) => c.accessTokens)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
