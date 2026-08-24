import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn } from 'typeorm';
import { Training } from './training.entity';
import { ReviewHeartRateTimeseries } from './review-heartrate-timeseries.entity';

/**
 * Review = one training recording / workout result.
 * Snake_case properties match MySQL columns AND Flutter fromJson keys.
 */
@Entity({ name: 'review' })
export class Review {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ nullable: true })
  file: string;

  @Column({ type: 'time', nullable: true })
  duration: string;

  @Column({ nullable: true })
  kcal: number;

  @Column({ type: 'float', nullable: true })
  heart_rate: number;

  @Column({ nullable: true })
  exerciseset_id: number;

  @Column({ nullable: true })
  training_id: number;

  /** App-recorded workouts: direct client link (no booked training required) */
  @Column({ nullable: true })
  client_id: number;

  /** Workout start (app recordings; booked trainings use training.date) */
  @Column({ type: 'datetime', nullable: true })
  date: string;

  /** 'app' = recorded in the client app, null/legacy = trainer/polar flows */
  @Column({ nullable: true })
  source: string;

  @Column({ nullable: true })
  training_type: string;

  @Column({ nullable: true })
  type: string;

  @Column({ nullable: true })
  goal: number;

  @Column({ nullable: true })
  goal_metric: string;

  @Column({ nullable: true })
  bonus_goal: number;

  @Column({ nullable: true })
  bonus_goal_metric: string;

  @Column({ nullable: true })
  trainingplan_id: number;

  @Column({ nullable: true })
  result: number;

  @Column({ nullable: true })
  feedback_emoticon: string;

  @Column({ type: 'text', nullable: true })
  feedback_client: string;

  @Column({ type: 'text', nullable: true })
  feedback_trainer: string;

  @Column({ type: 'float', nullable: true })
  speed: number;

  @Column({ type: 'float', nullable: true })
  distance: number;

  /** Kumulierte Höhenmeter (App-Aufzeichnungen, Meter) */
  @Column({ name: 'elevation_gain', nullable: true })
  elevation_gain: number;

  @ManyToOne(() => Training)
  @JoinColumn({ name: 'training_id' })
  training: Training;

  @OneToMany(() => ReviewHeartRateTimeseries, (ts) => ts.review)
  timeseries: ReviewHeartRateTimeseries[];
}
