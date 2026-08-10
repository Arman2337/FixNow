import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { AccountStatus } from '../users/account-status';
import { CredentialEntity } from '../users/credential.entity';
import { IdentityEntity } from '../users/identity.entity';
import { UserEntity } from '../users/user.entity';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  const signAsync = jest.fn().mockResolvedValue('signed-access-token');
  const jwtService = { signAsync } as unknown as JwtService;
  const manager = {
    findOneBy: jest.fn(),
    create: jest.fn((entity: unknown, values: object) => {
      if (entity === UserEntity) return { id: 'user-1', ...values };
      if (entity === IdentityEntity) return { id: 'identity-1', ...values };
      return values;
    }),
    save: jest.fn((value: unknown) => Promise.resolve(value)),
  } as unknown as jest.Mocked<EntityManager>;
  const identityRepository = {
    findOne: jest.fn(),
  } as unknown as jest.Mocked<Repository<IdentityEntity>>;
  const credentialRepository = {
    findOneBy: jest.fn(),
  } as unknown as jest.Mocked<Repository<CredentialEntity>>;
  const dataSource = {
    transaction: jest.fn((callback: (value: EntityManager) => unknown) =>
      callback(manager),
    ),
    getRepository: jest.fn((entity: unknown) =>
      entity === IdentityEntity ? identityRepository : credentialRepository,
    ),
  } as unknown as DataSource;
  const service = new AuthService(dataSource, jwtService);

  beforeEach(() => {
    jest.clearAllMocks();
    manager.findOneBy.mockResolvedValue(null);
  });

  it('registers a normalized customer with an Argon2id hash', async () => {
    const result = await service.register({
      email: 'customer@example.com',
      password: 'Correct Horse Battery Staple!',
    });

    expect(result).toEqual({
      userId: 'user-1',
      accessToken: 'signed-access-token',
      tokenType: 'Bearer',
      expiresIn: 900,
    });
    const credentialCreate = manager.create.mock.calls.find(
      ([entity]) => entity === CredentialEntity,
    );
    expect(credentialCreate).toBeDefined();
    const credential = credentialCreate?.[1] as unknown as CredentialEntity;
    expect(credential.passwordHash).not.toContain(
      'Correct Horse Battery Staple!',
    );
    await expect(
      argon2.verify(credential.passwordHash, 'Correct Horse Battery Staple!'),
    ).resolves.toBe(true);
    expect(signAsync).toHaveBeenCalledWith(
      expect.objectContaining({
        accountStatus: AccountStatus.PendingVerification,
        role: 'customer',
      }),
      expect.objectContaining({
        subject: 'user-1',
        expiresIn: 900,
      }),
    );
  });

  it('returns a generic conflict for an existing identity', async () => {
    manager.findOneBy.mockResolvedValue({ id: 'identity-1' });

    await expect(
      service.register({
        email: 'customer@example.com',
        password: 'Correct Horse Battery Staple!',
      }),
    ).rejects.toEqual(new ConflictException('Unable to create account'));
  });

  it('logs in with a valid password and rejects unknown or invalid credentials identically', async () => {
    const passwordHash = await argon2.hash('Correct Horse Battery Staple!', {
      type: argon2.argon2id,
    });
    identityRepository.findOne.mockResolvedValue({
      id: 'identity-1',
      user: {
        id: 'user-1',
        status: AccountStatus.Active,
      },
    } as IdentityEntity);
    credentialRepository.findOneBy.mockResolvedValue({
      passwordHash,
    } as CredentialEntity);

    await expect(
      service.login({
        email: 'customer@example.com',
        password: 'Correct Horse Battery Staple!',
      }),
    ).resolves.toEqual(expect.objectContaining({ userId: 'user-1' }));

    credentialRepository.findOneBy.mockResolvedValue({
      passwordHash,
    } as CredentialEntity);
    const invalidPassword = service.login({
      email: 'customer@example.com',
      password: 'Wrong Password Value!',
    });
    await expect(invalidPassword).rejects.toEqual(
      new UnauthorizedException('Invalid email or password'),
    );

    identityRepository.findOne.mockResolvedValue(null);
    const unknownIdentity = service.login({
      email: 'missing@example.com',
      password: 'Wrong Password Value!',
    });
    await expect(unknownIdentity).rejects.toEqual(
      new UnauthorizedException('Invalid email or password'),
    );
  });
});
