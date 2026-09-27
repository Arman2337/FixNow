import {
  ConflictException,
  HttpException,
  UnauthorizedException,
} from '@nestjs/common';
import * as argon2 from 'argon2';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { AccountStatus } from '../users/account-status';
import { CredentialEntity } from '../users/credential.entity';
import { IdentityEntity } from '../users/identity.entity';
import { UserEntity } from '../users/user.entity';
import { UserRoleEntity } from '../users/user-role.entity';
import { ProviderApplicationEntity } from '../providers/provider-application.entity';
import { ProviderOnboardingStatus } from '../providers/provider-onboarding-status';
import { AuthService } from './auth.service';
import { TokenLifecycleService } from './token-lifecycle.service';

describe('AuthService', () => {
  const issueSession = jest.fn().mockResolvedValue({
    userId: 'user-1',
    role: 'customer',
    accessToken: 'signed-access-token',
    refreshToken: 'refresh-token',
    tokenType: 'Bearer',
    expiresIn: 900,
  });
  const tokenLifecycle = { issueSession } as unknown as TokenLifecycleService;
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
  const credentialUpdateMock = jest.fn().mockResolvedValue({ affected: 1 });
  const credentialRepository = {
    findOneBy: jest.fn(),
    // A07: the lockout counter is written back on every failure and on success.
    update: credentialUpdateMock,
  } as unknown as jest.Mocked<Repository<CredentialEntity>>;
  const userRoleRepository = {
    findOneBy: jest.fn(),
    find: jest.fn(),
  } as unknown as jest.Mocked<Repository<UserRoleEntity>>;
  const dataSource = {
    transaction: jest.fn((callback: (value: EntityManager) => unknown) =>
      callback(manager),
    ),
    getRepository: jest.fn((entity: unknown) => {
      if (entity === IdentityEntity) return identityRepository;
      if (entity === UserRoleEntity) return userRoleRepository;
      return credentialRepository;
    }),
  } as unknown as DataSource;
  const service = new AuthService(dataSource, tokenLifecycle);

  beforeEach(() => {
    jest.clearAllMocks();
    manager.findOneBy.mockResolvedValue(null);
    userRoleRepository.findOneBy.mockResolvedValue(null);
    userRoleRepository.find.mockResolvedValue([]);
    (credentialRepository.update as jest.Mock).mockResolvedValue({
      affected: 1,
    });
  });

  it('registers a normalized customer with an Argon2id hash', async () => {
    const result = await service.registerCustomer({
      email: 'customer@example.com',
      password: 'Correct Horse Battery Staple!',
      mobile: '+919876543210',
    });

    expect(result).toEqual({
      userId: 'user-1',
      role: 'customer',
      accessToken: 'signed-access-token',
      refreshToken: 'refresh-token',
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
    expect(issueSession).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 'user-1',
        status: AccountStatus.PendingVerification,
      }),
      'customer',
    );
  });

  it('returns a generic conflict for an existing identity', async () => {
    manager.findOneBy.mockResolvedValue({ id: 'identity-1' });

    await expect(
      service.registerCustomer({
        email: 'customer@example.com',
        password: 'Correct Horse Battery Staple!',
        mobile: '+919876543210',
      }),
    ).rejects.toEqual(new ConflictException('Unable to create account'));
  });

  it('registers only an unverified provider-applicant persona', async () => {
    const result = await service.registerProvider({
      email: 'provider@example.com',
      password: 'Correct Horse Battery Staple!',
      mobile: '+919876543210',
    });

    const providerCreate = manager.create.mock.calls.find(
      ([entity]) => entity === ProviderApplicationEntity,
    );
    expect(providerCreate?.[1]).toEqual({
      userId: 'user-1',
      status: ProviderOnboardingStatus.Unverified,
    });
    expect(issueSession).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'user-1' }),
      'provider_applicant',
    );
    expect(result).toEqual(expect.objectContaining({ userId: 'user-1' }));
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

  // A07: no per-account lockout. The global throttle is keyed on the caller
  // address, so it bounds one egress, not one account.
  describe('per-account login lockout', () => {
    const validPassword = 'Correct Horse Battery Staple!';

    const lockedCredential = (
      overrides: Partial<CredentialEntity> = {},
    ): CredentialEntity =>
      ({
        id: 'credential-1',
        failedLoginCount: 0,
        lockedUntil: null,
        ...overrides,
      }) as CredentialEntity;

    const activeIdentity = (): IdentityEntity =>
      ({
        id: 'identity-1',
        userId: 'user-1',
        user: { id: 'user-1', status: AccountStatus.Active },
      }) as IdentityEntity;

    const credentialUpdate = credentialUpdateMock;
    let passwordHash: string;

    beforeEach(async () => {
      identityRepository.findOne.mockResolvedValue(activeIdentity());
      passwordHash = await argon2.hash(validPassword, {
        type: argon2.argon2id,
      });
    });

    const attempt = (password: string) =>
      service.login({ email: 'customer@example.com', password });

    const rejectedWith = (password: string): Promise<HttpException> =>
      attempt(password).then(
        () => {
          throw new Error('expected the login to be rejected');
        },
        (e: unknown) => e as HttpException,
      );

    it('counts a failed attempt', async () => {
      credentialRepository.findOneBy.mockResolvedValue(
        lockedCredential({ passwordHash }),
      );

      await expect(attempt('Wrong Password Value!')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
      expect(credentialUpdate).toHaveBeenCalledWith(
        { id: 'credential-1' },
        { failedLoginCount: 1 },
      );
    });

    it('locks at the threshold', async () => {
      credentialRepository.findOneBy.mockResolvedValue(
        lockedCredential({
          passwordHash,
          failedLoginCount: AuthService.MAX_FAILED_LOGINS - 1,
        }),
      );

      await expect(attempt('Wrong Password Value!')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );

      const calls = credentialUpdate.mock.calls as Array<
        [unknown, { failedLoginCount: number; lockedUntil: Date }]
      >;
      // The lock is applied conditionally on the pre-increment value, so two
      // concurrent failures cannot both read it and leave the count short.
      expect(calls[0][0]).toEqual({
        id: 'credential-1',
        failedLoginCount: AuthService.MAX_FAILED_LOGINS - 1,
      });
      expect(calls[0][1].failedLoginCount).toBe(AuthService.MAX_FAILED_LOGINS);
      expect(calls[0][1].lockedUntil).toBeInstanceOf(Date);
    });

    it('refuses a locked account without verifying the password', async () => {
      // The hash is deliberately not a valid argon2 digest. If the locked path
      // reached argon2.verify this would surface argon2's parse error rather
      // than our own rejection, so asserting the exact error also proves the
      // expensive verify was skipped - a locked account should not be usable
      // to burn CPU.
      credentialRepository.findOneBy.mockResolvedValue(
        lockedCredential({
          passwordHash: 'not-an-argon2-digest',
          lockedUntil: new Date(Date.now() + 60_000),
        }),
      );

      await expect(attempt(validPassword)).rejects.toEqual(
        new UnauthorizedException('Invalid email or password'),
      );
    });

    it('reports a lockout identically to a wrong password', async () => {
      credentialRepository.findOneBy.mockResolvedValue(
        lockedCredential({ passwordHash }),
      );
      const wrongPassword = rejectedWith('Wrong Password Value!');

      credentialRepository.findOneBy.mockResolvedValue(
        lockedCredential({
          passwordHash,
          failedLoginCount: 99,
          lockedUntil: new Date(Date.now() + 60_000),
        }),
      );
      const locked = rejectedWith(validPassword);

      const [a, b] = await Promise.all([wrongPassword, locked]);
      // Distinguishing them would tell an attacker which emails have accounts.
      expect(a.getStatus()).toBe(b.getStatus());
      expect(a.message).toBe(b.message);
    });

    it('clears the counter on a successful login', async () => {
      credentialRepository.findOneBy.mockResolvedValue(
        lockedCredential({ passwordHash, failedLoginCount: 3 }),
      );

      await expect(attempt(validPassword)).resolves.toEqual(
        expect.objectContaining({ userId: 'user-1' }),
      );
      expect(credentialUpdate).toHaveBeenCalledWith(
        { id: 'credential-1' },
        { failedLoginCount: 0, lockedUntil: null },
      );
    });
  });

  it('resolves provider role from persisted assignments at login', async () => {
    const passwordHash = await argon2.hash('Correct Horse Battery Staple!', {
      type: argon2.argon2id,
    });
    identityRepository.findOne.mockResolvedValue({
      id: 'identity-1',
      userId: 'provider-1',
      user: { id: 'provider-1', status: AccountStatus.Active },
    } as IdentityEntity);
    credentialRepository.findOneBy.mockResolvedValue({
      passwordHash,
    } as CredentialEntity);
    userRoleRepository.find.mockResolvedValue([
      {
        userId: 'provider-1',
        role: { code: 'provider_applicant' },
      } as UserRoleEntity,
    ]);

    await service.login({
      email: 'provider@example.com',
      password: 'Correct Horse Battery Staple!',
    });

    expect(issueSession).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'provider-1' }),
      'provider_applicant',
    );
  });

  it('prefers verified provider access after approval', async () => {
    const passwordHash = await argon2.hash('Correct Horse Battery Staple!', {
      type: argon2.argon2id,
    });
    identityRepository.findOne.mockResolvedValue({
      id: 'identity-1',
      userId: 'provider-1',
      user: { id: 'provider-1', status: AccountStatus.Active },
    } as IdentityEntity);
    credentialRepository.findOneBy.mockResolvedValue({
      passwordHash,
    } as CredentialEntity);
    userRoleRepository.find.mockResolvedValue([
      {
        userId: 'provider-1',
        role: { code: 'provider_applicant' },
      } as UserRoleEntity,
      {
        userId: 'provider-1',
        role: { code: 'verified_provider' },
      } as UserRoleEntity,
    ]);

    await service.login({
      email: 'provider@example.com',
      password: 'Correct Horse Battery Staple!',
    });
    expect(issueSession).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'provider-1' }),
      'verified_provider',
    );
  });

  it('issues an admin session only for exactly one active staff role', async () => {
    const passwordHash = await argon2.hash('Correct Horse Battery Staple!', {
      type: argon2.argon2id,
    });
    identityRepository.findOne.mockResolvedValue({
      id: 'identity-1',
      userId: 'staff-1',
      user: { id: 'staff-1', status: AccountStatus.Active },
    } as IdentityEntity);
    credentialRepository.findOneBy.mockResolvedValue({
      passwordHash,
    } as CredentialEntity);
    userRoleRepository.find.mockResolvedValue([
      { role: { code: 'provider_reviewer' } } as UserRoleEntity,
    ]);

    await service.loginAdmin({
      email: 'reviewer@example.com',
      password: 'Correct Horse Battery Staple!',
    });
    expect(issueSession).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'staff-1' }),
      'provider_reviewer',
    );

    userRoleRepository.find.mockResolvedValue([
      { role: { code: 'customer' } } as UserRoleEntity,
    ]);
    await expect(
      service.loginAdmin({
        email: 'customer@example.com',
        password: 'Correct Horse Battery Staple!',
      }),
    ).rejects.toEqual(new UnauthorizedException('Invalid email or password'));

    userRoleRepository.find.mockResolvedValue([
      { role: { code: 'provider_reviewer' } } as UserRoleEntity,
      { role: { code: 'auditor' } } as UserRoleEntity,
    ]);
    await expect(
      service.loginAdmin({
        email: 'multi-role@example.com',
        password: 'Correct Horse Battery Staple!',
      }),
    ).rejects.toEqual(new UnauthorizedException('Invalid email or password'));
  });
});
