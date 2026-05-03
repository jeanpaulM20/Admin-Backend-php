import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

/**
 * Web Push subscription — stores browser push endpoints per client.
 * One client may have multiple subscriptions (different browsers/devices).
 */
@Entity({ name: 'push_subscription' })
export class PushSubscription {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  client_id: number;

  @Column({ type: 'text' })
  endpoint: string;

  @Column({ type: 'text' })
  p256dh: string;

  @Column({ type: 'text' })
  auth: string;

  @Column({ type: 'datetime', nullable: true, default: () => 'CURRENT_TIMESTAMP' })
  created_at: Date;
}
