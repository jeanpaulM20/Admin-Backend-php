import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PushSubscription } from '../entities/push-subscription.entity';
import * as webpush from 'web-push';

@Injectable()
export class PushService {
  private readonly logger = new Logger('PushService');
  private readonly vapidConfigured: boolean;

  constructor(
    @InjectRepository(PushSubscription)
    private readonly subRepo: Repository<PushSubscription>,
  ) {
    const publicKey = process.env.VAPID_PUBLIC_KEY;
    const privateKey = process.env.VAPID_PRIVATE_KEY;
    const subject = process.env.VAPID_SUBJECT ?? 'mailto:info@sihltraining.ch';

    if (publicKey && privateKey) {
      webpush.setVapidDetails(subject, publicKey, privateKey);
      this.vapidConfigured = true;
      this.logger.log('VAPID keys configured');
    } else {
      this.vapidConfigured = false;
      this.logger.warn('VAPID keys not set — push notifications disabled');
    }
  }

  /** Return the public VAPID key so Flutter can subscribe */
  getPublicKey(): string | null {
    return process.env.VAPID_PUBLIC_KEY ?? null;
  }

  /** Store a new push subscription for a client */
  async subscribe(
    clientId: number,
    endpoint: string,
    p256dh: string,
    auth: string,
  ): Promise<PushSubscription> {
    // Avoid duplicates: check if this endpoint already exists
    const existing = await this.subRepo.findOne({ where: { endpoint } });
    if (existing) {
      // Update client_id in case it changed
      existing.client_id = clientId;
      existing.p256dh = p256dh;
      existing.auth = auth;
      return this.subRepo.save(existing);
    }

    const sub = this.subRepo.create({
      client_id: clientId,
      endpoint,
      p256dh,
      auth,
    });
    return this.subRepo.save(sub);
  }

  /** Remove a subscription (e.g. on logout) */
  async unsubscribe(clientId: number, endpoint: string): Promise<void> {
    await this.subRepo.delete({ client_id: clientId, endpoint });
  }

  /** Send a push notification to all subscriptions for a given client */
  async sendToClient(
    clientId: number,
    payload: { title: string; body: string; url?: string },
  ): Promise<void> {
    if (!this.vapidConfigured) return;

    const subs = await this.subRepo.find({ where: { client_id: clientId } });
    if (!subs.length) return;

    const data = JSON.stringify(payload);

    for (const sub of subs) {
      try {
        await webpush.sendNotification(
          {
            endpoint: sub.endpoint,
            keys: { p256dh: sub.p256dh, auth: sub.auth },
          },
          data,
        );
      } catch (err: any) {
        // 404 or 410 = subscription expired / unsubscribed
        if (err.statusCode === 404 || err.statusCode === 410) {
          this.logger.log(`Removing expired subscription ${sub.id}`);
          await this.subRepo.delete(sub.id);
        } else {
          this.logger.warn(`Push failed for sub ${sub.id}: ${err.message}`);
        }
      }
    }
  }
}
