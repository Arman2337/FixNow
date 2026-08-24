import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
// Type-only import: erased at build time, keeps firebase-admin lazily loaded.
import type { Message as FirebaseAdminMessage } from 'firebase-admin/messaging';

export const PUSH_DELIVERY = Symbol('PUSH_DELIVERY');

/**
 * Lock-screen-safe content only. Booking identifiers and generic wording;
 * never names, addresses, phone numbers, or other personal data.
 */
export interface PushNotificationContent {
  title: string;
  body: string;
}

export type PushSendStatus = 'sent' | 'unregistered' | 'unavailable';

export interface PushDeliveryResult {
  status: PushSendStatus;
}

export interface PushDelivery {
  sendToToken(
    token: string,
    content: PushNotificationContent,
  ): Promise<PushDeliveryResult>;
}

/** Deterministic in-memory provider for tests and local development. */
@Injectable()
export class FakePushDelivery implements PushDelivery {
  readonly sent: Array<{ token: string; content: PushNotificationContent }> =
    [];

  sendToToken(
    token: string,
    content: PushNotificationContent,
  ): Promise<PushDeliveryResult> {
    this.sent.push({ token, content });
    return Promise.resolve({ status: 'sent' });
  }
}

/** Narrow surface of firebase-admin messaging used by this adapter. */
interface MessagingClient {
  send(message: FirebaseAdminMessage): Promise<string>;
}

@Injectable()
export class FcmPushDelivery implements PushDelivery {
  private messagingPromise: Promise<MessagingClient> | undefined;

  constructor(private readonly config: ConfigService) {}

  async sendToToken(
    token: string,
    content: PushNotificationContent,
  ): Promise<PushDeliveryResult> {
    const messaging = await this.resolveMessaging();
    try {
      await messaging.send({
        token,
        notification: { title: content.title, body: content.body },
        android: { priority: 'normal' },
        apns: { headers: { 'apns-priority': '5' } },
      });
      return { status: 'sent' };
    } catch (error) {
      if (isUnregisteredTokenError(error)) {
        return { status: 'unregistered' };
      }
      throw error;
    }
  }

  private async resolveMessaging(): Promise<MessagingClient> {
    if (!this.messagingPromise) {
      this.messagingPromise = this.initializeMessaging();
    }
    try {
      return await this.messagingPromise;
    } catch (error) {
      // Reset so a later request can retry after configuration is fixed.
      this.messagingPromise = undefined;
      throw error;
    }
  }

  private async initializeMessaging(): Promise<MessagingClient> {
    const credentialsFile = this.config.get<string>('FCM_CREDENTIALS_FILE');
    if (!credentialsFile) {
      throw new ServiceUnavailableException('Push delivery is unavailable');
    }
    const { initializeApp, cert, getApps } = await import('firebase-admin/app');
    const { getMessaging } = await import('firebase-admin/messaging');
    const existing = getApps().find((app) => app.name === 'fixnow-push');
    const app =
      existing ??
      initializeApp({ credential: cert(credentialsFile) }, 'fixnow-push');
    return getMessaging(app);
  }
}

function isUnregisteredTokenError(error: unknown): boolean {
  const code =
    typeof error === 'object' && error !== null && 'code' in error
      ? String((error as { code?: unknown }).code)
      : '';
  return code === 'messaging/registration-token-not-registered';
}
