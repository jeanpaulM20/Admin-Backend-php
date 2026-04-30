import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Exercise } from './exercise.entity';

@Entity({ name: 'exercise_pictures' })
export class Exercisepictures {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'exercise_id' })
  exerciseId: number;

  @Column({ nullable: true })
  label: string;

  @Column({ name: 'picture', nullable: true })
  filename: string;

  @Column({ nullable: true })
  description: string;

  @Column({ default: 0 })
  published: number;

  @Column({ default: 0 })
  sort: number;

  @Column({ name: 'language_id', nullable: true })
  languageId: number;

  @ManyToOne(() => Exercise, (e) => e.exercisePictures)
  @JoinColumn({ name: 'exercise_id' })
  exercise: Exercise;
}
