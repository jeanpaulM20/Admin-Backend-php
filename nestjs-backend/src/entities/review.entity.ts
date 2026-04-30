import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn } from 'typeorm';
import { Training } from './training.entity';
import { Reviewheartratetimeseries } from './review-heartrate-timeseries.entity';

@Entity({ name: 'review' })
export class Review {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'training_id' })
  trainingId: number;

  @Column({ type: 'int', nullable: true })
  rating: number;

  @Column({ nullable: true, type: 'text' })
  comment: string;

  @Column({ name: 'avg_heart_rate', type: 'int', nullable: true })
  avgHeartRate: number;

  @Column({ name: 'max_heart_rate', type: 'int', nullable: true })
  maxHeartRate: number;

  @Column({ name: 'calories_burned', type: 'int', nullable: true })
  caloriesBurned: number;

  @Column({ name: 'created_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' })
  createdAt: Date;

  @ManyToOne(() => Training)
  @JoinColumn({ name: 'training_id' })
  training: Training;

  @OneToMany(() => Reviewheartratetimeseries, (ts) => ts.review)
  heartRateTimeseries: Reviewheartratetimeseries[];
}
