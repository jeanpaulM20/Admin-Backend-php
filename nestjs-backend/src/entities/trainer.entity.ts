import {
  Entity, PrimaryGeneratedColumn, Column, ManyToMany, JoinTable, OneToMany,
} from 'typeorm';
import { Client } from './client.entity';
import { Location } from './location.entity';
import { Training } from './training.entity';
import { TrainerAvailability } from './trainer-availability.entity';

@Entity({ name: 'trainer' })
export class Trainer {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  firstname: string;

  @Column()
  lastname: string;

  @Column({ unique: true })
  email: string;

  @Column({ select: false })
  passcode: string;

  @Column({ nullable: true })
  phone: string;

  @Column({ default: 1 })
  active: number;

  @Column({ nullable: true })
  picture: string;

  @ManyToMany(() => Client, (client) => client.trainers)
  @JoinTable({ name: 'trainer_client' })
  clients: Client[];

  @ManyToMany(() => Location)
  @JoinTable({ name: 'trainer_location' })
  locations: Location[];

  @OneToMany(() => Training, (t) => t.trainer)
  trainings: Training[];

  @OneToMany(() => TrainerAvailability, (a) => a.trainer)
  availabilities: TrainerAvailability[];
}
