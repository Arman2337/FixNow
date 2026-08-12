import { CACHE_MANAGER } from '@nestjs/cache-manager';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Cache } from 'cache-manager';
import { DataSource, In } from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { ProviderAvailabilityStatus } from '../../../shared/provider-availability.types';
import type { AuthorizationPrincipal } from '../common/authorization/authorization.types';
import { Booking } from '../bookings/domain/booking.entity';
import { ProviderAvailabilityEntity } from '../providers/availability/provider-availability.entity';
import type {
  CachedProviderLocation,
  LocationConsentUpdate,
  ProviderLocationUpdate,
  ProviderPresenceUpdate,
} from './location.types';

interface ConsentEvidence {
  readonly granted: true;
  readonly noticeVersion: string;
  readonly grantedAt: string;
}

@Injectable()
export class LocationService {
  constructor(
    private readonly dataSource: DataSource,
    @Inject(CACHE_MANAGER) private readonly cache: Cache,
    private readonly config: ConfigService,
  ) {}

  async updatePresence(
    principal: AuthorizationPrincipal,
    update: ProviderPresenceUpdate,
    now = new Date(),
  ): Promise<{ online: boolean; expiresAt: string | null }> {
    this.assertProvider(principal);
    if (typeof update.online !== 'boolean')
      throw new BadRequestException('Invalid presence update');
    if (!update.online) {
      await this.cache.del(this.presenceKey(principal.userId));
      await this.invalidateProviderLocations(principal.userId);
      return { online: false, expiresAt: null };
    }
    const availability = await this.dataSource
      .getRepository(ProviderAvailabilityEntity)
      .findOne({ where: { userId: principal.userId } });
    const available =
      availability &&
      availability.status !== ProviderAvailabilityStatus.Offline &&
      !!availability.statusExpiresAt &&
      availability.statusExpiresAt.getTime() > now.getTime();
    if (!available)
      throw new ForbiddenException('Online availability required');
    const ttl = this.numberConfig('LOCATION_PRESENCE_TTL_MS', 45_000);
    await this.cache.set(
      this.presenceKey(principal.userId),
      { online: true, refreshedAt: now.toISOString() },
      ttl,
    );
    return {
      online: true,
      expiresAt: new Date(now.getTime() + ttl).toISOString(),
    };
  }

  async updateConsent(
    principal: AuthorizationPrincipal,
    update: LocationConsentUpdate,
    now = new Date(),
  ): Promise<{ granted: boolean }> {
    this.assertProvider(principal);
    this.assertUuid(update.bookingId);
    if (
      typeof update.granted !== 'boolean' ||
      typeof update.noticeVersion !== 'string' ||
      update.noticeVersion !==
        this.config.get<string>('LOCATION_NOTICE_VERSION', '2026-08-13')
    ) {
      throw new BadRequestException('Invalid location consent');
    }
    await this.requireTrackedBooking(update.bookingId, principal.userId);
    if (!update.granted) {
      await this.cache.del(this.consentKey(update.bookingId));
      await this.cache.del(this.locationKey(update.bookingId));
      return { granted: false };
    }
    const evidence: ConsentEvidence = {
      granted: true,
      noticeVersion: update.noticeVersion,
      grantedAt: now.toISOString(),
    };
    await this.cache.set(
      this.consentKey(update.bookingId),
      evidence,
      this.numberConfig('LOCATION_CONSENT_TTL_MS', 43_200_000),
    );
    return { granted: true };
  }

