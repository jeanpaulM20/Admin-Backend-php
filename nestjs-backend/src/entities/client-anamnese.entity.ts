import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

/**
 * Medical intake questionnaire — one record per client.
 * Property names match MySQL columns AND Flutter Anamnese.fromJson keys.
 * Note: "sportarts_intencity" and "disease_raynauld_syndrome" are original
 * PHP typos preserved for DB compatibility.
 */
@Entity({ name: 'client_anamnese' })
export class ClientAnamnese {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  client_id: number;

  // Personal info
  @Column({ type: 'text', nullable: true })
  address: string;

  @Column({ type: 'text', nullable: true })
  profession: string;

  @Column({ nullable: true })
  activities: string;

  @Column({ nullable: true })
  physical_demands: string;

  // Sport & Training
  @Column({ type: 'text', nullable: true })
  sportarts: string;

  @Column({ nullable: true })
  sportarts_scope: string;

  @Column({ nullable: true })
  sportarts_intencity: string;    // typo from PHP, kept for DB compat

  // Sleep & Recovery
  @Column({ nullable: true })
  sleep_week: string;

  @Column({ nullable: true })
  sleep_weekend: string;

  @Column({ nullable: true })
  relaxation_week: string;

  @Column({ nullable: true })
  relaxation_weekend: string;

  @Column({ nullable: true })
  training_dayoff: string;

  // Injuries
  @Column({ type: 'tinyint', default: 0 })
  injury: number;

  @Column({ type: 'text', nullable: true })
  injury_type: string;

  @Column({ type: 'text', nullable: true })
  injury_bodypart: string;

  @Column({ type: 'tinyint', default: 0 })
  injury_chronic: number;

  // Diseases / Contraindications
  @Column({ type: 'tinyint', default: 0 })
  disease_heartattack: number;

  @Column({ type: 'tinyint', default: 0 })
  disease_arterial_disorder: number;

  @Column({ type: 'tinyint', default: 0 })
  disease_raynauld_syndrome: number;  // typo from PHP

  @Column({ type: 'tinyint', default: 0 })
  disease_vasculitis: number;

  @Column({ type: 'tinyint', default: 0 })
  disease_cold_sensitivity: number;

  @Column({ type: 'tinyint', default: 0 })
  disease_sensory_disturbances: number;

  @Column({ type: 'tinyint', default: 0 })
  disease_circulatory_disorder: number;

  @Column({ type: 'tinyint', default: 0 })
  disease_nerve_damage: number;

  @Column({ type: 'tinyint', default: 0 })
  disease_replantation: number;

  @Column({ type: 'tinyint', default: 0 })
  disease_peripheral_lymphatics: number;

  @Column({ type: 'tinyint', default: 0 })
  disease_hemoglobinemia: number;

  @Column({ type: 'tinyint', default: 0 })
  disease_kidney_bladder: number;

  @Column({ type: 'tinyint', default: 0 })
  disease_heart_circulatory: number;

  // Musculoskeletal
  @Column({ type: 'tinyint', default: 0 })
  musculoskeletal_problems: number;

  @Column({ type: 'text', nullable: true })
  musculoskeletal_problems_description: string;

  // General
  @Column({ type: 'tinyint', default: 0 })
  medical_treatment: number;

  @Column({ type: 'tinyint', default: 0 })
  taking_drugs: number;

  @Column({ type: 'text', nullable: true })
  comments: string;

  @Column({ type: 'text', nullable: true })
  goals: string;

  @ManyToOne(() => Client)
  @JoinColumn({ name: 'client_id' })
  client: Client;
}
