import { Entity, PrimaryGeneratedColumn, Column, ManyToMany, JoinTable } from 'typeorm';
import { Exercise } from './exercise.entity';

@Entity({ name: 'exerciseset' })
export class Exerciseset {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  name: string;

  @Column({ default: 0 })
  archive: number;

  @Column({ default: 0 })
  published: number;

  @ManyToMany(() => Exercise)
  @JoinTable({
    name: 'tbl_exerciseset_exercise',
    joinColumn: { name: 'exerciseset_id', referencedColumnName: 'id' },
    inverseJoinColumn: { name: 'exercise_id', referencedColumnName: 'id' },
  })
  exercises: Exercise[];
}
