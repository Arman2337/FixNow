import { ConflictException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { EntityManager, In, Repository } from 'typeorm';
import { Booking } from '../../bookings/domain/booking.entity';
import { BookingStatus } from '../../../../shared/booking-lifecycle.types';
import { ProviderAvailabilityStatus } from '../../../../shared/provider-availability.types';
import { ProviderAvailabilityEntity } from './provider-availability.entity';

/** Matches CHK_provider_availability_status_expiry: a non-offline status needs an expiry. */
const MAX_STATUS_DURATION_MS = 12 * 60 * 60 * 1000;
const DEFAULT_MAX_CONCURRENT_BOOKINGS = 5;

/** Statuses that occupy a provider. */
const OCCUPYING_STATUSES: BookingStatus[] = [
  BookingStatus.ASSIGNED,
  BookingStatus.EN_ROUTE,
  BookingStatus.IN_PROGRESS,
];

@Injectable()
export class ProviderCapacityService {
  constructor(
    @InjectRepository(ProviderAvailabilityEntity)
    private readonly availabilityRepository: Repository<ProviderAvailabilityEntity>,
    private readonly config?: ConfigService,
  ) {}

  get maxConcurrentBookings(): number {
    const configured = Number(
      this.config?.get<string>('PROVIDER_MAX_CONCURRENT_BOOKINGS'),
    );
    if (!Number.isInteger(configured) || configured < 1) {
      return DEFAULT_MAX_CONCURRENT_BOOKINGS;
    }
    return configured;
  }

  private countActive(
    manager: EntityManager,
    providerId: string,
  ): Promise<number> {
    return manager.getRepository(Booking).count({
      where: { providerId, status: In(OCCUPYING_STATUSES) },
    });
  }

  /**
   * Locks the provider's availability row, so concurrent accepts for the same
   * provider serialise. The lock must be taken before the count: counting first
   * would let two simultaneous accepts both read a count below the limit.
   *
   * The row is not needed afterwards, only held.
   */
  private async lockProvider(
    manager: EntityManager,
    providerId: string,
  ): Promise<void> {
    await manager.getRepository(ProviderAvailabilityEntity).findOne({
      where: { userId: providerId },
      lock: { mode: 'pessimistic_write' },
    });
  }

  /**
   * BUG-008: nothing in the codebase limited how many jobs a provider could hold
   * at once, and `ProviderAvailabilityStatus.Busy` was never assigned by any code
   * path, so the answer was "unbounded".
   *
   * Call inside the same transaction that performs the assignment.
   */
  async assertCanAccept(
    manager: EntityManager,
    providerId: string,
  ): Promise<void> {
    await this.lockProvider(manager, providerId);
    const active = await this.countActive(manager, providerId);
    const limit = this.maxConcurrentBookings;
    if (active >= limit) {
      throw new ConflictException(
        `Provider already has ${active} active bookings (limit ${limit})`,
      );
    }
  }

  /**
   * Keeps availability honest about workload: Busy while the provider is
   * working, back to Online when they are free.
   *
   * Only ever moves a provider between Online and Busy. Someone who
   * deliberately went Offline is left alone, because going Offline is a
   * statement of intent that a finishing job should not override.
   */
  async syncAvailabilityForWorkload(
    manager: EntityManager,
    providerId: string,
  ): Promise<void> {
    await this.lockProvider(manager, providerId);
    const repository = manager.getRepository(ProviderAvailabilityEntity);
    const availability = await repository.findOne({
      where: { userId: providerId },
    });
    // No availability row means the provider never set a status. Matching
    // already excludes them, so there is nothing to reconcile.
    if (!availability) return;

    const active = await this.countActive(manager, providerId);
    const wanted =
      active > 0
        ? ProviderAvailabilityStatus.Busy
        : availability.status === ProviderAvailabilityStatus.Busy
          ? ProviderAvailabilityStatus.Online
          : null;
    if (!wanted || availability.status === wanted) return;

    availability.status = wanted;
    availability.statusExpiresAt = new Date(
      Date.now() + MAX_STATUS_DURATION_MS,
    );
    await repository.save(availability);
  }
}
