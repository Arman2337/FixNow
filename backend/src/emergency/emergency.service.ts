import {
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { Booking } from '../bookings/domain/booking.entity';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { BookingEvent } from '../bookings/domain/booking-event.entity';
import { CreateBookingDto } from '../bookings/bookings.dto';
import { BookingsService } from '../bookings/bookings.service';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { MatchingService } from '../matching/matching.service';
import {
  DomainNotificationService,
  EMERGENCY_NOTIFICATION_TEMPLATES,
} from '../notifications/domain/domain-notification.service';
import { TrustService } from '../trust/trust.service';
import { EmergencyDispatch } from './emergency-dispatch.entity';
import {
  EMERGENCY_FALLBACK_GUIDANCE,
  EMERGENCY_POLICY_V1,
} from './emergency-policy';

const ACTIVE_DISPATCH_STATUSES = [
  BookingStatus.REQUESTED,
  BookingStatus.ASSIGNED,
  BookingStatus.EN_ROUTE,
  BookingStatus.IN_PROGRESS,
];

/**
 * FN-063 priority dispatch over ordinary bookings, exactly as approved in
 * docs/safety/emergency-dispatch-policy-v1.md. The booking lifecycle is
 * never bypassed; this service adds eligibility confirmation, abuse
 * controls, escalation waves, audit events, and honest fallback states.
 */
@Injectable()
export class EmergencyService implements OnModuleInit, OnModuleDestroy {
  private timer: NodeJS.Timeout | null = null;

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly bookings: BookingsService,
    private readonly matching: MatchingService,
    private readonly notifications: DomainNotificationService,
    private readonly trust: TrustService,
  ) {}

  onModuleInit(): void {
    this.timer = setInterval(() => void this.scanSafely(), 30_000);
    this.timer.unref?.();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  /**
   * Two-step deliberate creation (policy §3): the client collects details on
   * one screen and posts them with an explicit confirm action here. Abuse
   * controls run BEFORE any booking or push exists.
   */
  async createEmergency(
    customerId: string,
    input: CreateBookingDto,
    idempotencyKey: string,
  ): Promise<EmergencyCreationResult> {
    const category = await this.dataSource
      .getRepository(ServiceCategoryEntity)
      .findOneBy({ id: input.serviceCategoryId });
    if (!category || !category.isActive || !category.isEmergency) {
      throw new ConflictException(
        'This service is not an approved emergency category',
      );
    }

    await this.assertWithinAbuseLimits(customerId);

    const booking = await this.bookings.create(
      customerId,
      input,
      idempotencyKey,
    );

    const dispatches = this.dataSource.getRepository(EmergencyDispatch);
    let dispatch = await dispatches.findOneBy({ bookingId: booking.id });
    if (!dispatch) {
      dispatch = await dispatches.save(
        dispatches.create({ bookingId: booking.id, currentWave: 0 }),
      );
      // Self-healing note (policy §4 atomicity): a crash between booking
      // commit and this insert is covered because the wave scanner only
      // escalates dispatches that exist, and the status endpoint treats a
      // missing row as wave 0 for any emergency-category booking.
    }

    await this.audit(booking, customerId, 'emergency: request created');

    // Best-effort: repeat-use patterns surface for human review (policy §6).
    try {
      const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60_000);
      const used = await this.dataSource
        .getRepository(EmergencyDispatch)
        .createQueryBuilder('dispatch')
        .innerJoin(Booking, 'booking', 'booking.id = dispatch.booking_id')
        .where('booking.customer_id = :customerId', { customerId })
        .andWhere('dispatch.created_at > :weekAgo', { weekAgo })
        .getCount();
      await this.trust.recordEmergencyFrequencySignal(customerId, used);
    } catch {
      // Signal failures never fail an emergency.
    }

    const eligibleCount = await this.runWave(booking, dispatch, 1);
    return {
      bookingId: booking.id,
      status: booking.status,
      currentWave: 1,
      fallbackRequired: false,
      guidance: null,
      eligibleCount,
    };
  }

  /** Participant-visible dispatch state (FR-EMG-004 honest outcomes). */
  async getStatus(
    bookingId: string,
    requesterId: string,
  ): Promise<EmergencyStatusResult> {
    const booking = await this.dataSource
      .getRepository(Booking)
      .findOneBy({ id: bookingId });
    if (!booking) throw new NotFoundException('Emergency request not found');
    if (
      booking.customerId !== requesterId &&
      booking.providerId !== requesterId
    ) {
      throw new NotFoundException('Emergency request not found');
    }

    const dispatch = await this.dataSource
      .getRepository(EmergencyDispatch)
      .findOneBy({ bookingId });
    const currentWave = dispatch?.currentWave ?? 0;
    const unassignedFallback =
      booking.status === BookingStatus.REQUESTED && currentWave >= 3;

    return {
      bookingId,
      status: booking.status,
      currentWave,
      fallbackRequired: unassignedFallback,
      guidance: unassignedFallback ? EMERGENCY_FALLBACK_GUIDANCE : null,
    };
  }

  /** Ops oversight listing (policy §9): every live dispatch with its wave. */
  async listActiveDispatches(): Promise<
    Array<{
      bookingId: string;
      customerId: string;
      categoryName: string | null;
      status: BookingStatus;
      currentWave: number;
      lastEscalatedAt: Date | null;
      createdAt: Date;
    }>
  > {
    const rows = await this.dataSource
      .getRepository(EmergencyDispatch)
      .createQueryBuilder('dispatch')
      .innerJoin(Booking, 'booking', 'booking.id = dispatch.booking_id')
      .leftJoin(
        ServiceCategoryEntity,
        'category',
        'category.id = booking.service_category_id',
      )
      .where('booking.status IN (:...statuses)', {
        statuses: ACTIVE_DISPATCH_STATUSES,
      })
      .orderBy('dispatch.created_at', 'DESC')
      .take(100)
      .select([
        'dispatch.booking_id AS booking_id',
        'booking.customer_id AS customer_id',
        'category.name AS category_name',
        'booking.status AS status',
        'dispatch.current_wave AS current_wave',
        'dispatch.last_escalated_at AS last_escalated_at',
        'dispatch.created_at AS created_at',
      ])
      .getRawMany<{
        booking_id: string;
        customer_id: string;
        category_name: string | null;
        status: BookingStatus;
        current_wave: number;
        last_escalated_at: Date | string | null;
        created_at: Date | string;
      }>();
    return rows.map((row) => ({
      bookingId: row.booking_id,
      customerId: row.customer_id,
      categoryName: row.category_name ?? null,
      status: row.status,
      currentWave: Number(row.current_wave),
      lastEscalatedAt: row.last_escalated_at
        ? new Date(row.last_escalated_at)
        : null,
      createdAt: new Date(row.created_at),
    }));
  }

  /**
   * Escalation tick (policy §5). Public + injectable clock for tests. Waves
   * never touch non-emergency bookings, terminal states, or assigned jobs —
   * the moment acceptance wins, status leaves REQUESTED and waves no-op.
   */
  async scanOnce(now = new Date()): Promise<number> {
    const candidates = await this.dataSource
      .getRepository(EmergencyDispatch)
      .createQueryBuilder('dispatch')
      .innerJoin(Booking, 'booking', 'booking.id = dispatch.booking_id')
      .innerJoin(
        ServiceCategoryEntity,
        'category',
        'category.id = booking.service_category_id',
      )
      .where('booking.status = :status', { status: BookingStatus.REQUESTED })
      .andWhere('booking.deleted_at IS NULL')
      .andWhere('category.is_emergency = true')
      .andWhere('category.is_active = true')
      .andWhere('dispatch.current_wave BETWEEN 1 AND 2')
      .take(EMERGENCY_POLICY_V1.fanOutCap)
      .select([
        'dispatch.booking_id AS booking_id',
        'dispatch.current_wave AS current_wave',
        'dispatch.last_escalated_at AS last_escalated_at',
        'dispatch.created_at AS created_at',
      ])
      .addSelect([
        'booking.location_lat AS location_lat',
        'booking.location_lng AS location_lng',
        'booking.service_category_id AS category_id',
        'booking.customer_id AS customer_id',
        'booking.version AS version',
      ])
      .getRawMany<{
        booking_id: string;
        current_wave: number;
        last_escalated_at: Date | string | null;
        created_at: Date | string;
        location_lat: number | string;
        location_lng: number | string;
        category_id: string;
        customer_id: string;
        version: number | string;
      }>();

    let waves = 0;
    for (const row of candidates) {
      const currentWave = Number(row.current_wave);
      const reference = new Date(row.last_escalated_at ?? row.created_at);
      const nextWave = currentWave + 1;
      const thresholdMinutes =
        nextWave === 2
          ? EMERGENCY_POLICY_V1.wave2AfterMinutes
          : EMERGENCY_POLICY_V1.wave3AfterMinutes;
      if (now.getTime() - reference.getTime() < thresholdMinutes * 60_000) {
        continue;
      }
      const booking = new Booking();
      booking.id = row.booking_id;
      booking.customerId = row.customer_id;
      booking.locationLat = Number(row.location_lat);
      booking.locationLng = Number(row.location_lng);
      booking.serviceCategoryId = row.category_id;
      booking.status = BookingStatus.REQUESTED;
      booking.version = Number(row.version);

      const dispatch = new EmergencyDispatch();
      dispatch.bookingId = row.booking_id;
      dispatch.currentWave = currentWave;
      dispatch.lastEscalatedAt = reference;

      await this.runWave(booking, dispatch, nextWave);
      waves += 1;
    }
    return waves;
  }

  /**
   * One fan-out wave: radius widening on wave 2 (policy §5), quiet-hour
   * override always (policy §8), permanent dedupe keys per wave+provider so
   * repeated ticks never double-push.
   */
  private async runWave(
    booking: Booking,
    dispatch: EmergencyDispatch,
    wave: number,
  ): Promise<number> {
    const eligible = await this.matching.findEligibleProviders(
      booking.locationLat!,
      booking.locationLng!,
      booking.serviceCategoryId,
      EMERGENCY_POLICY_V1.fanOutCap,
      wave >= 2 ? EMERGENCY_POLICY_V1.radiusMultiplierWave2 : 1,
    );

    for (const { providerId } of eligible) {
      try {
        await this.notifications.send(
          providerId,
          'provider:EMERGENCY_REQUEST',
          `emergency:${booking.id}:w${wave}:${providerId}`,
          EMERGENCY_NOTIFICATION_TEMPLATES['provider:EMERGENCY_REQUEST'],
          booking.id,
          { bypassQuietHours: true },
        );
      } catch {
        // Single-attempt per send; delivery records capture failures.
      }
    }

    const dispatches = this.dataSource.getRepository(EmergencyDispatch);
    const existing = await dispatches.findOneBy({ bookingId: booking.id });
    if (existing) {
      existing.currentWave = Math.max(existing.currentWave, wave);
      existing.lastEscalatedAt = new Date();
      existing.waveHistory = [
        ...existing.waveHistory,
        { wave, at: new Date().toISOString(), eligibleCount: eligible.length },
      ];
      await dispatches.save(existing);
      await this.audit(
        booking,
        booking.customerId,
        `emergency: wave ${wave} dispatched to ${eligible.length} providers`,
      );
    }
    return eligible.length;
  }

  /**
   * Policy §6 limits. A cooldown waiver applies when the previous emergency
   * ended CANCELLED with a provider attached (the provider walked away), so
   * a stranded customer can immediately re-dispatch (policy §7 row 4).
   */
  private async assertWithinAbuseLimits(customerId: string): Promise<void> {
    const dispatches = this.dataSource.getRepository(EmergencyDispatch);
    const recent = await dispatches
      .createQueryBuilder('dispatch')
      .innerJoin(Booking, 'booking', 'booking.id = dispatch.booking_id')
      .where('booking.customer_id = :customerId', { customerId })
      .orderBy('dispatch.created_at', 'DESC')
      .take(10)
      .select([
        'dispatch.booking_id AS booking_id',
        'dispatch.created_at AS created_at',
        'booking.status AS status',
        'booking.provider_id AS provider_id',
      ])
      .getRawMany<{
        booking_id: string;
        created_at: Date | string;
        status: BookingStatus;
        provider_id: string | null;
      }>();

    const active = recent.find((row) =>
      ACTIVE_DISPATCH_STATUSES.includes(row.status),
    );
    if (active) {
      throw new ConflictException(
        'You already have an active emergency request. Cancel it before creating another.',
      );
    }

    const newest = recent[0];
    if (newest) {
      const minutesSince =
        (Date.now() - new Date(newest.created_at).getTime()) / 60_000;
      const providerWalkedAway =
        newest.status === BookingStatus.CANCELLED && !!newest.provider_id;
      if (
        minutesSince < EMERGENCY_POLICY_V1.cooldownMinutes &&
        !providerWalkedAway
      ) {
        throw new ConflictException(
          'Please wait a short moment before raising another emergency request.',
        );
      }
    }

    const dayAgo = Date.now() - 24 * 60 * 60_000;
    const within24h = recent.filter(
      (row) => new Date(row.created_at).getTime() > dayAgo,
    ).length;
    if (within24h >= EMERGENCY_POLICY_V1.dailyCustomerCap) {
      throw new ConflictException(
        'Daily emergency limit reached. Your usage has been flagged for review; if this is dangerous, call your local emergency services.',
      );
    }
  }

  /** Coarse, coordinate-free audit trail (policy §6.4). */
  private async audit(
    booking: Booking,
    actorUserId: string,
    reason: string,
  ): Promise<void> {
    try {
      const events = this.dataSource.getRepository(BookingEvent);
      await events.insert(
        events.create({
          bookingId: booking.id,
          actorUserId,
          fromStatus: booking.status,
          toStatus: booking.status,
          reason: reason.slice(0, 500),
          bookingVersion: booking.version,
        }),
      );
    } catch {
      // Audit failures are recorded nowhere sensitive; never fail dispatch.
    }
  }

  private async scanSafely(): Promise<void> {
    try {
      await this.scanOnce();
    } catch {
      // Next tick retries; sends are deduplicated.
    }
  }
}

export interface EmergencyCreationResult {
  bookingId: string;
  status: BookingStatus;
  currentWave: number;
  fallbackRequired: boolean;
  guidance: string | null;
  eligibleCount: number;
}

export interface EmergencyStatusResult {
  bookingId: string;
  status: BookingStatus;
  currentWave: number;
  fallbackRequired: boolean;
  guidance: string | null;
}
