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

  @Column({ name: 'name' })
  firstname: string;

  @Column({ name: 'surname' })
  lastname: string;

  @Column({ name: 'e_mail', unique: true })
  email: string;

  @Column({ nullable: true })
  phone: string;

  @Column({ nullable: true })
  mobile: string;

  @Column({ name: 'foto', nullable: true })
  picture: string;

  @Column({ nullable: true })
  color: string;

  @Column({ nullable: true })
  position: string;

  @Column({ nullable: true })
  qualification: string;

  @Column({ default: 1 })
  active: number;

  @Column({ default: 0 })
  published: number;

  @Column({ select: false })
  passcode: string;

  @Column({ nullable: true })
  qrcode: string;

  @Column({ name: 'qrcode_valid_to', nullable: true })
  qrcodeValidTo: string;

  @ManyToMany(() => Client, (client) => client.trainers)
  @JoinTable({
    name: 'trainer_client',
    joinColumn: { name: 'trainer_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'client_id', referencedColumnName: 'id' },
  })
  clients: Client[];

  @ManyToMany(() => Location)
  @JoinTable({
    name: 'trainer_location',
    joinColumn: { name: 'trainer_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'location_id', referencedColumnName: 'id' },
  })
  locations: Location[];

  @OneToMany(() => Training, (t) => t.trainer)
  trainings: Training[];

  @OneToMany(() => TrainerAvailability, (a) => a.trainer)
  availabilities: TrainerAvailability[];
}
