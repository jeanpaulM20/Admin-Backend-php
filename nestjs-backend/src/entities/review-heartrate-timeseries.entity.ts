import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Review } from './review.entity';

@Entity({ name: 'review_heart_rate_timeseries' })
export class Reviewheartratetimeseries {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'review_id' })
  reviewId: number;

  @Column({ name: 'heart_rate', type: 'int' })
  heartRate: number;

  @Column({ type: 'datetime' })
  timestamp: Date;

  @ManyToOne(() => Review, (r) => r.heartRateTimeseries)
  @JoinColumn({ name: 'review_id' })
  review: Review;
}
