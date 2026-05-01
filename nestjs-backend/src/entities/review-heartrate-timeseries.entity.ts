import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Review } from './review.entity';

/**
 * Individual heart-rate data points for a Review.
 * Snake_case properties match MySQL columns AND Flutter fromJson keys.
 */
@Entity({ name: 'review_heart_rate_timeseries' })
export class ReviewHeartRateTimeseries {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'datetime', nullable: true })
  timestamp: string;

  @Column({ type: 'float', nullable: true })
  value: number;

  @Column({ default: 0 })
  sort: number;

  @Column()
  review_id: number;

  @ManyToOne(() => Review, (r) => r.timeseries)
  @JoinColumn({ name: 'review_id' })
  review: Review;
}
