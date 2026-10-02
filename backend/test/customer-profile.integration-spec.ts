import { DataSource } from 'typeorm';
import { AuthAuditEventEntity } from '../src/auth/auth-audit-event.entity';
import { CustomerProfileService } from '../src/users/customer-profile.service';
import { UserEntity } from '../src/users/user.entity';
import { AccountStatus } from '../src/users/account-status';
import { Booking } from '../src/bookings/domain/booking.entity';
import { BookingStatus } from '../../shared/booking-lifecycle.types';
import { createTestDataSource } from './support/test-data-source';

describe('customer profile PostgreSQL boundaries', () => {
  const dataSource: DataSource = createTestDataSource();
  const service = new CustomerProfileService(dataSource);

  beforeAll(() => dataSource.initialize());
  beforeEach(() =>
    dataSource.query(
      'TRUNCATE TABLE "bookings", "booking_events", "customer_profiles", "auth_audit_events", "service_categories", "users" CASCADE',
    ),
  );
  afterAll(async () => {
    await dataSource.query(
      'TRUNCATE TABLE "bookings", "booking_events", "customer_profiles", "auth_audit_events", "service_categories", "users" CASCADE',
    );
    await dataSource.destroy();
  });

  async function createUser(): Promise<UserEntity> {
    const repository = dataSource.getRepository(UserEntity);
    return repository.save(
      repository.create({
        status: AccountStatus.Active,
        statusReason: null,
        statusChangedAt: new Date(),
      }),
    );
  }

  // The response grew a `stats` block after this was written; the suite had
  // never run, so the stale expectation sat here unnoticed. `toEqual` is kept
  // deliberately - this is the response contract, so an added field should fail
  // here rather than surprise a client.
  const emptyStats = {
    completedJobs: 0,
    cashbackMinor: 0,
    activeWarranties: 0,
  };

  it('reads and updates only the selected customer profile', async () => {
    const first = await createUser();
    const second = await createUser();

    await expect(service.read(first.id)).resolves.toEqual({
      displayName: null,
      stats: emptyStats,
    });
    await expect(service.update(first.id, 'Ada')).resolves.toEqual({
      displayName: 'Ada',
      stats: emptyStats,
    });
    await expect(service.read(first.id)).resolves.toEqual({
      displayName: 'Ada',
      stats: emptyStats,
    });
    await expect(service.read(second.id)).resolves.toEqual({
      displayName: null,
      stats: emptyStats,
    });
  });

  it('counts a completed booking into the profile stats', async () => {
    const user = await createUser();
    const bookings = dataSource.getRepository(Booking);
    const categoryId = '00000000-0000-4000-8000-000000000301';
    await dataSource.query(
      `INSERT INTO "service_categories" ("id", "name", "slug", "is_active") VALUES ($1, 'Plumbing', 'plumbing-stats', true)`,
      [categoryId],
    );
    await bookings.save(
      bookings.create({
        customerId: user.id,
        serviceCategoryId: categoryId,
        idempotencyKey: 'profile-stats-completed',
        requestFingerprint: 'a'.repeat(64),
        status: BookingStatus.COMPLETED,
        description: 'Completed work',
        locationLat: 22.3072,
        locationLng: 73.1812,
        completedAt: new Date(),
      }),
    );
    await bookings.save(
      bookings.create({
        customerId: user.id,
        serviceCategoryId: categoryId,
        idempotencyKey: 'profile-stats-requested',
        requestFingerprint: 'b'.repeat(64),
        status: BookingStatus.REQUESTED,
        description: 'Still in flight',
        locationLat: 22.3072,
        locationLng: 73.1812,
      }),
    );

    // Only COMPLETED counts. A booking still in flight must not inflate a
    // customer's history.
    await expect(service.read(user.id)).resolves.toMatchObject({
      stats: { completedJobs: 1, activeWarranties: 1 },
    });
  });

  it('persists privacy-safe audit events without profile values', async () => {
    const user = await createUser();
    await service.update(user.id, 'Private Display Name');

    const audit = await dataSource.getRepository(AuthAuditEventEntity).find();
    expect(audit).toHaveLength(1);
    expect(audit[0]).toMatchObject({
      userId: user.id,
      eventType: 'customer_profile.update',
      outcome: 'success',
    });
    expect(JSON.stringify(audit[0])).not.toContain('Private Display Name');
  });
});
