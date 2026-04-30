import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity({ name: 'exercise_subgroups' })
export class Exercisesubgroup {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  name: string;
}