  async ingestLocation(
    principal: AuthorizationPrincipal,
    update: ProviderLocationUpdate,
    now = new Date(),
  ): Promise<{ sequence: number; receivedAt: string; staleAt: string }> {
    this.assertProvider(principal);
    this.validateLocation(update, now);
    await this.requireTrackedBooking(update.bookingId, principal.userId);
    if (!(await this.cache.get(this.presenceKey(principal.userId))))
      throw new ForbiddenException('Current provider presence required');
    const consent = await this.cache.get<ConsentEvidence>(
      this.consentKey(update.bookingId),
    );
    if (!consent?.granted)
      throw new ForbiddenException('Location consent required');
    const key = this.locationKey(update.bookingId);
    const previous = await this.cache.get<CachedProviderLocation>(key);
    if (previous && update.sequence <= previous.sequence)
      throw new ConflictException('Location sequence is stale');
    const interval = this.numberConfig('LOCATION_UPDATE_INTERVAL_MS', 10_000);
    if (
      previous &&
      now.getTime() - new Date(previous.receivedAt).getTime() < interval
    )
      throw new ConflictException('Location update rate exceeded');
    const receivedAt = now.toISOString();
    const location: CachedProviderLocation = {
      providerId: principal.userId,
      bookingId: update.bookingId,
      sequence: update.sequence,
      capturedAt: new Date(update.capturedAt).toISOString(),
      receivedAt,
      latitude: update.latitude,
      longitude: update.longitude,
      accuracyMeters: update.accuracyMeters,
    };
    const ttl = this.numberConfig('LOCATION_CACHE_TTL_MS', 60_000);
    await this.cache.set(key, location, ttl);
    return {
      sequence: update.sequence,
      receivedAt,
      staleAt: new Date(now.getTime() + ttl).toISOString(),
    };
  }

  async invalidateBooking(bookingId: string): Promise<void> {
    this.assertUuid(bookingId);
    await Promise.all([
      this.cache.del(this.consentKey(bookingId)),
      this.cache.del(this.locationKey(bookingId)),
    ]);
  }

  async getLatestAuthorized(
    principal: AuthorizationPrincipal,
    bookingId: string,
  ): Promise<CachedProviderLocation | null> {
    this.assertProvider(principal);
    await this.requireTrackedBooking(bookingId, principal.userId);
    return (
      (await this.cache.get<CachedProviderLocation>(
        this.locationKey(bookingId),
      )) ?? null
    );
  }

  private async invalidateProviderLocations(providerId: string): Promise<void> {
    const bookings = await this.dataSource.getRepository(Booking).find({
      select: { id: true },
      where: {
        providerId,
        status: In([BookingStatus.EN_ROUTE, BookingStatus.IN_PROGRESS]),
      },
    });
    await Promise.all(bookings.map(({ id }) => this.invalidateBooking(id)));
  }

  private async requireTrackedBooking(
    bookingId: string,
    providerId: string,
  ): Promise<void> {
    const booking = await this.dataSource
      .getRepository(Booking)
      .findOne({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException('Booking not found');
    if (
      booking.providerId !== providerId ||
      booking.status !== BookingStatus.EN_ROUTE
    )
      throw new ForbiddenException('Active travel booking required');
  }

  private validateLocation(update: ProviderLocationUpdate, now: Date): void {
    this.assertUuid(update.bookingId);
    if (!Number.isSafeInteger(update.sequence) || update.sequence < 0)
      throw new BadRequestException('Invalid location sequence');
    if (
      !Number.isFinite(update.latitude) ||
      update.latitude < -90 ||
      update.latitude > 90 ||
      !Number.isFinite(update.longitude) ||
      update.longitude < -180 ||
      update.longitude > 180
    )
      throw new BadRequestException('Invalid coordinates');
    const maxAccuracy = this.numberConfig('LOCATION_MAX_ACCURACY_METERS', 100);
    if (
      !Number.isFinite(update.accuracyMeters) ||
      update.accuracyMeters <= 0 ||
      update.accuracyMeters > maxAccuracy
    )
      throw new BadRequestException('Location accuracy is outside policy');
    const capturedAt = new Date(update.capturedAt);
    const age = now.getTime() - capturedAt.getTime();
    const staleAfter = this.numberConfig('LOCATION_STALE_AFTER_MS', 60_000);
    if (
      !Number.isFinite(capturedAt.getTime()) ||
      age > staleAfter ||
      age < -10_000
    )
      throw new ConflictException('Location update is stale');
  }

  private assertProvider(principal: AuthorizationPrincipal): void {
    if (!principal.roles.includes('verified_provider'))
      throw new ForbiddenException('Verified provider access required');
  }

  private assertUuid(value: string): void {
    if (
      typeof value !== 'string' ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        value,
      )
    )
      throw new BadRequestException('Invalid booking identifier');
  }

  private numberConfig(key: string, fallback: number): number {
    return this.config.get<number>(key, fallback);
  }

  private presenceKey(providerId: string): string {
    return `location:v1:presence:${providerId}`;
  }
  private consentKey(bookingId: string): string {
    return `location:v1:consent:${bookingId}`;
  }
  private locationKey(bookingId: string): string {
    return `location:v1:latest:${bookingId}`;
  }
}
