import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Review } from './review.entity';

/**
 * Ein Foto zur Trainingsaufzeichnung (Trainings-Galerie, F1).
 * Die Bilddaten liegen als BLOB in der Datenbank: Das MySQL-Volume hat
 * reichlich Reserve, die Bilder sind klein (9:16, JPEG ~300 KB) und
 * wandern so ohne Zusatz-Infrastruktur in die bestehende Sicherung.
 */
@Entity('review_photo')
export class ReviewPhoto {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'review_id' })
  reviewId: number;

  @Column({ name: 'client_id' })
  clientId: number;

  @Column({ length: 40, default: 'image/jpeg' })
  mime: string;

  @Column({ type: 'mediumblob' })
  bytes: Buffer;

  @Column({ name: 'created_at', type: 'datetime' })
  createdAt: Date;

  @ManyToOne(() => Review, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'review_id' })
  review: Review;
}
