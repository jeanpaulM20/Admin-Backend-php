import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

/**
 * Push subscription — stores browser Web Push endpoints AND iOS APNs device tokens.
 * platform = 'web'  → endpoint/p256dh/auth populated (VAPID / Web Push)
 * platform = 'ios'  → device_token populated (APNs hex token)
 * One client may have multiple subscriptions (different browsers/devices).
 */
@Entity({ name: 'push_subscription' })
export class PushSubscription {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  client_id: number;

  /** Web Push endpoint URL (platform='web') or synthetic 'apns://{token}' (platform='ios') */
  @Column({ type: 'text' })
  endpoint: string;

  @Column({ type: 'text' })
  p256dh: string;

  @Column({ type: 'text' })
  auth: string;

  /** APNs device token hex string — only set when platform = 'ios' */
  @Column({ type: 'text', nullable: true })
  device_token: string | null;

  /** 'web' (VAPID) | 'ios' (APNs) — default web for backward compat */
  @Column({ type: 'varchar', length: 10, default: 'web' })
  platform: string;

  @Column({ type: 'datetime', nullable: true, default: () => 'CURRENT_TIMESTAMP' })
  created_at: Date;
}
