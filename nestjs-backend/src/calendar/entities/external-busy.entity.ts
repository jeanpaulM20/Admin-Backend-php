import { Entity, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

/**
 * Ein aus einem Fremdkalender übernommener belegter Zeitraum.
 *
 * Bewusst ohne Betreff, Teilnehmer oder Notiz: übernommen wird nur, DASS die
 * Zeit belegt ist. Damit stehen keine Kundendaten fremder Studios in dieser
 * Datenbank.
 *
 * Zeiten liegen in UTC — die Quelle kann in jeder Zone senden, und nur so
 * lassen sich Termine über die Zeitumstellung hinweg zuverlässig vergleichen.
 */
@Entity({ name: 'external_busy' })
@Index('idx_external_busy_trainer', ['trainerId', 'startsAt'])
export class ExternalBusy {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'trainer_id' })
  trainerId: number;

  @Column({ name: 'feed_id' })
  feedId: number;

  /** UID des Termins beim Anbieter — für Wiedererkennung beim Abgleich. */
  @Column({ type: 'varchar', length: 190 })
  uid: string;

  @Column({ name: 'starts_at', type: 'datetime' })
  startsAt: Date;

  @Column({ name: 'ends_at', type: 'datetime' })
  endsAt: Date;

  @Column({ name: 'all_day', type: 'tinyint', width: 1, default: 0 })
  allDay: boolean;
}
