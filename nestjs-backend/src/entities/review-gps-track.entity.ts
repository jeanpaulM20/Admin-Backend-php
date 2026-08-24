import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, Index } from 'typeorm';
import { Review } from './review.entity';

/**
 * GPS track points for an app-recorded workout (Phase 2 of the
 * training-tracking concept). One row per filtered location sample.
 */
@Entity({ name: 'review_gps_track' })
export class ReviewGpsTrack {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'datetime', nullable: true })
  timestamp: string;

  @Column({ type: 'double' })
  lat: number;

  @Column({ type: 'double' })
  lon: number;

  @Column({ type: 'float', nullable: true })
  ele: number;

  @Column({ type: 'float', nullable: true })
  accuracy: number;

  @Column({ default: 0 })
  sort: number;

  @Index()
  @Column()
  review_id: number;

  @ManyToOne(() => Review)
  @JoinColumn({ name: 'review_id' })
  review: Review;
}
