import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, OneToOne, JoinColumn } from 'typeorm';
import { Exercisegroup } from './exercise-group.entity';
import { ExerciseReformer } from './exercise-reformer.entity';
import { decimalToNumber, tinyintToBoolean } from './column-transformers';
import { Exercisesubgroup } from './exercise-subgroup.entity';
import { Exercisepictures } from './exercise-pictures.entity';

@Entity({ name: 'exercise' })
export class Exercise {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  name: string;

  @Column({ name: 'group_id', nullable: true })
  groupId: number;

  @Column({ name: 'subgroup_id', nullable: true })
  subgroupId: number;

  @Column({ default: 0 })
  archive: number;

  @Column({ default: 0 })
  published: number;

  // ── Anatomie-Metadaten (für KI-gestützte Planauswahl) ──

  /** UpperBody | LowerBody | Core | FullBody | Foot | Shoulder | Spine | Hip */
  @Column({ name: 'body_region', nullable: true })
  bodyRegion: string;

  /** z.B. Quadriceps, Hamstrings, Wade, Oberer Rücken, Brust, Schulter … */
  @Column({ name: 'primary_muscle_group', nullable: true })
  primaryMuscleGroup: string;

  /** Sprunggelenk | Knie | Hüfte | LWS | BWS | Schulter | Ellenbogen | Handgelenk */
  @Column({ name: 'target_joint', nullable: true })
  targetJoint: string;

  /** Push | Pull | Squat | Hinge | Carry | Rotation | Static | Plyo | Sprint | Agility */
  @Column({ name: 'movement_pattern', nullable: true })
  movementPattern: string;

  /** AI-generated line-art icon (PNG binary, stored as LONGBLOB) */
  @Column({ type: 'longblob', nullable: true, select: false })
  icon: Buffer | null;

  // ── Modalität und Ausführung (Konzept Programm-Generator, Abschnitt 4.1) ──
  // Alle nullable: der Bestand von 148 Übungen bleibt ohne Änderung gültig.

  /** athletik | fitness | cardio | pilates_mat | pilates_reformer — s. exercise-vocabulary.ts */
  @Column({ type: 'varchar', length: 24, nullable: true })
  modality: string | null;

  /** Gerät, Vokabular aus dem Import (leg_press, cable, …) plus Pilates-Geräte */
  @Column({ type: 'varchar', length: 48, nullable: true })
  equipment: string | null;

  /** beginner | intermediate | advanced */
  @Column({ type: 'varchar', length: 16, nullable: true })
  level: string | null;

  /** Ausführung Schritt für Schritt, deutsch */
  @Column({ name: 'instructions_de', type: 'text', nullable: true })
  instructionsDe: string | null;

  /** Ansagen für den Trainer („Rippen schliessen") */
  @Column({ name: 'cues_de', type: 'text', nullable: true })
  cuesDe: string | null;

  /** Atemführung — bei Pilates Teil der Übung */
  @Column({ name: 'breathing_de', type: 'varchar', length: 190, nullable: true })
  breathingDe: string | null;

  /** z.B. „3-1-1-0" (exzentrisch-Pause-konzentrisch-Pause) */
  @Column({ type: 'varchar', length: 16, nullable: true })
  tempo: string | null;

  /** Kommagetrennte Schlüssel, s. ContraindicationKey */
  @Column({ type: 'varchar', length: 255, nullable: true })
  contraindications: string | null;

  @Column({ name: 'is_unilateral', type: 'tinyint', width: 1, nullable: true, transformer: tinyintToBoolean })
  isUnilateral: boolean | null;

  /** Energieumsatz, für die Kalorienschätzung */
  @Column({ type: 'decimal', precision: 4, scale: 2, nullable: true, transformer: decimalToNumber })
  met: number | null;

  /** sihl | repdb | free-exercise-db — ohne Herkunft lässt sich kein Import neu abgleichen */
  @Column({ type: 'varchar', length: 32, nullable: true })
  source: string | null;

  /** Fremd-ID der Quelle */
  @Column({ name: 'source_ref', type: 'varchar', length: 120, nullable: true })
  sourceRef: string | null;

  /** Reformer-Angaben — nur bei modality = pilates_reformer vorhanden */
  @OneToOne(() => ExerciseReformer, (r) => r.exercise)
  reformer: ExerciseReformer | null;

  @ManyToOne(() => Exercisegroup, (g) => g.exercises)
  @JoinColumn({ name: 'group_id' })
  group: Exercisegroup;

  @ManyToOne(() => Exercisesubgroup)
  @JoinColumn({ name: 'subgroup_id' })
  subgroup: Exercisesubgroup;

  @OneToMany(() => Exercisepictures, (p) => p.exercise)
  exercisePictures: Exercisepictures[];
}
