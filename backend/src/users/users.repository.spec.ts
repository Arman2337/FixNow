import { BadRequestException, ConflictException } from '@nestjs/common';
import { Repository } from 'typeorm';
import { AccountStatus } from './account-status';
import { UserEntity } from './user.entity';
import { UsersRepository } from './users.repository';

describe('UsersRepository', () => {
  let typeormRepository: jest.Mocked<
    Pick<Repository<UserEntity>, 'create' | 'findOneBy' | 'save' | 'update'>
  >;
  let repository: UsersRepository;

  beforeEach(() => {
    typeormRepository = {
      create: jest.fn(),
      findOneBy: jest.fn(),
      save: jest.fn(),
      update: jest.fn(),
    };
    repository = new UsersRepository(
      typeormRepository as unknown as Repository<UserEntity>,
    );
  });

  it('creates accounts pending verification', async () => {
    const user = {
      id: 'user-1',
      status: AccountStatus.PendingVerification,
    } as UserEntity;
    typeormRepository.create.mockReturnValue(user);
    typeormRepository.save.mockResolvedValue(user);

    await expect(repository.create()).resolves.toBe(user);
    expect(typeormRepository.create).toHaveBeenCalledWith({
      status: AccountStatus.PendingVerification,
    });
  });

  it('persists a valid transition with its audit reason', async () => {
    const user = { id: 'user-1', status: AccountStatus.Active } as UserEntity;
    const updated = {
      ...user,
      status: AccountStatus.Suspended,
      statusReason: 'abuse review',
      statusChangedAt: new Date(),
    } as UserEntity;
    typeormRepository.findOneBy
      .mockResolvedValueOnce(user)
      .mockResolvedValueOnce(updated);
    typeormRepository.update.mockResolvedValue({
      affected: 1,
      generatedMaps: [],
      raw: [],
    });

    const result = await repository.transitionStatus(
      'user-1',
      AccountStatus.Suspended,
      ' abuse review ',
    );

    expect(result).toBe(updated);
    expect(typeormRepository.update).toHaveBeenCalledTimes(1);
    const [criteria, changes] = typeormRepository.update.mock.calls[0];
    expect(criteria).toEqual({ id: 'user-1', status: AccountStatus.Active });
    expect(changes.status).toBe(AccountStatus.Suspended);
    expect(changes.statusReason).toBe('abuse review');
    expect(changes.statusChangedAt).toBeInstanceOf(Date);
  });

  it('rejects invalid transitions and blank reasons', async () => {
    typeormRepository.findOneBy.mockResolvedValue({
      id: 'user-1',
      status: AccountStatus.Active,
    } as UserEntity);
    await expect(
      repository.transitionStatus('user-1', AccountStatus.Active, 'reason'),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      repository.transitionStatus('user-1', AccountStatus.Suspended, ' '),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(typeormRepository.update).not.toHaveBeenCalled();
  });

  it('returns null when the account does not exist', async () => {
    typeormRepository.findOneBy.mockResolvedValue(null);
    await expect(
      repository.transitionStatus('missing', AccountStatus.Active, 'verified'),
    ).resolves.toBeNull();
  });

  it('rejects a transition lost to a concurrent state change', async () => {
    typeormRepository.findOneBy.mockResolvedValue({
      id: 'user-1',
      status: AccountStatus.Active,
    } as UserEntity);
    typeormRepository.update.mockResolvedValue({
      affected: 0,
      generatedMaps: [],
      raw: [],
    });

    await expect(
      repository.transitionStatus(
        'user-1',
        AccountStatus.Suspended,
        'abuse review',
      ),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});
