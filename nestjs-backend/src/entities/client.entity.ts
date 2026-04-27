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

  @Column()
  firstname: string;

  @Column()
  lastname: string;

  @Column({ unique: true })
  email: string;

  @Column({ select: false, nullable: true })
  clientpasscode: string;

  @Column({ default: 1 })
  active: number;

  @Column({ nullable: true })
  phone: string;

  @Column({ nullable: true })
  picture: string;

  @Column({ nullable: true })
  qrcode: string;

  @Column({ name: 'qrcode_static', nullable: true })
  qrcodeStatic: string;

  @Column({ name: 'door_access', default: 0 })
  doorAccess: number;

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
