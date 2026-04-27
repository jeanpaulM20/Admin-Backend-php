import { Entity, PrimaryGeneratedColumn, Column, ManyToMany, JoinTable } from 'typeorm';
import { Exercise } from './exercise.entity';

@Entity({ name: 'exerciseset' })
export class Exerciseset {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  name: string;

  @Column({ nullable: true, type: 'text' })
  description: string;

  @ManyToMany(() => Exercise)
  @JoinTable({ name: 'exerciseset_exercise' })
  exercises: Exercise[];
}
