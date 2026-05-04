import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity({ name: 'training_type' })
export class TrainingType {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ nullable: true })
  name_en: string;

  @Column({ nullable: true })
  name_de: string;

  @Column({ default: 0 })
  service: number;

  @Column({ nullable: true })
  duration: number;

  @Column({ default: 1 })
  participants: number;

  @Column({ default: 0 })
  no_avaliability: number;

  @Column({ nullable: true })
  avaliability_from: number;

  @Column({ nullable: true })
  credits_from: number;

  @Column({ default: 0 })
  no_locker: number;

  @Column({ nullable: true })
  abbr: string;

  @Column({ default: 100 })
  sort: number;
}
