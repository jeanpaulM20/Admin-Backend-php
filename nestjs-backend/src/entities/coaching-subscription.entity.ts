import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn } from 'typeorm';
import { Client } from './client.entity';

/**
 * An online-coaching entitlement period. A client has coaching access
 * iff a row exists with status='active' AND valid_to >= today.
 * Created atomically alongside ClientCredits + Invoice on purchase of a
 * credit_package whose kind = 'coaching'.
 */
@Entity({ name: 'coaching_subscription' })
export class CoachingSubscription {
  @PrimaryGeneratedColumn() id: number;

  @Column({ name: 'client_id' }) clientId: number;

  @Column({ name: 'package_id', nullable: true }) packageId: number;

  /** 'monthly' | 'yearly' */
  @Column() tier: string;

  /** 'active' | 'cancelled' | 'expired' */
  @Column({ default: 'active' }) status: string;

  @Column({ name: 'valid_from', type: 'date' }) validFrom: string;

  @Column({ name: 'valid_to', type: 'date' }) validTo: string;

  @Column({ name: 'invoice_number', nullable: true }) invoiceNumber: string;

  @Column({ name: 'created_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' })
  createdAt: Date;

  @ManyToOne(() => Client) @JoinColumn({ name: 'client_id' }) client: Client;
}
