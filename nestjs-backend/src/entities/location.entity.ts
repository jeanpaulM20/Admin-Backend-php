import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity({ name: 'location' })
export class Location {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  name: string;

  @Column({ nullable: true })
  address: string;

  @Column({ default: 1 })
  active: number;
}
