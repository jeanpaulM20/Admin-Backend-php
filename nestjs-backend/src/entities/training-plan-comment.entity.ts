import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, CreateDateColumn } from 'typeorm';
import { TrainingPlan } from './training-plan.entity';
import { Trainer } from './trainer.entity';

@Entity({ name: 'training_plan_comment' })
export class TrainingPlanComment {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'plan_id' })
  planId: number;

  @Column({ name: 'trainer_id', nullable: true })
  trainerId: number;

  /** Optional exercise key like "s-0", "m-2", "c-1" — null = plan-level comment */
  @Column({ name: 'exercise_key', type: 'varchar', length: 10, nullable: true, default: null })
  exerciseKey: string | null;

  @Column({ type: 'text' })
  text: string;

  @Column({ name: 'author_name', nullable: true })
  authorName: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @ManyToOne(() => TrainingPlan, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'plan_id' })
  plan: TrainingPlan;

  @ManyToOne(() => Trainer, { nullable: true })
  @JoinColumn({ name: 'trainer_id' })
  trainer: Trainer;
}
