import {
  Entity, PrimaryGeneratedColumn, Column, ManyToMany, OneToMany, OneToOne,
} from 'typeorm';
import { Trainer } from './trainer.entity';
import { Clientaccesstoken } from './client-access-token.entity';
import { Training } from './training.entity';
import { Metric } from './metric.entity';
import { Account } from './account.entity';

@Entity({ name: 'client' })
export class Client {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'name' })
  firstname: string;

  @Column({ name: 'surname' })
  lastname: string;

  @Column({ name: 'e_mail', unique: true })
  email: string;

  @Column({ select: false, nullable: true })
  clientpasscode: string;

  @Column({ nullable: true })
  clientid: string;

  @Column({ default: 1 })
  active: number;

  @Column({ nullable: true })
  phone: string;

  @Column({ nullable: true })
  mobile: string;

  @Column({ name: 'foto', nullable: true })
  picture: string;

  @Column({ nullable: true })
  birthday: string;

  @Column({ nullable: true })
  gender: string;

  @Column({ nullable: true })
  zip: string;

  @Column({ nullable: true })
  domicile: string;

  @Column({ nullable: true })
  qrcode: string;

  @Column({ name: 'qrcode_static', nullable: true })
  qrcodeStatic: string;

  @Column({ name: 'qrcode_valid_to', nullable: true })
  qrcodeValidTo: string;

  @Column({ name: 'door_access', default: 0 })
  doorAccess: number;

  @Column({ name: 'min_heart_rate', nullable: true })
  minHeartRate: number;

  @Column({ name: 'max_heart_rate', nullable: true })
  maxHeartRate: number;

  @ManyToMany(() => Trainer, (t) => t.clients)
  trainers: Trainer[];

  @OneToMany(() => Clientaccesstoken, (t) => t.client)
  accessTokens: Clientaccesstoken[];

  @OneToMany(() => Training, (t) => t.client)
  trainings: Training[];

  @OneToMany(() => Metric, (m) => m.client)
  metrics: Metric[];

  @OneToOne(() => Account, (a) => a.client)
  account: Account;
}
