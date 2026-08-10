import { AuthAuditEventEntity } from '../auth/auth-audit-event.entity';
import { CustomerProfileEntity } from './customer-profile.entity';
import { CustomerProfileService } from './customer-profile.service';
import type { DataSource, EntityManager } from 'typeorm';

describe('CustomerProfileService', () => {
  const manager = {
    findOneBy: jest.fn(),
    create: jest.fn((_entity, value: object) => ({ ...value })),
    save: jest.fn((value: object) => Promise.resolve(value)),
  };
  const dataSource = {
    transaction: jest.fn((work: (value: EntityManager) => unknown) =>
      Promise.resolve(work(manager as unknown as EntityManager)),
    ),
  };
  const service = new CustomerProfileService(
    dataSource as unknown as DataSource,
  );

  beforeEach(() => jest.clearAllMocks());

  it('returns an empty own profile and audits without profile values', async () => {
    manager.findOneBy.mockResolvedValue(null);

    await expect(service.read('user-1')).resolves.toEqual({
      displayName: null,
    });
    expect(manager.findOneBy).toHaveBeenCalledWith(CustomerProfileEntity, {
      userId: 'user-1',
    });
    expect(manager.create).toHaveBeenCalledWith(AuthAuditEventEntity, {
      userId: 'user-1',
      eventType: 'customer_profile.read',
      outcome: 'success',
    });
  });

  it('upserts only the selected own profile and emits value-free audit data', async () => {
    manager.findOneBy.mockResolvedValue(null);

    await expect(service.update('user-1', 'Ada')).resolves.toEqual({
      displayName: 'Ada',
    });
    expect(manager.create).toHaveBeenCalledWith(CustomerProfileEntity, {
      userId: 'user-1',
    });
    expect(manager.create).toHaveBeenCalledWith(AuthAuditEventEntity, {
      userId: 'user-1',
      eventType: 'customer_profile.update',
      outcome: 'success',
    });
    const auditCall = manager.create.mock.calls.find(
      ([entity]) => entity === AuthAuditEventEntity,
    );
    expect(JSON.stringify(auditCall)).not.toContain('Ada');
  });
});
