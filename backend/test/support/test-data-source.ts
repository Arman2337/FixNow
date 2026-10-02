/**
 * One integration-test harness, shared by every spec.
 *
 * TEST-003. The suite had never been run, and the reason it never ran hid a
 * second problem: each spec hand-built its own `new DataSource({ entities: [...] })`
 * with a hand-copied subset of the entity list. Nine subsets, nine chances to be
 * wrong, and no execution to catch it. `booking-lifecycle` omitted
 * `BookingLineItem`, so the `Booking` relation could not resolve and the file
 * failed at `dataSource.initialize()` before a single assertion ran.
 * `customer-profile` omitted `Booking`, so `EntityManager.count(Booking)` threw
 * `EntityMetadataNotFoundError`. Both read as broken tests; both were broken
 * harnesses, and neither could be discovered without a database.
 *
 * Registering the whole entity set once means a spec can no longer drift, and
 * `test-data-source.spec.ts` fails if this list ever falls behind the files on
 * disk - the one drift direction that would otherwise be invisible.
 */
import { DataSource } from 'typeorm';

import { AuthAuditEventEntity } from '../../src/auth/auth-audit-event.entity';
import { AuthSessionEntity } from '../../src/auth/auth-session.entity';
import { OtpChallengeEntity } from '../../src/auth/otp-challenge.entity';
import { Booking } from '../../src/bookings/domain/booking.entity';
import { BookingCall } from '../../src/bookings/domain/booking-call.entity';
import { BookingEvent } from '../../src/bookings/domain/booking-event.entity';
import { BookingLineItem } from '../../src/bookings/domain/booking-line-item.entity';
import { BookingMessage } from '../../src/bookings/domain/booking-message.entity';
import { RecurringSchedule } from '../../src/bookings/domain/recurring-schedule.entity';
import { EmergencyDispatch } from '../../src/emergency/emergency-dispatch.entity';
import { OutboxMessage } from '../../src/outbox/outbox-message.entity';
import { GuaranteeClaim } from '../../src/guarantees/domain/guarantee-claim.entity';
import { InAppNotification } from '../../src/notifications/domain/in-app-notification.entity';
import { NotificationDelivery } from '../../src/notifications/domain/notification-delivery.entity';
import { PushDeviceTokenEntity } from '../../src/notifications/push/push-device-token.entity';
import { Invoice } from '../../src/payments/domain/invoice.entity';
import { PaymentEvent } from '../../src/payments/domain/payment-event.entity';
import { PaymentOrder } from '../../src/payments/domain/payment-order.entity';
import { Refund } from '../../src/payments/domain/refund.entity';
import { ProviderAvailabilityEntity } from '../../src/providers/availability/provider-availability.entity';
import { ProviderDocumentEntity } from '../../src/providers/documents/provider-document.entity';
import { ProviderDocumentAuditEntity } from '../../src/providers/documents/provider-document-audit.entity';
import { ProviderApplicationEntity } from '../../src/providers/provider-application.entity';
import { ProviderProfileEntity } from '../../src/providers/provider-profile.entity';
import { ProviderSkillEntity } from '../../src/providers/provider-skill.entity';
import { ProviderVerificationEventEntity } from '../../src/providers/verification/provider-verification-event.entity';
import { BookingReview } from '../../src/ratings/domain/review.entity';
import { ReviewModerationEvent } from '../../src/ratings/domain/review-moderation-event.entity';
import { ReviewPhoto } from '../../src/ratings/domain/review-photo.entity';
import { ReviewPhotoModerationEvent } from '../../src/ratings/domain/review-photo-moderation-event.entity';
import { ServiceCategoryEntity } from '../../src/services/service-category.entity';
import { SubServiceEntity } from '../../src/services/sub-service.entity';
import { Complaint } from '../../src/support/complaints/domain/complaint.entity';
import { ComplaintAudit } from '../../src/support/complaints/domain/complaint-audit.entity';
import { ComplaintEvidence } from '../../src/support/complaints/domain/complaint-evidence.entity';
import { TrustSignal } from '../../src/trust/domain/trust-signal.entity';
import { CredentialEntity } from '../../src/users/credential.entity';
import { CustomerAddressEntity } from '../../src/users/customer-address.entity';
import { CustomerProfileEntity } from '../../src/users/customer-profile.entity';
import { IdentityEntity } from '../../src/users/identity.entity';
import { PasswordResetTokenEntity } from '../../src/users/password-reset-token.entity';
import { RoleEntity } from '../../src/users/role.entity';
import { UserEntity } from '../../src/users/user.entity';
import { UserRoleEntity } from '../../src/users/user-role.entity';

