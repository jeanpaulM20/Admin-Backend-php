import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

/**
 * Records a client's like or dislike on a specific exercise within a plan.
 * Deliberately separate from the plan's values JSON (which belongs to the
 * trainer's prescription) so trainer edits never overwrite client feedback.
 *
 * exercise_key format: '{sectionPrefix}-{index}' e.g. 's-0', 'm-2', 'c-1'
 */
@Entity({ name: 'training_plan_like' })
export class TrainingPlanLike {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'plan_id' }) planId: number;
  @Column({ name: 'client_id' }) clientId: number;
  @Column({ name: 'exercise_key' }) exerciseKey: string;
  /** 'like' | 'dislike' */
  @Column() type: string;
  @Column({ name: 'created_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' })
  createdAt: Date;
}
