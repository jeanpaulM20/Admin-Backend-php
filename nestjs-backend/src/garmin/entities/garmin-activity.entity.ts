import { Entity, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

/**
 * Garmin activity data pushed via webhook.
 * One row per activity (workout) pushed by Garmin.
 */
@Entity({ name: 'garmin_activity' })
export class GarminActivity {
  @PrimaryGeneratedColumn()
  id: number;

  @Index()
  @Column({ name: 'client_id' })
  clientId: number;

  /** Garmin's unique activity ID — used for idempotent upsert */
  @Index({ unique: true })
  @Column({ name: 'garmin_activity_id', type: 'bigint' })
  garminActivityId: string;

  /** Garmin user access token (to map webhook → client) */
  @Column({ name: 'garmin_user_token', nullable: true })
  garminUserToken: string;

  @Column({ name: 'activity_type', nullable: true })
  activityType: string;

  @Column({ name: 'activity_name', nullable: true })
  activityName: string;

  /** ISO date-time string of when the activity started */
  @Column({ name: 'start_time', nullable: true })
  startTime: string;

  /** Duration in seconds */
  @Column({ name: 'duration_seconds', type: 'float', nullable: true })
  durationSeconds: number;

  /** Distance in meters */
  @Column({ name: 'distance_meters', type: 'float', nullable: true })
  distanceMeters: number;

  /** Active kilocalories */
  @Column({ name: 'active_kcal', type: 'float', nullable: true })
  activeKcal: number;

  /** Average heart rate in bpm */
  @Column({ name: 'avg_heart_rate', type: 'float', nullable: true })
  avgHeartRate: number;

  /** Max heart rate in bpm */
  @Column({ name: 'max_heart_rate', type: 'float', nullable: true })
  maxHeartRate: number;

  /** Average speed in m/s */
  @Column({ name: 'avg_speed', type: 'float', nullable: true })
  avgSpeed: number;

  /** Steps (if applicable) */
  @Column({ nullable: true })
  steps: number;

  /** Raw JSON payload from Garmin for future use */
  @Column({ name: 'raw_json', type: 'text', nullable: true })
  rawJson: string;

  @Column({ name: 'received_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' })
  receivedAt: Date;
}
