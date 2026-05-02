// Smaller entities grouped for convenience – split into separate files as you expand them

import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';
import { Trainer } from './trainer.entity';

@Entity({ name: 'abbonement' })
export class Abbonement {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'client_id' }) clientId: number;
  @Column({ nullable: true }) type: string;
  @Column({ name: 'valid_from', type: 'date', nullable: true }) validFrom: string;
  @Column({ name: 'valid_to', type: 'date', nullable: true }) validTo: string;
  @Column({ default: 1 }) active: number;
  @ManyToOne(() => Client) @JoinColumn({ name: 'client_id' }) client: Client;
}

// Re-export from dedicated file so that modules importing from remaining.entities still work
export { ClientAnamnese } from './client-anamnese.entity';

@Entity({ name: 'client_credits' })
export class ClientCredits {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'client_id' }) clientId: number;
  @Column({ name: 'training_type_id', nullable: true }) trainingTypeId: number;
  @Column({ default: 0 }) paid: number;
  @Column({ default: 0 }) attended: number;
  @Column({ name: 'abbonement_id', nullable: true }) abbonementId: number;
  @Column({ name: 'sold_by_id', nullable: true }) soldById: number;
  @Column({ type: 'date', nullable: true }) startdate: string;
  @Column({ type: 'date', nullable: true }) expires: string;
  @Column({ name: 'sell_date', type: 'date', nullable: true }) sellDate: string;
  @ManyToOne(() => Client) @JoinColumn({ name: 'client_id' }) client: Client;
}

@Entity({ name: 'client_heart_rate' })
export class Clientheartrate {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'client_id' }) clientId: number;
  @Column({ name: 'heart_rate', type: 'int' }) heartRate: number;
  @Column({ type: 'datetime' }) timestamp: Date;
  @ManyToOne(() => Client) @JoinColumn({ name: 'client_id' }) client: Client;
}

@Entity({ name: 'client_max_heart_rate' })
export class Clientmaxheartrate {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'client_id' }) clientId: number;
  @Column({ name: 'max_heart_rate', type: 'int' }) maxHeartRate: number;
  @Column({ type: 'date' }) date: string;
  @ManyToOne(() => Client) @JoinColumn({ name: 'client_id' }) client: Client;
}

@Entity({ name: 'client_session' })
export class ClientSession {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'client_id' }) clientId: number;
  @Column({ nullable: true }) device: string;
  @Column({ name: 'last_seen', type: 'datetime', nullable: true }) lastSeen: Date;
  @ManyToOne(() => Client) @JoinColumn({ name: 'client_id' }) client: Client;
}

@Entity({ name: 'content' })
export class Content {
  @PrimaryGeneratedColumn() id: number;
  @Column() title: string;
  @Column({ nullable: true, type: 'text' }) body: string;
  @Column({ nullable: true }) type: string;
  @Column({ default: 1 }) active: number;
}

@Entity({ name: 'content_fotos' })
export class ContentFoto {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'content_id' }) contentId: number;
  @Column() filename: string;
}

@Entity({ name: 'door_log' })
export class DoorLog {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'client_id', nullable: true }) clientId: number;
  @Column({ nullable: true }) action: string;
  @Column({ type: 'datetime', default: () => 'CURRENT_TIMESTAMP' }) timestamp: Date;
}

@Entity({ name: 'file' })
export class File {
  @PrimaryGeneratedColumn() id: number;
  @Column() filename: string;
  @Column({ nullable: true }) path: string;
  @Column({ name: 'client_id', nullable: true }) clientId: number;
  @Column({ name: 'trainer_id', nullable: true }) trainerId: number;
  @Column({ name: 'created_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' }) createdAt: Date;
}

@Entity({ name: 'goal' })
export class Goal {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'client_id' }) clientId: number;
  @Column({ nullable: true, type: 'text' }) description: string;
  @Column({ name: 'target_date', type: 'date', nullable: true }) targetDate: string;
  @Column({ default: 0 }) achieved: number;
  @ManyToOne(() => Client) @JoinColumn({ name: 'client_id' }) client: Client;
}

@Entity({ name: 'language' })
export class Language {
  @PrimaryGeneratedColumn() id: number;
  @Column({ unique: true }) code: string;
  @Column() name: string;
}

@Entity({ name: 'locker' })
export class Locker {
  @PrimaryGeneratedColumn() id: number;
  @Column() number: string;
  @Column({ name: 'client_id', nullable: true }) clientId: number;
  @Column({ default: 0 }) occupied: number;
}

@Entity({ name: 'locker_log' })
export class LockerLog {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'locker_id' }) lockerId: number;
  @Column({ name: 'client_id', nullable: true }) clientId: number;
  @Column({ nullable: true }) action: string;
  @Column({ type: 'datetime', default: () => 'CURRENT_TIMESTAMP' }) timestamp: Date;
}

@Entity({ name: 'offer' })
export class Offer {
  @PrimaryGeneratedColumn() id: number;
  @Column() title: string;
  @Column({ nullable: true, type: 'text' }) description: string;
  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true }) price: number;
  @Column({ default: 1 }) active: number;
}

// Re-export from dedicated file so that modules importing from remaining.entities still work
export { PerformanceTest } from './performance-test.entity';

@Entity({ name: 'preference' })
export class Preference {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'client_id' }) clientId: number;
  @Column({ nullable: true }) key: string;
  @Column({ nullable: true }) value: string;
  @ManyToOne(() => Client) @JoinColumn({ name: 'client_id' }) client: Client;
}

@Entity({ name: 'review_feedback' })
export class ReviewFeedback {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'review_id' }) reviewId: number;
  @Column({ nullable: true, type: 'text' }) comment: string;
  @Column({ name: 'trainer_id', nullable: true }) trainerId: number;
  @Column({ name: 'created_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' }) createdAt: Date;
  @ManyToOne(() => Trainer) @JoinColumn({ name: 'trainer_id' }) trainer: Trainer;
}

@Entity({ name: 'screen_stats' })
export class Screenstats {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'client_id', nullable: true }) clientId: number;
  @Column({ nullable: true }) screen: string;
  @Column({ name: 'visit_count', default: 0 }) visitCount: number;
  @Column({ name: 'last_visited', type: 'datetime', nullable: true }) lastVisited: Date;
}

@Entity({ name: 'service' })
export class Service {
  @PrimaryGeneratedColumn() id: number;
  @Column() name: string;
  @Column({ nullable: true, type: 'text' }) description: string;
  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true }) price: number;
  @Column({ default: 1 }) active: number;
}

@Entity({ name: 'training_type' })
export class TrainingType {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'name_de', nullable: true }) nameDe: string;
  @Column({ name: 'name_en', nullable: true }) nameEn: string;
  @Column({ default: 60 }) duration: number;
  @Column({ nullable: true }) participants: number;
  @Column({ nullable: true }) sort: number;
  @Column({ nullable: true }) abbr: string;
}

@Entity({ name: 'translation' })
export class Translation {
  @PrimaryGeneratedColumn() id: number;
  @Column() key: string;
  @Column({ name: 'language_code' }) languageCode: string;
  @Column({ type: 'text' }) value: string;
}
