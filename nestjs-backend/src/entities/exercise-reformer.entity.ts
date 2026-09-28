import { Entity, PrimaryColumn, Column, OneToOne, JoinColumn } from 'typeorm';
import { Exercise } from './exercise.entity';
import { decimalToNumber } from './column-transformers';

/**
 * Reformer-Angaben einer Übung — eigene Tabelle, weil keine andere Modalität
 * diese Eigenschaften kennt. Eine Reformer-Übung ist ohne Federspannung nicht
 * definiert: „Footwork mit 4 Federn" und „mit 1 Feder" sind verschiedene Reize.
 * Siehe KONZEPT-PROGRAMM-GENERATOR.md, Abschnitt 4.2.
 */
@Entity({ name: 'exercise_reformer' })
export class ExerciseReformer {
  @PrimaryColumn({ name: 'exercise_id' })
  exerciseId: number;

  /** Anzeige für den Trainer, in den Farben des Studios: „1 rot + 1 blau". */
  @Column({ type: 'varchar', length: 48, nullable: true })
  springs: string | null;

  /** Normierte Last 0–5, damit der Generator „eine Stufe leichter" rechnen kann. */
  @Column({ name: 'spring_load', type: 'decimal', precision: 4, scale: 2, nullable: true, transformer: decimalToNumber })
  springLoad: number | null;

  @Column({ type: 'varchar', length: 16, nullable: true })
  footbar: string | null;

  @Column({ type: 'varchar', length: 16, nullable: true })
  headrest: string | null;

  @Column({ name: 'carriage_start', type: 'varchar', length: 24, nullable: true })
  carriageStart: string | null;

  /** Box, Gurte, Jumpboard — oder „keines". */
  @Column({ type: 'varchar', length: 48, nullable: true })
  attachment: string | null;

  @Column({ type: 'varchar', length: 32, nullable: true })
  position: string | null;

  /** Platz in der klassischen Reihenfolge; der Generator sortiert danach. */
  @Column({ name: 'classical_order', type: 'int', nullable: true })
  classicalOrder: number | null;

  @OneToOne(() => Exercise, (e) => e.reformer, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'exercise_id' })
  exercise: Exercise;
}
