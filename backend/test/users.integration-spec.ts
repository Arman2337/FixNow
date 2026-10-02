import { DataSource, QueryFailedError } from 'typeorm';
import { AccountStatus } from '../src/users/account-status';
import { IdentityEntity } from '../src/users/identity.entity';
import { UserEntity } from '../src/users/user.entity';
import { UsersRepository } from '../src/users/users.repository';
import { createTestDataSource } from './support/test-data-source';

describe('user identity PostgreSQL boundaries', () => {
  const dataSource: DataSource = createTestDataSource();

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
