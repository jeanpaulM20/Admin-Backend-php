import { Entity, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

/**
 * Stores Garmin OAuth 1.0a tokens per client.
 * One client has at most one Garmin connection.
 */
@Entity({ name: 'garmin_connection' })
export class GarminConnection {
  @PrimaryGeneratedColumn()
  id: number;

  @Index({ unique: true })
  @Column({ name: 'client_id' })
  clientId: number;

  /** OAuth 1.0a access token (permanent until user revokes) */
  @Column({ name: 'access_token', type: 'text' })
  accessToken: string;

  /** OAuth 1.0a access token secret */
  @Column({ name: 'access_token_secret', type: 'text' })
  accessTokenSecret: string;

  /** Garmin user ID from the API response */
  @Column({ name: 'garmin_user_id', nullable: true })
  garminUserId: string;

  /** Display name from Garmin profile */
  @Column({ name: 'garmin_display_name', nullable: true })
  garminDisplayName: string;

  @Column({ name: 'connected_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' })
  connectedAt: Date;

  @Column({ name: 'last_sync_at', type: 'datetime', nullable: true })
  lastSyncAt: Date;
}
