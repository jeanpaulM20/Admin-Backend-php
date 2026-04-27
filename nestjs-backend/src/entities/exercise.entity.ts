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

  @Column({ nullable: true })
  pictures: string;

  @Column({ default: 0 })
  archive: number;

  @Column({ default: 0 })
  published: number;

  @ManyToOne(() => Exercisegroup, (g) => g.exercises)
  @JoinColumn({ name: 'group_id' })
  group: Exercisegroup;

  @ManyToOne(() => Exercisesubgroup)
  @JoinColumn({ name: 'subgroup_id' })
  subgroup: Exercisesubgroup;

  @OneToMany(() => Exercisepictures, (p) => p.exercise)
  exercisePictures: Exercisepictures[];
}
