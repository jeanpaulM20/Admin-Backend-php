import { Entity, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

export type CalendarProvider = 'google' | 'microsoft';

/**
 * Verbindung eines Trainers zu einem externen Kalender.
 *
 * Phase 1 der Kalender-Zusammenführung (s. Konzept):
 *  - microsoft → LESEND: Termine der Klinik werden als Sperrzeit übernommen
 *  - google    → SCHREIBEND: dort entstehen die Sperreinträge, wodurch die
 *    Google-Terminplanung auf der Website diese Zeiten selbst ausblendet
 */
@Entity({ name: 'calendar_connection' })
@Index('uniq_calendar_connection', ['trainerId', 'provider'], { unique: true })
export class CalendarConnection {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'trainer_id' })
  trainerId: number;

  @Column({ type: 'varchar', length: 16 })
  provider: CalendarProvider;

  @Column({ name: 'access_token', type: 'text' })
  accessToken: string;

  /** Ohne Refresh-Token endet der Zugriff nach einer Stunde. */
  @Column({ name: 'refresh_token', type: 'text', nullable: true })
  refreshToken: string | null;

  @Column({ name: 'expires_at', type: 'datetime', nullable: true })
  expiresAt: Date | null;

  /** Konto, das verbunden wurde — nur zur Anzeige. */
  @Column({ name: 'account_email', type: 'varchar', length: 190, nullable: true })
  accountEmail: string | null;

  /** Zielkalender; leer = Standardkalender des Kontos. */
  @Column({ name: 'calendar_id', type: 'varchar', length: 190, nullable: true })
  calendarId: string | null;

  @Column({ name: 'connected_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' })
  connectedAt: Date;

  @Column({ name: 'last_sync_at', type: 'datetime', nullable: true })
  lastSyncAt: Date | null;

  @Column({ name: 'last_sync_error', type: 'varchar', length: 255, nullable: true })
  lastSyncError: string | null;
}
