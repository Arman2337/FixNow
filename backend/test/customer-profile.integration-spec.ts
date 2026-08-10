import { DataSource } from 'typeorm';
import { AuthAuditEventEntity } from '../src/auth/auth-audit-event.entity';
import { CustomerProfileEntity } from '../src/users/customer-profile.entity';
import { CustomerProfileService } from '../src/users/customer-profile.service';
import { UserEntity } from '../src/users/user.entity';
import { AccountStatus } from '../src/users/account-status';

describe('customer profile PostgreSQL boundaries', () => {
  const rawUrl = process.env.TEST_DATABASE_URL;
  if (!rawUrl)
    throw new Error('TEST_DATABASE_URL must target an isolated test database');
  const url = new URL(rawUrl);
  if (
    url.protocol !== 'postgresql:' ||
    !['127.0.0.1', 'localhost'].includes(url.hostname) ||
    url.port !== '55432' ||
    url.username !== 'fixnow_test' ||
    url.pathname !== '/fixnow_test'
  ) {
    throw new Error(
      'Refusing destructive integration tests: TEST_DATABASE_URL must be the documented loopback fixnow_test database on port 55432',
    );
  }

  const dataSource = new DataSource({
    type: 'postgres',
    url: rawUrl,
    entities: [UserEntity, CustomerProfileEntity, AuthAuditEventEntity],
    synchronize: false,
  });
  const service = new CustomerProfileService(dataSource);

  beforeAll(() => dataSource.initialize());
  beforeEach(() =>
    dataSource.query(
      'TRUNCATE TABLE "customer_profiles", "auth_audit_events", "users" CASCADE',
    ),
  );
  afterAll(async () => {
    await dataSource.query(
      'TRUNCATE TABLE "customer_profiles", "auth_audit_events", "users" CASCADE',
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

  it('reads and updates only the selected customer profile', async () => {
    const first = await createUser();
    const second = await createUser();

    await expect(service.read(first.id)).resolves.toEqual({
      displayName: null,
    });
    await expect(service.update(first.id, 'Ada')).resolves.toEqual({
      displayName: 'Ada',
    });
    await expect(service.read(first.id)).resolves.toEqual({
      displayName: 'Ada',
    });
    await expect(service.read(second.id)).resolves.toEqual({
      displayName: null,
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
