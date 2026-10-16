import { Entity, PrimaryGeneratedColumn, Column, Index } from 'typeorm';

/**
 * Welche Polar-Trainings schon übernommen wurden. Bewusst ohne
 * Fremdschlüssel auf review: Löscht der Client ein importiertes Training,
 * soll es beim nächsten Sync nicht wieder auftauchen.
 */
@Entity({ name: 'polar_exercise_import' })
@Index('uniq_polar_exercise_import', ['clientId', 'exerciseId'], { unique: true })
export class PolarExerciseImportRow {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ name: 'exercise_id', type: 'varchar', length: 64 })
  exerciseId: string;

  /** null = übersprungen (nicht übernehmbar) */
  @Column({ name: 'review_id', type: 'int', nullable: true })
  reviewId: number | null;

  @Column({ name: 'imported_at', type: 'datetime' })
  importedAt: Date;
}
