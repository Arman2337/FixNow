import { NotFoundException } from '@nestjs/common';
import { PushDeviceService } from './push.service';
import { PushPlatform } from './push-device-token.entity';

describe('PushDeviceService', () => {
  let repository: {
    findOne: jest.Mock;
    find: jest.Mock;
    save: jest.Mock;
    create: jest.Mock;
    delete: jest.Mock;
  };
  let service: PushDeviceService;

  const row = (overrides: Record<string, unknown> = {}) => ({
    id: 'device-1',
    userId: 'user-1',
    platform: PushPlatform.Android,
    token: 'a'.repeat(64),
    enabled: true,
    createdAt: new Date('2026-08-24T00:00:00Z'),
    ...overrides,
  });

  beforeEach(() => {
    repository = {
      findOne: jest.fn(),
      find: jest.fn().mockResolvedValue([]),
      save: jest.fn(<T extends object>(entity: T): Promise<T> =>
        Promise.resolve(entity),
      ),
      create: jest.fn((value: Record<string, unknown>) => ({
        ...row(),
        ...value,
      })),
      delete: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    service = new PushDeviceService(
      repository as unknown as ConstructorParameters<
        typeof PushDeviceService
      >[0],
    );
  });

  it('registers a new device with the authenticated owner', async () => {
    repository.findOne.mockResolvedValue(null);
    const result = await service.register('user-1', {
      token: 'b'.repeat(64),
      platform: PushPlatform.Ios,
    });
    expect(repository.create).toHaveBeenCalledWith({
      userId: 'user-1',
      platform: PushPlatform.Ios,
      token: 'b'.repeat(64),
      enabled: true,
    });
    expect(result.id).toBe('device-1');
    expect(result.platform).toBe(PushPlatform.Ios);
    expect(result.createdAt).toBeInstanceOf(Date);
    expect(result).not.toHaveProperty('token');
  });

  it('reassigns an existing installation to the newly signed-in account and re-enables it', async () => {
    const existing = row({ userId: 'previous-user', enabled: false });
    repository.findOne.mockResolvedValue(existing);
    const result = await service.register('new-user', {
      token: 'a'.repeat(64),
      platform: PushPlatform.Web,
    });
    expect(existing.userId).toBe('new-user');
    expect(existing.enabled).toBe(true);
    expect(existing.platform).toBe(PushPlatform.Web);
    expect(result.platform).toBe(PushPlatform.Web);
  });

  it('lists only minimized own devices without tokens', async () => {
    repository.find.mockResolvedValue([
      row(),
      row({ id: 'device-2', platform: PushPlatform.Web }),
    ]);
    const result = await service.list('user-1');
    expect(repository.find).toHaveBeenCalledWith({
      where: { userId: 'user-1' },
      order: { createdAt: 'DESC' },
    });
    expect(result).toHaveLength(2);
    for (const device of result) {
      expect(device).not.toHaveProperty('token');
    }
  });

  it('revokes an owned device', async () => {
    await service.revoke('user-1', 'device-1');
    expect(repository.delete).toHaveBeenCalledWith({
      id: 'device-1',
      userId: 'user-1',
    });
  });

  it('refuses to revoke another account device', async () => {
    repository.delete.mockResolvedValue({ affected: 0 });
    await expect(service.revoke('user-1', 'foreign-device')).rejects.toThrow(
      NotFoundException,
    );
  });

  it('removes provider-reported unregistered tokens', async () => {
    await service.removeUnregistered('c'.repeat(64));
    expect(repository.delete).toHaveBeenCalledWith({
      token: 'c'.repeat(64),
    });
  });
});