/** Mirrors the entity glob in `typeorm.config.ts`. */
export const ALL_ENTITIES: (new () => object)[] = [
  AuthAuditEventEntity,
  AuthSessionEntity,
  OtpChallengeEntity,
  Booking,
  BookingCall,
  BookingEvent,
  BookingLineItem,
  BookingMessage,
  RecurringSchedule,
  EmergencyDispatch,
  OutboxMessage,
  GuaranteeClaim,
  InAppNotification,
  NotificationDelivery,
  PushDeviceTokenEntity,
  Invoice,
  PaymentEvent,
  PaymentOrder,
  Refund,
  ProviderAvailabilityEntity,
  ProviderDocumentEntity,
  ProviderDocumentAuditEntity,
  ProviderApplicationEntity,
  ProviderProfileEntity,
  ProviderSkillEntity,
  ProviderVerificationEventEntity,
  BookingReview,
  ReviewModerationEvent,
  ReviewPhoto,
  ReviewPhotoModerationEvent,
  ServiceCategoryEntity,
  SubServiceEntity,
  Complaint,
  ComplaintAudit,
  ComplaintEvidence,
  TrustSignal,
  CredentialEntity,
  CustomerAddressEntity,
  CustomerProfileEntity,
  IdentityEntity,
  PasswordResetTokenEntity,
  RoleEntity,
  UserEntity,
  UserRoleEntity,
];

/**
 * The only database these tests are permitted to touch.
 *
 * This guard used to be copied into all nine specs. Nine copies is nine chances
 * to weaken one, so it now lives here once. It is deliberately strict and
 * deliberately not configurable: these tests TRUNCATE, and the properties that
 * make that safe are the host being loopback and the database being a
 * dedicated, differently-named one. The port is pinned so a developer's own
 * application database on 5432 cannot be reached by accident.
 */
export const ISOLATED_TEST_DATABASE = {
  protocol: 'postgresql:',
  hostnames: ['127.0.0.1', 'localhost'] as const,
  port: '55432',
  username: 'fixnow_test',
  pathname: '/fixnow_test',
};

export function assertIsolatedTestDatabase(rawUrl: string | undefined): string {
  if (!rawUrl) {
    throw new Error(
      'TEST_DATABASE_URL must target an isolated test database. ' +
        'Run `npm run test:integration`, which prints how to provision one.',
    );
  }
  const url = new URL(rawUrl);
  const expected = ISOLATED_TEST_DATABASE;
  const ok =
    url.protocol === expected.protocol &&
    (expected.hostnames as readonly string[]).includes(url.hostname) &&
    url.port === expected.port &&
    url.username === expected.username &&
    url.pathname === expected.pathname;
  if (!ok) {
    throw new Error(
      'Refusing destructive integration tests: TEST_DATABASE_URL must be ' +
        `${expected.protocol}//${expected.username}:***@` +
        `${expected.hostnames[0]}:${expected.port}${expected.pathname}`,
    );
  }
  return rawUrl;
}

/**
 * A DataSource on the isolated test database with every entity registered.
 * The caller initialises and destroys it.
 */
export function createTestDataSource(): DataSource {
  return new DataSource({
    type: 'postgres',
    url: assertIsolatedTestDatabase(process.env.TEST_DATABASE_URL),
    entities: ALL_ENTITIES,
    // Never `synchronize`. These tests assert against constraints and triggers
    // that only exist if migrations built them, so a schema derived from the
    // entity metadata would make the database tests vacuous.
    synchronize: false,
  });
}
