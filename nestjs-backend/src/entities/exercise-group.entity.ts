import { Entity, PrimaryGeneratedColumn, Column, OneToMany } from 'typeorm';
import { Exercise } from './exercise.entity';

@Entity({ name: 'exercise_group' })
export class Exercisegroup {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  name: string;

  @OneToMany(() => Exercise, (e) => e.group)
  exercises: Exercise[];
}
