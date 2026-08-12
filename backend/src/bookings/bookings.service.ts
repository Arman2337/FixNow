import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { createHash } from 'crypto';
import { DataSource, EntityManager, QueryFailedError } from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { CreateBookingDto } from './bookings.dto';
import { BookingEvent } from './domain/booking-event.entity';
import { Booking } from './domain/booking.entity';
import { MatchingService } from '../matching/matching.service';
import { LocationService } from '../location/location.service';
import { BookingProjectionService } from '../realtime/booking-projection.service';

export interface BookingHistoryPage {
  bookings: Booking[];
  nextCursor: string | null;
}

interface HistoryCursor {
  createdAt: string;
  id: string;
}

@Injectable()
export class BookingsService {
  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly matchingService: MatchingService,
    private readonly locationService?: LocationService,
    private readonly bookingProjections?: BookingProjectionService,
  ) {}

  async create(
    userId: string,
    input: CreateBookingDto,
    idempotencyKey: string,
  ): Promise<Booking> {
    const normalizedKey = this.validateIdempotencyKey(idempotencyKey);
    const normalizedInput = this.normalizeCreateInput(input);
    const fingerprint = createHash('sha256')
      .update(JSON.stringify(normalizedInput))
      .digest('hex');

    const existing = await this.dataSource.getRepository(Booking).findOneBy({
      customerId: userId,
      idempotencyKey: normalizedKey,
    });
    if (existing) return this.resolveIdempotentReplay(existing, fingerprint);

    try {
      return await this.dataSource.transaction(async (manager) => {
        const bookingRepository = manager.getRepository(Booking);
        const booking = bookingRepository.create({
          customerId: userId,
          providerId: null,
          serviceCategoryId: normalizedInput.serviceCategoryId,
          idempotencyKey: normalizedKey,
          requestFingerprint: fingerprint,
          status: BookingStatus.REQUESTED,
          description: normalizedInput.description,
          locationLat: normalizedInput.locationLat,
          locationLng: normalizedInput.locationLng,
          scheduledAt: normalizedInput.scheduledAt
            ? new Date(normalizedInput.scheduledAt)
            : null,
          assignedAt: null,
          enRouteAt: null,
          startedAt: null,
          completedAt: null,
          cancelledAt: null,
          cancellationReason: null,
          deletedAt: null,
        });
        const saved = await bookingRepository.save(booking);
        await this.appendEvent(
          manager,
          saved,
          userId,
          null,
          BookingStatus.REQUESTED,
          null,
        );
        return saved;
      });
    } catch (error: unknown) {
      if (!this.isUniqueViolation(error)) throw error;
      const concurrent = await this.dataSource
        .getRepository(Booking)
        .findOneByOrFail({
          customerId: userId,
          idempotencyKey: normalizedKey,
        });
      return this.resolveIdempotentReplay(concurrent, fingerprint);
    }
  }

  async acceptBooking(
    bookingId: string,
    providerId: string,
    expectedVersion: number,
  ): Promise<Booking> {
    const candidate = await this.dataSource
      .getRepository(Booking)
      .findOneBy({ id: bookingId });
    if (!candidate) throw new NotFoundException('Booking not found');
    const eligibleProviders = await this.matchingService.findEligibleProviders(
      candidate.locationLat!,
      candidate.locationLng!,
      candidate.serviceCategoryId,
      50,
    );
    if (!eligibleProviders.some(({ providerId: id }) => id === providerId)) {
      throw new ForbiddenException('Provider is not eligible for this booking');
    }
    return this.transition(
      bookingId,
      providerId,
      expectedVersion,
      (booking) => {
        if (booking.customerId === providerId) {
          throw new ForbiddenException(
            'Customers cannot accept their own booking',
          );
        }
        if (booking.status !== BookingStatus.REQUESTED) {
          throw new ConflictException('Booking is no longer available');
        }
        booking.providerId = providerId;
        booking.transitionTo(BookingStatus.ASSIGNED);
      },
    );
  }

  async updateStatus(
    bookingId: string,
    providerId: string,
    status: BookingStatus,
    expectedVersion: number,
  ): Promise<Booking> {
    if (
      ![
        BookingStatus.EN_ROUTE,
        BookingStatus.IN_PROGRESS,
        BookingStatus.COMPLETED,
      ].includes(status)
    ) {
      throw new BadRequestException('Unsupported provider status command');
    }
    const booking = await this.transition(
      bookingId,
      providerId,
      expectedVersion,
      (booking) => {
        if (booking.providerId !== providerId) {
          throw new ForbiddenException('You are not assigned to this booking');
        }
        this.applyDomainTransition(booking, status);
      },
    );
    if (
      status === BookingStatus.IN_PROGRESS ||
      status === BookingStatus.COMPLETED
    ) {
      await this.locationService?.invalidateBooking(bookingId);
    }
    await this.bookingProjections?.publishBooking(booking);
    return booking;
  }

  async cancelBooking(
    bookingId: string,
    userId: string,
    reason: string,
    expectedVersion: number,
  ): Promise<Booking> {
    const normalizedReason = reason.trim();
    const booking = await this.transition(
      bookingId,
      userId,
      expectedVersion,
      (booking) => {
        const isCustomer = booking.customerId === userId;
        const isProvider = booking.providerId === userId;
        if (!isCustomer && !isProvider) {
          throw new ForbiddenException(
            'You are not authorized to cancel this booking',
          );
        }
        const allowed = isCustomer
          ? [BookingStatus.REQUESTED, BookingStatus.ASSIGNED]
          : [BookingStatus.ASSIGNED, BookingStatus.EN_ROUTE];
        if (!allowed.includes(booking.status)) {
          throw new ConflictException(
            'Booking cannot be cancelled in its current state',
          );
        }
        this.applyDomainTransition(
          booking,
          BookingStatus.CANCELLED,
          normalizedReason,
        );
      },
      normalizedReason,
    );
    await this.locationService?.invalidateBooking(bookingId);
    await this.bookingProjections?.publishUnavailable(booking);
    return booking;
  }

  async getBookingHistory(
    userId: string,
    limit = 20,
    cursor?: string,
  ): Promise<BookingHistoryPage> {
    const boundedLimit = Math.min(Math.max(Math.trunc(limit), 1), 100);
    const decodedCursor = cursor ? this.decodeCursor(cursor) : null;
    const query = this.dataSource
      .getRepository(Booking)
      .createQueryBuilder('booking')
      .where('(booking.customerId = :userId OR booking.providerId = :userId)', {
        userId,
      })
      .orderBy('booking.createdAt', 'DESC')
      .addOrderBy('booking.id', 'DESC')
      .take(boundedLimit + 1);

    if (decodedCursor) {
      query.andWhere(
        '(booking.createdAt < :cursorDate OR (booking.createdAt = :cursorDate AND booking.id < :cursorId))',
        {
          cursorDate: decodedCursor.createdAt,
          cursorId: decodedCursor.id,
        },
      );
    }

    const rows = await query.getMany();
    const hasMore = rows.length > boundedLimit;
    const page = rows.slice(0, boundedLimit).map((booking) =>
      booking.providerId === userId && booking.customerId !== userId
        ? Object.assign(new Booking(), booking, {
            locationLat: null,
            locationLng: null,
          })
        : booking,
    );
    const last = page.at(-1);
    return {
      bookings: page,
      nextCursor:
        hasMore && last
          ? this.encodeCursor({
              createdAt: last.createdAt.toISOString(),
              id: last.id,
            })
          : null,
    };
  }

  private async transition(
    bookingId: string,
    actorUserId: string,
    expectedVersion: number,
    mutate: (booking: Booking) => void,
    reason: string | null = null,
  ): Promise<Booking> {
    if (!Number.isInteger(expectedVersion) || expectedVersion < 1) {
      throw new BadRequestException(
        'Expected version must be a positive integer',
      );
    }
    return this.dataSource.transaction(async (manager) => {
      const repository = manager.getRepository(Booking);
      const booking = await repository.findOneBy({ id: bookingId });
      if (!booking) throw new NotFoundException('Booking not found');
      if (booking.version !== expectedVersion) {
        throw new ConflictException('Booking version is stale');
      }

      const fromStatus = booking.status;
      mutate(booking);
      const result = await repository
        .createQueryBuilder()
        .update(Booking)
        .set({
          providerId: booking.providerId,
          status: booking.status,
          assignedAt: booking.assignedAt,
          enRouteAt: booking.enRouteAt,
          startedAt: booking.startedAt,
          completedAt: booking.completedAt,
          cancelledAt: booking.cancelledAt,
          cancellationReason: booking.cancellationReason,
          version: () => '"version" + 1',
        })
        .where('id = :id AND version = :expectedVersion', {
          id: bookingId,
          expectedVersion,
        })
        .execute();
      if (result.affected !== 1) {
        throw new ConflictException('Booking was modified concurrently');
      }

      booking.version = expectedVersion + 1;
      await this.appendEvent(
        manager,
        booking,
        actorUserId,
        fromStatus,
        booking.status,
        reason,
      );
      return repository.findOneByOrFail({ id: bookingId });
    });
  }

  private async appendEvent(
    manager: EntityManager,
    booking: Booking,
    actorUserId: string,
    fromStatus: BookingStatus | null,
    toStatus: BookingStatus,
    reason: string | null,
  ): Promise<void> {
    const repository = manager.getRepository(BookingEvent);
    await repository.save(
      repository.create({
        bookingId: booking.id,
        actorUserId,
        fromStatus,
        toStatus,
        reason,
        bookingVersion: booking.version,
      }),
    );
  }

  private applyDomainTransition(
    booking: Booking,
    status: BookingStatus,
    reason?: string,
  ): void {
    try {
      booking.transitionTo(status, reason);
    } catch (error: unknown) {
      throw new ConflictException(
        error instanceof Error ? error.message : 'Invalid booking transition',
      );
    }
  }

  private normalizeCreateInput(input: CreateBookingDto) {
    const description = input.description.trim();
    const scheduledAt = input.scheduledAt
      ? new Date(input.scheduledAt).toISOString()
      : null;
    if (scheduledAt && new Date(scheduledAt).getTime() <= Date.now()) {
      throw new BadRequestException('Scheduled time must be in the future');
    }
    return {
      serviceCategoryId: input.serviceCategoryId,
      description,
      locationLat: Number(input.locationLat.toFixed(7)),
      locationLng: Number(input.locationLng.toFixed(7)),
      scheduledAt,
    };
  }

  private validateIdempotencyKey(value: string): string {
    const key = value?.trim();
    if (!/^[A-Za-z0-9._:-]{8,128}$/.test(key)) {
      throw new BadRequestException(
        'Idempotency-Key must contain 8-128 safe characters',
      );
    }
    return key;
  }

  private resolveIdempotentReplay(
    booking: Booking,
    fingerprint: string,
  ): Booking {
    if (booking.requestFingerprint !== fingerprint) {
      throw new ConflictException(
        'Idempotency key was already used with a different request',
      );
    }
    return booking;
  }

  private isUniqueViolation(error: unknown): boolean {
    if (!(error instanceof QueryFailedError)) return false;
    const driverError = error.driverError as { code?: unknown };
    return driverError.code === '23505';
  }

  private encodeCursor(cursor: HistoryCursor): string {
    return Buffer.from(JSON.stringify(cursor)).toString('base64url');
  }

  private decodeCursor(value: string): HistoryCursor {
    try {
      const parsed = JSON.parse(
        Buffer.from(value, 'base64url').toString('utf8'),
      ) as Partial<HistoryCursor>;
      if (
        typeof parsed.createdAt !== 'string' ||
        !Number.isFinite(Date.parse(parsed.createdAt)) ||
        typeof parsed.id !== 'string' ||
        !/^[0-9a-f-]{36}$/i.test(parsed.id)
      ) {
        throw new Error('Invalid cursor fields');
      }
      return { createdAt: parsed.createdAt, id: parsed.id };
    } catch {
      throw new BadRequestException('Invalid booking history cursor');
    }
  }
}
