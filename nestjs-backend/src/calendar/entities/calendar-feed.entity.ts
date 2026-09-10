import { Entity, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

/**
 * Abonnierter Fremdkalender eines Trainers (Phase 2).
 *
 * Anders als `calendar_connection` braucht ein Abo kein Konto beim Anbieter:
 * es genügt die iCal-Adresse, die Google, Outlook, Apple und die gängigen
 * Studio-Systeme ausgeben. Damit lassen sich beliebig viele fremde Kalender
 * einbinden — ein Trainer kann für mehrere Studios arbeiten.
 */
@Entity({ name: 'calendar_feed' })
@Index('idx_calendar_feed_trainer', ['trainerId'])
export class CalendarFeed {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'trainer_id' })
  trainerId: number;

  /** Anzeigename, z.B. „Studio Enge". */
  @Column({ type: 'varchar', length: 120 })
  label: string;

  /**
   * Die iCal-Adresse. Sie ist ein Generalschlüssel zu diesem Kalender —
   * wer sie hat, liest alles. Darum wird sie nie an die App zurückgegeben
   * (nur maskiert) und nie protokolliert.
   */
  @Column({ type: 'text' })
  url: string;

  @Column({ type: 'tinyint', width: 1, default: 1 })
  active: boolean;

  @Column({ name: 'last_fetch_at', type: 'datetime', nullable: true })
  lastFetchAt: Date | null;

  @Column({ name: 'last_error', type: 'varchar', length: 255, nullable: true })
  lastError: string | null;

  /** Zuletzt gefundene Zeiträume — Anhaltspunkt, ob der Feed etwas liefert. */
  @Column({ name: 'event_count', type: 'int', default: 0 })
  eventCount: number;

  @Column({ name: 'created_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' })
  createdAt: Date;
}
