import { ConflictException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { EntityManager, Repository } from 'typeorm';
import { Booking } from '../../bookings/domain/booking.entity';
import { ProviderAvailabilityStatus } from '../../../../shared/provider-availability.types';
import { ProviderAvailabilityEntity } from './provider-availability.entity';
import { ProviderCapacityService } from './provider-capacity.service';

interface Repo {
  findOne: jest.Mock;
  count: jest.Mock;
  save: jest.Mock;
}

function managerWith(availability: Repo, bookingCount: number): EntityManager {
  const bookingRepo: Repo = {
    findOne: jest.fn(),
    count: jest.fn().mockResolvedValue(bookingCount),
    save: jest.fn(),
  };
  return {
    getRepository: jest.fn((entity: unknown) =>
      entity === Booking ? bookingRepo : availability,
    ),
  } as unknown as EntityManager;
}

const config = (value?: string) =>
  ({
    get: jest.fn().mockReturnValue(value),
  }) as unknown as ConfigService;

function availabilityRow(
  status: ProviderAvailabilityStatus,
): ProviderAvailabilityEntity {
  return Object.assign(new ProviderAvailabilityEntity(), {
    userId: 'provider-1',
    status,
    statusExpiresAt: null,
  });
}

describe('ProviderCapacityService', () => {
  describe('assertCanAccept', () => {
    it('allows an accept when the provider is under the limit', async () => {
      const availability: Repo = {
        findOne: jest
          .fn()
          .mockResolvedValue(
            availabilityRow(ProviderAvailabilityStatus.Online),
          ),
        count: jest.fn(),
        save: jest.fn(),
      };
      const service = new ProviderCapacityService(
        {} as unknown as Repository<ProviderAvailabilityEntity>,
        config('3'),
      );

      await expect(
        service.assertCanAccept(managerWith(availability, 2), 'provider-1'),
      ).resolves.toBeUndefined();
    });

    it('refuses an accept once the provider is at the limit', async () => {
      const availability: Repo = {
        findOne: jest
          .fn()
          .mockResolvedValue(
            availabilityRow(ProviderAvailabilityStatus.Online),
          ),
        count: jest.fn(),
        save: jest.fn(),
      };
      const service = new ProviderCapacityService(
        {} as unknown as Repository<ProviderAvailabilityEntity>,
        config('3'),
      );

      await expect(
        service.assertCanAccept(managerWith(availability, 3), 'provider-1'),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('locks the availability row before counting', async () => {
      // Without the lock, two concurrent accepts can both read a count below
      // the limit and both assign.
      const order: string[] = [];
      const availability: Repo = {
        findOne: jest.fn(async () => {
          order.push('lock');
          return availabilityRow(ProviderAvailabilityStatus.Online);
        }),
        count: jest.fn(),
        save: jest.fn(),
      };
      const manager = {
        getRepository: jest.fn((entity: unknown) => {
          if (entity === Booking) {
            return {
              count: jest.fn(async () => {
                order.push('count');
                return 0;
              }),
            };
          }
          return availability;
        }),
      } as unknown as EntityManager;

      const service = new ProviderCapacityService(
        {} as unknown as Repository<ProviderAvailabilityEntity>,
        config('3'),
      );
      await service.assertCanAccept(manager, 'provider-1');

      expect(order).toEqual(['lock', 'count']);
    });

    it('defaults to 5 when unset, and ignores nonsense values', () => {
      const repository =
        {} as unknown as Repository<ProviderAvailabilityEntity>;

      expect(
        new ProviderCapacityService(repository, config(undefined))
          .maxConcurrentBookings,
      ).toBe(5);
      expect(
        new ProviderCapacityService(repository, config('not-a-number'))
          .maxConcurrentBookings,
      ).toBe(5);
      expect(
        new ProviderCapacityService(repository, config('0'))
          .maxConcurrentBookings,
      ).toBe(5);
      expect(
        new ProviderCapacityService(repository, config('12'))
          .maxConcurrentBookings,
      ).toBe(12);
    });
  });

  describe('syncAvailabilityForWorkload', () => {
    const repository = {} as unknown as Repository<ProviderAvailabilityEntity>;

    it('moves an online provider to busy when they take work', async () => {
      const row = availabilityRow(ProviderAvailabilityStatus.Online);
      const availability: Repo = {
        findOne: jest.fn().mockResolvedValue(row),
        count: jest.fn(),
        save: jest.fn().mockResolvedValue(row),
      };
      const service = new ProviderCapacityService(repository, config('3'));

      await service.syncAvailabilityForWorkload(
        managerWith(availability, 2),
        'provider-1',
      );

      expect(row.status).toBe(ProviderAvailabilityStatus.Busy);
      // CHK_provider_availability_status_expiry requires an expiry.
      expect(row.statusExpiresAt).toBeInstanceOf(Date);
      expect(availability.save).toHaveBeenCalled();
    });

    it('moves a busy provider back to online when their last job ends', async () => {
      const row = availabilityRow(ProviderAvailabilityStatus.Busy);
      const availability: Repo = {
        findOne: jest.fn().mockResolvedValue(row),
        count: jest.fn(),
        save: jest.fn().mockResolvedValue(row),
      };
      const service = new ProviderCapacityService(repository, config('3'));

      await service.syncAvailabilityForWorkload(
        managerWith(availability, 0),
        'provider-1',
      );

      expect(row.status).toBe(ProviderAvailabilityStatus.Online);
      expect(availability.save).toHaveBeenCalled();
    });

    it('never overrides a provider who deliberately went offline', async () => {
      const row = availabilityRow(ProviderAvailabilityStatus.Offline);
      const availability: Repo = {
        findOne: jest.fn().mockResolvedValue(row),
        count: jest.fn(),
        save: jest.fn().mockResolvedValue(row),
      };
      const service = new ProviderCapacityService(repository, config('3'));

      await service.syncAvailabilityForWorkload(
        managerWith(availability, 0),
        'provider-1',
      );

      expect(row.status).toBe(ProviderAvailabilityStatus.Offline);
      expect(availability.save).not.toHaveBeenCalled();
    });

    it('leaves a provider alone when they have no availability row', async () => {
      const availability: Repo = {
        findOne: jest.fn().mockResolvedValue(null),
        count: jest.fn(),
        save: jest.fn(),
      };
      const service = new ProviderCapacityService(repository, config('3'));

      await expect(
        service.syncAvailabilityForWorkload(
          managerWith(availability, 4),
          'provider-1',
        ),
      ).resolves.toBeUndefined();
      expect(availability.save).not.toHaveBeenCalled();
    });
  });
});
