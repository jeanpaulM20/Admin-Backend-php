import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity({ name: 'credit_package' })
export class CreditPackage {
  @PrimaryGeneratedColumn() id: number;

  @Column() name: string;

  @Column({ default: 0 }) credits: number;

  @Column({ type: 'decimal', precision: 10, scale: 2, default: 0 }) price: number;

  @Column({ name: 'price_per_session', type: 'decimal', precision: 10, scale: 2, nullable: true })
  pricePerSession: number;

  @Column({ name: 'duration_months', nullable: true }) durationMonths: number;

  @Column({ nullable: true, type: 'text' }) description: string;

  @Column({ nullable: true, type: 'text' }) includes: string;

  @Column({ name: 'sort_order', default: 0 }) sortOrder: number;

  @Column({ default: 1 }) active: number;
}
