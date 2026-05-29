import { Entity, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

/**
 * Garmin daily health summary pushed via webhook.
 * One row per client per calendar day.
 */
@Entity({ name: 'garmin_daily_summary' })
@Index(['clientId', 'calendarDate'], { unique: true })
export class GarminDailySummary {
  @PrimaryGeneratedColumn()
  id: number;

  @Index()
  @Column({ name: 'client_id' })
  clientId: number;

  /** YYYY-MM-DD */
  @Column({ name: 'calendar_date' })
  calendarDate: string;

  @Column({ nullable: true })
  steps: number;

  /** Total active kilocalories */
  @Column({ name: 'active_kcal', type: 'float', nullable: true })
  activeKcal: number;

  /** Resting heart rate in bpm */
  @Column({ name: 'resting_heart_rate', type: 'float', nullable: true })
  restingHeartRate: number;

  /** Max heart rate during the day */
  @Column({ name: 'max_heart_rate', type: 'float', nullable: true })
  maxHeartRate: number;

  /** Average stress level (1-100) */
  @Column({ name: 'avg_stress', type: 'float', nullable: true })
  avgStress: number;

  /** Body Battery max value (0-100) */
  @Column({ name: 'body_battery_max', nullable: true })
  bodyBatteryMax: number;

  /** Body Battery min value (0-100) */
  @Column({ name: 'body_battery_min', nullable: true })
  bodyBatteryMin: number;

  /** Sleep duration in seconds */
  @Column({ name: 'sleep_duration_seconds', nullable: true })
  sleepDurationSeconds: number;

  /** Sleep score (0-100) */
  @Column({ name: 'sleep_score', nullable: true })
  sleepScore: number;

  /** SpO2 average */
  @Column({ name: 'spo2_avg', type: 'float', nullable: true })
  spo2Avg: number;

  /** Respiration average (breaths/min) */
  @Column({ name: 'respiration_avg', type: 'float', nullable: true })
  respirationAvg: number;

  /** Floors climbed */
  @Column({ name: 'floors_climbed', nullable: true })
  floorsClimbed: number;

  /** Intensity minutes (vigorous + moderate) */
  @Column({ name: 'intensity_minutes', nullable: true })
  intensityMinutes: number;

  /** Raw JSON for future use */
  @Column({ name: 'raw_json', type: 'text', nullable: true })
  rawJson: string;

  @Column({ name: 'received_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' })
  receivedAt: Date;
}
