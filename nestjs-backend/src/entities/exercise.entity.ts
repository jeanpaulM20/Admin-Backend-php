import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, OneToMany, JoinColumn } from 'typeorm';
import { Exercisegroup } from './exercise-group.entity';
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

  @ManyToOne(() => Exercisegroup, (g) => g.exercises)
  @JoinColumn({ name: 'group_id' })
  group: Exercisegroup;

  @ManyToOne(() => Exercisesubgroup)
  @JoinColumn({ name: 'subgroup_id' })
  subgroup: Exercisesubgroup;

  @OneToMany(() => Exercisepictures, (p) => p.exercise)
  exercisePictures: Exercisepictures[];
}
