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

  @Column({ nullable: true, type: 'text' })
  description: string;

  @Column({ name: 'group_id', nullable: true })
  groupId: number;

  @Column({ name: 'subgroup_id', nullable: true })
  subgroupId: number;

  @Column({ default: 1 })
  active: number;

  @ManyToOne(() => Exercisegroup, (g) => g.exercises)
  @JoinColumn({ name: 'group_id' })
  group: Exercisegroup;

  @ManyToOne(() => Exercisesubgroup)
  @JoinColumn({ name: 'subgroup_id' })
  subgroup: Exercisesubgroup;

  @OneToMany(() => Exercisepictures, (p) => p.exercise)
  pictures: Exercisepictures[];
}
