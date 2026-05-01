import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';
import { Trainer } from './trainer.entity';

/**
 * Feedback / Chat messages between trainer and client.
 * Snake_case properties match MySQL columns AND Flutter fromJson keys.
 */
@Entity({ name: 'feedback' })
export class Feedback {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  client_id: number;

  @Column({ nullable: true })
  trainer_id: number;

  @Column({ type: 'text', nullable: true })
  text: string;

  @Column({ default: 0 })
  read_client: number;

  @Column({ default: 0 })
  read_trainer: number;

  @Column({ default: 0 })
  is_circle: number;

  @ManyToOne(() => Client)
  @JoinColumn({ name: 'client_id' })
  client: Client;

  @ManyToOne(() => Trainer)
  @JoinColumn({ name: 'trainer_id' })
  trainer: Trainer;
}
