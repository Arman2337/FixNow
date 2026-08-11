import { ConflictException, ForbiddenException } from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';
import { ProviderAvailabilityStatus } from '../../../../shared/provider-availability.types';
import { ProviderApplicationEntity } from '../provider-application.entity';
import { ProviderOnboardingStatus } from '../provider-onboarding-status';
import { ProviderAvailabilityEntity } from './provider-availability.entity';
import { ProviderAvailabilityResponseDto } from './provider-availability.dto';
import { ProviderAvailabilityService } from './provider-availability.service';

describe('ProviderAvailabilityService', () => {
  const userId = '00000000-0000-4000-8000-000000000001';
  const findApplication = jest.fn();
  const findAvailability = jest.fn();
  const createAvailability = jest.fn(
    (value: Partial<ProviderAvailabilityEntity>) =>
      ({
        id: 'availability-1',
        createdAt: new Date('2026-08-11T00:00:00Z'),
        updatedAt: new Date('2026-08-11T00:00:00Z'),
        ...value,
      }) as ProviderAvailabilityEntity,
  );
  const saveAvailability = jest.fn((value: ProviderAvailabilityEntity) =>
    Promise.resolve(value),
  );
  const repositories = new Map<unknown, unknown>();
  const manager = {
    getRepository: jest.fn((entity: unknown): unknown =>
      repositories.get(entity),
    ),
  };
  let service: ProviderAvailabilityService;

  beforeEach(() => {
    jest.clearAllMocks();
    repositories.set(ProviderApplicationEntity, { findOne: findApplication });
    repositories.set(ProviderAvailabilityEntity, {
      findOne: findAvailability,
      create: createAvailability,
      save: saveAvailability,
    });
    findApplication.mockResolvedValue({
      status: ProviderOnboardingStatus.Approved,
    });
    findAvailability.mockResolvedValue(null);
    const dataSource = {
      manager,
      getRepository: manager.getRepository,
      transaction: jest.fn(
        (
          work: (
            transactionManager: EntityManager,
          ) => Promise<ProviderAvailabilityResponseDto>,
        ) => work(manager as unknown as EntityManager),
      ),
    } as unknown as DataSource;
    service = new ProviderAvailabilityService(dataSource);
  });

  it('stores a valid IANA-zone schedule and dated exception', async () => {
    const result = await service.updateSchedule(userId, {
      timeZone: 'Asia/Kolkata',
      weeklyRules: [
        { dayOfWeek: 1, intervals: [{ startMinute: 540, endMinute: 1020 }] },
      ],
      exceptions: [{ date: '2026-08-15', unavailable: true, intervals: [] }],
      expectedVersion: 0,
    });
    expect(result.version).toBe(1);
    expect(saveAvailability).toHaveBeenCalledWith(
      expect.objectContaining({ timeZone: 'Asia/Kolkata' }),
    );
  });

  it.each([
    [
      'invalid time zone',
      {
        timeZone: 'Mars/Olympus',
        weeklyRules: [],
        exceptions: [],
        expectedVersion: 0,
      },
    ],
    [
      'overlap',
      {
        timeZone: 'UTC',
        weeklyRules: [
          {
            dayOfWeek: 1,
            intervals: [
              { startMinute: 60, endMinute: 120 },
              { startMinute: 90, endMinute: 180 },
            ],
          },
        ],
        exceptions: [],
        expectedVersion: 0,
      },
    ],
    [
      'duplicate day',
      {
        timeZone: 'UTC',
        weeklyRules: [
          { dayOfWeek: 1, intervals: [] },
          { dayOfWeek: 1, intervals: [] },
        ],
        exceptions: [],
        expectedVersion: 0,
      },
    ],
    [
      'invalid exception date',
      {
        timeZone: 'UTC',
        weeklyRules: [],
        exceptions: [{ date: '2026-02-31', unavailable: true, intervals: [] }],
        expectedVersion: 0,
      },
    ],
    [
      'out-of-range interval',
      {
        timeZone: 'UTC',
        weeklyRules: [
          { dayOfWeek: 1, intervals: [{ startMinute: -1, endMinute: 60 }] },
        ],
        exceptions: [],
        expectedVersion: 0,
      },
    ],
  ])('rejects %s schedule conflicts', async (_name, dto) => {
    await expect(service.updateSchedule(userId, dto)).rejects.toBeInstanceOf(
      ConflictException,
    );
  });

  it('rejects providers whose verification is no longer approved', async () => {
    findApplication.mockResolvedValue({
      status: ProviderOnboardingStatus.UnderReview,
    });
    await expect(
      service.updateSchedule(userId, {
        timeZone: 'UTC',
        weeklyRules: [],
        exceptions: [],
        expectedVersion: 0,
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('rejects a stale version without saving', async () => {
    findAvailability.mockResolvedValue({ userId, version: 3 });
    await expect(
      service.updateSchedule(userId, {
        timeZone: 'UTC',
        weeklyRules: [],
        exceptions: [],
        expectedVersion: 2,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(saveAvailability).not.toHaveBeenCalled();
  });

  it('requires online status to expire within twelve hours', async () => {
    await expect(
      service.updateStatus(userId, {
        status: ProviderAvailabilityStatus.Online,
        expiresAt: 'not-a-date',
        expectedVersion: 0,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
    await expect(
      service.updateStatus(userId, {
        status: ProviderAvailabilityStatus.Online,
        expectedVersion: 0,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
    const expiresAt = new Date(Date.now() + 60_000).toISOString();
    await expect(
      service.updateStatus(userId, {
        status: ProviderAvailabilityStatus.Online,
        expiresAt,
        expectedVersion: 0,
      }),
    ).resolves.toEqual(
      expect.objectContaining({ status: 'online', version: 1 }),
    );
  });

  it('reports an expired transient status as offline', async () => {
    findAvailability.mockResolvedValue({
      id: 'availability-1',
      userId,
      timeZone: 'UTC',
      weeklyRules: [],
      exceptions: [],
      status: ProviderAvailabilityStatus.Busy,
      statusExpiresAt: new Date(Date.now() - 1),
      version: 2,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await expect(service.getOwn(userId)).resolves.toEqual(
      expect.objectContaining({
        status: ProviderAvailabilityStatus.Offline,
        statusExpiresAt: null,
      }),
    );
  });
});
