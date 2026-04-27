import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Exercise } from './exercise.entity';

@Entity({ name: 'exercise_pictures' })
export class Exercisepictures {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'exercise_id' })
  exerciseId: number;

  @Column()
  filename: string;

  @Column({ default: 0 })
  sort: number;

  @ManyToOne(() => Exercise, (e) => e.pictures)
  @JoinColumn({ name: 'exercise_id' })
  exercise: Exercise;
}
