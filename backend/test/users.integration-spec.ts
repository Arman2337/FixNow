import { DataSource, QueryFailedError } from 'typeorm';
import { AccountStatus } from '../src/users/account-status';
import { IdentityEntity } from '../src/users/identity.entity';
import { RoleEntity } from '../src/users/role.entity';
import { UserRoleEntity } from '../src/users/user-role.entity';
import { UserEntity } from '../src/users/user.entity';
import { UsersRepository } from '../src/users/users.repository';

describe('user identity PostgreSQL boundaries', () => {
  const rawUrl = process.env.TEST_DATABASE_URL;
  if (!rawUrl)
    throw new Error('TEST_DATABASE_URL must target an isolated test database');
  const url = new URL(rawUrl);
  const isExpectedTestDatabase =
    url.protocol === 'postgresql:' &&
    ['127.0.0.1', 'localhost'].includes(url.hostname) &&
    url.port === '55432' &&
    url.username === 'fixnow_test' &&
    url.pathname === '/fixnow_test';
  if (!isExpectedTestDatabase) {
    throw new Error(
      'Refusing destructive integration tests: TEST_DATABASE_URL must be the documented loopback fixnow_test database on port 55432',
    );
  }

  const dataSource = new DataSource({
    type: 'postgres',
    url: rawUrl,
    entities: [UserEntity, IdentityEntity, RoleEntity, UserRoleEntity],
    synchronize: false,
  });

  beforeAll(() => dataSource.initialize());
  beforeEach(() =>
    dataSource.query(
      'TRUNCATE TABLE "user_roles", "user_identities", "roles", "users" CASCADE',
    ),
  );
  afterAll(() => dataSource.destroy());

  it('persists the account lifecycle through the repository boundary', async () => {
    const repository = new UsersRepository(
      dataSource.getRepository(UserEntity),
    );
    const created = await repository.create();

    expect(created.status).toBe(AccountStatus.PendingVerification);

    const activated = await repository.transitionStatus(
      created.id,
      AccountStatus.Active,
      'identity verified',
    );

    expect(activated).toMatchObject({
      id: created.id,
      status: AccountStatus.Active,
      statusReason: 'identity verified',
    });
  });

  it('enforces provider-subject uniqueness at the database boundary', async () => {
    const users = new UsersRepository(dataSource.getRepository(UserEntity));
    const identities = dataSource.getRepository(IdentityEntity);
    const first = await users.create();
    const second = await users.create();

    await identities.save(
      identities.create({
        userId: first.id,
        provider: 'test',
        subject: 'subject-1',
      }),
    );

    await expect(
      identities.save(
        identities.create({
          userId: second.id,
          provider: 'test',
          subject: 'subject-1',
        }),
      ),
    ).rejects.toBeInstanceOf(QueryFailedError);
  });
});
