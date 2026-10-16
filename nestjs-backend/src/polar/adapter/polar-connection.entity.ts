import { Entity, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

/** Polar-Verknüpfung je Client — höchstens eine. Token AES-GCM-verschlüsselt. */
@Entity({ name: 'polar_connection' })
export class PolarConnectionRow {
  @PrimaryGeneratedColumn()
  id: number;

  @Index({ unique: true })
  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ name: 'polar_user_id', type: 'varchar', length: 32 })
  polarUserId: string;

  @Column({ name: 'access_token_enc', type: 'text' })
  accessTokenEnc: string;

  @Column({ name: 'expires_at', type: 'datetime', nullable: true })
  expiresAt: Date | null;

  @Column({ name: 'connected_at', type: 'datetime' })
  connectedAt: Date;

  @Column({ name: 'last_sync_at', type: 'datetime', nullable: true })
  lastSyncAt: Date | null;
}
