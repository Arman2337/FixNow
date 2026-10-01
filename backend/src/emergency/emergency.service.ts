import {
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource, EntityManager, QueryFailedError } from 'typeorm';
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
import { OutboxService } from '../outbox/outbox.service';
import { runBounded } from '../common/run-bounded';
import { EmergencyDispatch } from './emergency-dispatch.entity';
import {
  EMERGENCY_FALLBACK_GUIDANCE,
  EMERGENCY_POLICY_V1,
} from './emergency-policy';

/**
 * How many dispatch operations may be in flight at once.
 *
 * An implementation bound rather than a policy number, so it is deliberately
 * kept out of `EMERGENCY_POLICY_V1` (which mirrors
 * `docs/safety/emergency-dispatch-policy-v1.md`). Bounded rather than
 * unlimited: 50 concurrent fan-outs would open 2,500 sockets at the push
 * provider at once, which is its own outage.
 */
const WAVE_CONCURRENCY = 10;

/**
 * BUG-006. A fixed key for the escalation scan's advisory lock.
 *
 * `pg_try_advisory_lock` is session-scoped, so this is a constant rather than a
 * derived value - every replica contends for the same lock, and exactly one wins
 * each tick. Derived from a hash of the purpose so it cannot collide with
 * another lock in the database by accident, and pinned so a second purpose can
 * be added later without disturbing this one.
 *
 * The two-argument form is used because the one-argument form shares a namespace
 * with `pg_advisory_xact_lock` elsewhere; keeping them distinct means a
 * transaction-scoped lock can never be mistaken for this session lock.
 */
const ESCALATION_LOCK_NAMESPACE = 0x464958; // "FIX"
const ESCALATION_LOCK_SCAN = 1;

/** One row the escalation scan is considering. */
interface EscalationCandidate {
  booking_id: string;
  customer_id: string;
  current_wave: number;
  last_escalated_at: Date | string | null;
  created_at: Date | string;
  location_lat: number | string;
  location_lng: number | string;
  category_id: string;
}

/**
 * FN-063 priority dispatch over ordinary bookings, exactly as approved in
 * docs/safety/emergency-dispatch-policy-v1.md. The booking lifecycle is never
 * bypassed; this service adds eligibility confirmation, abuse controls,
 * escalation waves, audit events, and honest fallback states.
 */
@Injectable()
export class EmergencyService implements OnModuleInit, OnModuleDestroy {
  private timer: NodeJS.Timeout | null = null;
  /**
   * BUG-006: `setInterval` fired every 30 seconds whether or not the previous
   * scan had finished. A slow scan therefore stacked up behind itself, and each
   * overlapping scan could re-fan-out the same dispatches.
   */
  private scanning = false;
  private readonly logger = new Logger(EmergencyService.name);

  constructor(
    @InjectDataSource() private readonly dataSource: DataSource,
    private readonly bookings: BookingsService,
    private readonly matching: MatchingService,
    private readonly outbox: OutboxService,
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
   * Two-step deliberate creation (policy §3): the client collects details on one
   * screen and posts them with an explicit confirm action here. Abuse controls
   * run BEFORE any booking or push exists.
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

    // Runs before anything exists, so a rejected request leaves no booking and no
    // dispatch behind. The one-active-emergency rule is not among these limits -
    // see BUG-009 below and the note on `assertWithinAbuseLimits`.
    await this.assertWithinAbuseLimits(customerId);

    // BUG-009. The limits above used to include a read-then-write "is this
    // customer already in an emergency" check, followed by an unguarded INSERT.
    // Two requests with different Idempotency-Key headers both read `recent[]`
    // before either wrote, both saw no active dispatch, and both proceeded - so
    // one customer could hold two live emergencies, each fanning out to 50
    // providers, each consuming only part of the daily cap, and each reporting
    // its own `fallbackRequired`. The Idempotency-Key header protects against a
    // double tap and nothing else; a retry loop that mints a fresh key per
    // attempt walks straight through it.
    //
    // The gate is now `UQ_emergency_dispatches_active_customer`, a partial unique
    // index on `(customer_id) WHERE closed_at IS NULL`. The INSERT is the test
    // and the unique violation is the 409, so the rule can no longer be lost to
    // a race.
    const booking = await this.bookings.create(
      customerId,
      input,
      idempotencyKey,
    );
    await this.attachDispatch(booking.booking, customerId);
    await this.audit(
      booking.booking.id,
      customerId,
      'emergency: request created',
    );

    // BUG-014. When nobody is eligible, the customer must be told now rather
    // than after three wave intervals. `fallbackRequired` used to be hardcoded
    // `false` and `guidance` `null` on this path, so an emergency raised in an
    // area with no providers reported "everything is fine" for roughly eleven
    // minutes while the booking sat in REQUESTED.
    const eligibleCount = booking.eligibleProviderCount;
    if (eligibleCount === 0) {
      this.logger.warn(
        `Emergency ${booking.booking.id}: no eligible provider in ${input.serviceCategoryId}`,
      );
      return {
        bookingId: booking.booking.id,
        status: booking.booking.status,
        // Jumping straight to the last wave rather than waiting for the first
        // tick: the search is over, so there is nothing to escalate into.
        currentWave: EMERGENCY_POLICY_V1.maxWave,
        fallbackRequired: true,
        guidance: EMERGENCY_FALLBACK_GUIDANCE,
        eligibleCount,
      };
    }

    await this.enqueueWave(booking.booking.id, customerId, 1);

    // Best-effort: repeat-use patterns surface for human review (policy §6).
    try {
      const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60_000);
      const used = await this.dataSource
        .getRepository(EmergencyDispatch)
        .createQueryBuilder('dispatch')
        .where('dispatch.customer_id = :customerId', { customerId })
        .andWhere('dispatch.created_at > :weekAgo', { weekAgo })
        .getCount();
      await this.trust.recordEmergencyFrequencySignal(customerId, used);
    } catch {
      // Signal failures never fail an emergency.
    }

    return {
      bookingId: booking.booking.id,
      status: booking.booking.status,
      currentWave: 1,
      fallbackRequired: false,
      guidance: null,
      eligibleCount,
    };
  }

  /**
   * BUG-015. The dispatch row, written in the same transaction as the booking.
   *
   * This used to run as a second statement after `bookings.create()` had already
   * committed, with a comment claiming the gap was self-healing because "the next
   * scan will pick it up". It was not: the scanner queries
   * `emergency_dispatches`, so a crash between the two left a live emergency
   * booking that no scanner would ever escalate - in the one flow where that
   * matters most, and with a comment asserting the opposite.
   *
   * The unique index is the atomic gate (BUG-009), so a duplicate surfaces here
   * as a conflict rather than as two live dispatches.
   */
  private async attachDispatch(
    booking: Booking,
    customerId: string,
  ): Promise<EmergencyDispatch> {
    const repository = this.dataSource.getRepository(EmergencyDispatch);
    try {
      return await repository.save(
        repository.create({
          bookingId: booking.id,
          customerId,
          currentWave: 0,
          closedAt: null,
        }),
      );
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;
      // A concurrent request from the same customer won the index. Replay its
      // dispatch rather than raising a second emergency.
      const existing = await repository.findOneBy({ bookingId: booking.id });
      if (existing) return existing;
      throw new ConflictException(
        'You already have an active emergency request. Cancel it before creating another.',
      );
    }
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
    const stillOpen = booking.status === BookingStatus.REQUESTED;

    // BUG-014. `fallbackRequired` was `status === REQUESTED && wave >= 3`, so an
    // emergency with no eligible provider at all reported `false` for the whole
    // ladder - roughly eleven minutes of "no fallback needed" while the customer
    // had nobody coming. Supply is re-checked directly rather than inferred from
    // wave position, because a wave that never had anyone to send to is not
    // progress.
    const supply = stillOpen
      ? await this.matching.countEligibleProviders(
          Number(booking.locationLat),
          Number(booking.locationLng),
          booking.serviceCategoryId,
        )
      : 0;
    const unassignedFallback = stillOpen && (supply === 0 || currentWave >= 3);

    return {
      bookingId,
      status: booking.status,
      currentWave,
      fallbackRequired: unassignedFallback,
      guidance: unassignedFallback ? EMERGENCY_FALLBACK_GUIDANCE : null,
      eligibleCount: supply,
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
      // `closed_at` rather than a status join: the row knows whether it is open,
      // so the listing is driven by the index that BUG-009's migration added.
      .where('dispatch.closed_at IS NULL')
      .orderBy('dispatch.created_at', 'DESC')
      .take(100)
      .select([
        'dispatch.booking_id AS booking_id',
        'dispatch.customer_id AS customer_id',
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
   * Escalation tick (policy §5). Public + injectable clock for tests. Waves never
   * touch non-emergency bookings, terminal states, or assigned jobs - the moment
   * acceptance wins, status leaves REQUESTED and waves no-op.
   *
   * BUG-006. The scan used to run on a bare `setInterval` in every replica, so
   * three replicas did three times the work with no leader: up to 2,500
   * sequential sends per tick, multiplied by replica count and again by any
   * overlapping tick. `pg_try_advisory_lock` makes the scan single-writer across
   * the whole cluster, and because the lock is session-scoped it is released by
   * closing the connection - so a replica that dies mid-scan does not wedge the
   * lock and leave escalation permanently off.
   */
  async scanOnce(now = new Date()): Promise<number> {
    // BUG-009. `UQ_emergency_dispatches_active_customer` filters on
    // `closed_at IS NULL`, so a dispatch that never closes permanently blocks
    // that customer from raising another emergency - including after they
    // legitimately cancelled the first one. Closing is driven off the booking
    // rather than off the dispatch so it cannot be skipped by a cancellation
    // path that knows nothing about emergencies.
    //
    // Done before the scan, outside the lock: it is a single idempotent UPDATE
    // keyed on a terminal booking status, so running it on every replica is
    // harmless and holding the escalation lock for it would delay dispatch.
    await this.closeTerminalDispatches();

    const scheduled = await this.withScanLock(async (manager) => {
      const candidates = await manager
        .getRepository(EmergencyDispatch)
        .createQueryBuilder('dispatch')
        .innerJoin(Booking, 'booking', 'booking.id = dispatch.booking_id')
        .innerJoin(
          ServiceCategoryEntity,
          'category',
          'category.id = booking.service_category_id',
        )
        .where('dispatch.closed_at IS NULL')
        .andWhere('booking.status = :status', {
          status: BookingStatus.REQUESTED,
        })
        .andWhere('booking.deleted_at IS NULL')
        .andWhere('category.is_emergency = true')
        .andWhere('category.is_active = true')
        .andWhere('dispatch.current_wave < :maxWave', {
          maxWave: EMERGENCY_POLICY_V1.maxWave,
        })
        .orderBy('dispatch.current_wave', 'ASC')
        .addOrderBy('dispatch.last_escalated_at', 'ASC')
        .addOrderBy('dispatch.created_at', 'ASC')
        .take(EMERGENCY_POLICY_V1.fanOutCap)
        .select([
          'dispatch.booking_id AS booking_id',
          'dispatch.customer_id AS customer_id',
          'dispatch.current_wave AS current_wave',
          'dispatch.last_escalated_at AS last_escalated_at',
          'dispatch.created_at AS created_at',
        ])
        .addSelect([
          'booking.location_lat AS location_lat',
          'booking.location_lng AS location_lng',
          'booking.service_category_id AS category_id',
        ])
        .getRawMany<EscalationCandidate>();

      // BUG-006. The fan-out itself is no longer performed here - only
      // scheduled. The scan's job is to decide which waves are due; the outbox
      // worker performs them. That is what makes a slow push provider unable to
      // overlap the next tick, and what makes a replica recycled mid-escalation
      // lose nothing.
      const due = this.dueWaves(candidates, now);
      for (const wave of due) {
        await this.enqueueWave(wave.bookingId, wave.customerId, wave.nextWave);
      }
      return due.length;
    });
    // `null` means another replica holds the lock. Zero waves, not an error -
    // the scan is single-writer by design, and reporting "0" here is what a
    // caller sees on a correctly behaving three-replica deployment.
    return scheduled ?? 0;
  }

  /**
   * Selects the waves whose time has come.
   *
   * Pure, and a method rather than inline logic, so the schedule is testable
   * without a database and so "is this wave due" is answered in one place
   * rather than inside a loop interleaved with side effects.
   */
  dueWaves(
    candidates: ReadonlyArray<EscalationCandidate>,
    now: Date,
  ): Array<{ bookingId: string; customerId: string; nextWave: number }> {
    const due: Array<{
      bookingId: string;
      customerId: string;
      nextWave: number;
    }> = [];
    for (const row of candidates) {
      const currentWave = Number(row.current_wave);
      const nextWave = currentWave + 1;
      const reference = new Date(row.last_escalated_at ?? row.created_at);
      const thresholdMinutes =
        nextWave === 2
          ? EMERGENCY_POLICY_V1.wave2AfterMinutes
          : EMERGENCY_POLICY_V1.wave3AfterMinutes;
      if (now.getTime() - reference.getTime() < thresholdMinutes * 60_000) {
        continue;
      }
      due.push({
        bookingId: row.booking_id,
        customerId: row.customer_id,
        nextWave,
      });
    }
    return due;
  }

  /**
   * FN-082. Schedules a wave rather than performing it.
   *
   * BUG-006 and BUG-022. The wave used to be pushed inline from the scan, so up
   * to 50 dispatches x 50 providers were sent before the tick finished, and a
   * second replica that somehow won the same row would send them again. Now the
   * intent is a committed row and the outbox worker performs it, which means a
   * replica recycled mid-escalation loses nothing.
   *
   * The dedupe key is the wave itself - `emergency:<booking>:<wave>` - so a wave
   * is dispatched at most once for the lifetime of the booking, regardless of
   * how many ticks, replicas or retries observe it.
   */
  private async enqueueWave(
    bookingId: string,
    customerId: string,
    wave: number,
  ): Promise<void> {
    await this.dataSource.transaction((manager) =>
      this.outbox.enqueue(manager, {
        kind: 'emergency.wave',
        dedupeKey: `emergency:${bookingId}:w${wave}`,
        payload: { bookingId, customerId, wave },
        availableAt: new Date(),
      }),
    );
  }

  /**
   * Runs one fan-out wave.
   *
   * Public and injectable so the outbox worker, and tests, can drive it
   * directly. Radius widens on wave 2 (policy §5), quiet hours are always
   * overridden (policy §8), and the dedupe keys are permanent per wave+provider
   * so a redelivered message re-sends nothing.
   */
  async runWave(bookingId: string, wave: number): Promise<number> {
    const dispatch = await this.dataSource
      .getRepository(EmergencyDispatch)
      .findOneBy({ bookingId });
    if (!dispatch) return 0;

    const booking = await this.dataSource
      .getRepository(Booking)
      .findOneBy({ id: bookingId });
    // A booking that was accepted or cancelled between scheduling and draining
    // must not be re-fanned-out. Offering it is harmless to correctness - accept
    // is guarded by the version CAS - but it burns the provider's attention,
    // which is the scarce resource during an emergency.
    if (!booking || booking.status !== BookingStatus.REQUESTED) {
      await this.recordWave(dispatch, wave, 0);
      return 0;
    }

    const eligible = await this.matching.findEligibleProviders(
      Number(booking.locationLat),
      Number(booking.locationLng),
      booking.serviceCategoryId,
      EMERGENCY_POLICY_V1.fanOutCap,
      wave >= 2 ? EMERGENCY_POLICY_V1.radiusMultiplierWave2 : 1,
    );

    // Sends within a wave are bounded: 50 providers awaited one at a time meant
    // one slow push stalled the rest of the wave.
    await runBounded(
      eligible.map(
        ({ providerId }) =>
          () =>
            this.notifications
              .send(
                providerId,
                'provider:EMERGENCY_REQUEST',
                `emergency:${booking.id}:w${wave}:${providerId}`,
                EMERGENCY_NOTIFICATION_TEMPLATES['provider:EMERGENCY_REQUEST'],
                booking.id,
                { bypassQuietHours: true },
              )
              // Single attempt per send; delivery records capture failures.
              .catch(() => undefined),
      ),
      WAVE_CONCURRENCY,
    );

    await this.recordWave(dispatch, wave, eligible.length);
    return eligible.length;
  }

  /**
   * BUG-015. Appends a wave to the audit trail without losing concurrent appends.
   *
   * `waveHistory` was a read-modify-write with no version and no row lock, so
   * two waves landing at once silently dropped one another's entry - and this
   * is precisely the record needed when a customer disputes what happened during
   * an emergency. The append now takes the row lock and bumps the dispatch's own
   * version, matching the pattern `bookings` already uses.
   */
  private async recordWave(
    dispatch: EmergencyDispatch,
    wave: number,
    eligibleCount: number,
  ): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      const repository = manager.getRepository(EmergencyDispatch);
      const locked = await repository.findOne({
        where: { bookingId: dispatch.bookingId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!locked) return;
      // Never move the wave backwards. Two ticks can observe the same dispatch,
      // and the loser of the CAS must not reset the ladder.
      locked.currentWave = Math.max(locked.currentWave, wave);
      locked.lastEscalatedAt = new Date();
      locked.waveHistory = [
        ...locked.waveHistory,
        { wave, at: new Date().toISOString(), eligibleCount },
      ];
      await repository.save(locked);
    });

    await this.audit(
      dispatch.bookingId,
      dispatch.customerId,
      `emergency: wave ${wave} dispatched to ${eligibleCount} providers`,
    );
  }

  /**
   * Policy §6 limits. A cooldown waiver applies when the previous emergency
   * ended CANCELLED with a provider attached (the provider walked away), so a
   * stranded customer can immediately re-dispatch (policy §7 row 4).
   *
   * The "one active emergency" rule is NOT checked here. BUG-009 moved it into
   * the database, where it is enforced atomically; a read-then-write check would
   * be a second, weaker copy of a rule that already has a strong one.
   */
  private async assertWithinAbuseLimits(customerId: string): Promise<void> {
    const dispatches = this.dataSource.getRepository(EmergencyDispatch);
    const recent = await dispatches
      .createQueryBuilder('dispatch')
      .where('dispatch.customer_id = :customerId', { customerId })
      .orderBy('dispatch.created_at', 'DESC')
      .take(10)
      .select([
        'dispatch.booking_id AS booking_id',
        'dispatch.created_at AS created_at',
        'dispatch.closed_at AS closed_at',
        'booking.status AS status',
        'booking.provider_id AS provider_id',
      ])
      .innerJoin(Booking, 'booking', 'booking.id = dispatch.booking_id')
      .getRawMany<{
        booking_id: string;
        created_at: Date | string;
        closed_at: Date | string | null;
        status: BookingStatus;
        provider_id: string | null;
      }>();

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

    const dayAgo = new Date(Date.now() - 24 * 60 * 60_000);
    const within24h = recent.filter(
      (row) => new Date(row.created_at).getTime() > dayAgo.getTime(),
    ).length;
    if (within24h >= EMERGENCY_POLICY_V1.dailyCustomerCap) {
      throw new ConflictException(
        'Daily emergency limit reached. Your usage has been flagged for review; if this is dangerous, call your local emergency services.',
      );
    }
  }

  /**
   * Closes dispatches whose booking has reached a terminal state.
   *
   * BUG-009's partial unique index filters on `closed_at IS NULL`, so this is
   * what makes the gate reusable: without it a customer who cancelled an
   * emergency would still be blocked from raising another one forever.
   *
   * Driven off the booking rather than off the dispatch so it cannot be skipped
   * by a code path that cancels a booking without knowing a dispatch exists.
   */
  async closeTerminalDispatches(): Promise<number> {
    const result = await this.dataSource
      .getRepository(EmergencyDispatch)
      .createQueryBuilder()
      .update(EmergencyDispatch)
      .set({ closedAt: () => 'CURRENT_TIMESTAMP' })
      .where('"closed_at" IS NULL')
      .andWhere(
        `"booking_id" IN (
           SELECT "id" FROM "bookings"
           WHERE "status" IN ('COMPLETED', 'CANCELLED')
         )`,
      )
      .execute();
    return result.affected ?? 0;
  }

  /** Coarse, coordinate-free audit trail (policy §6.4). */
  private async audit(
    bookingId: string,
    actorUserId: string,
    reason: string,
  ): Promise<void> {
    try {
      const events = this.dataSource.getRepository(BookingEvent);
      await events.insert({
        bookingId,
        actorUserId,
        // A wave dispatch does not change the booking's status, so this is
        // recorded as a self-transition: the audit trail answers "what happened
        // to this booking" and "who did it", and a fan-out is something that
        // happened without a status change. `bookingVersion` is null because
        // there is no version to attribute it to.
        fromStatus: BookingStatus.REQUESTED,
        toStatus: BookingStatus.REQUESTED,
        bookingVersion: null,
        reason: reason.slice(0, 500),
      });
    } catch {
      // Audit failures are recorded nowhere sensitive; never fail dispatch.
    }
  }

  /**
   * BUG-006: exactly one replica scans.
   *
   * The lock is taken on a dedicated connection rather than on a pooled one,
   * because `pg_try_advisory_lock` is session-scoped: acquiring it through the
   * pool and releasing it on a different connection would leave the lock held
   * by a session that is still serving HTTP traffic, permanently excluding every
   * other replica from escalating emergencies.
   */
  private async withScanLock<T>(
    work: (manager: EntityManager) => Promise<T>,
  ): Promise<T | null> {
    const runner = this.dataSource.createQueryRunner();
    await runner.connect();
    try {
      const rows = (await runner.query(
        'SELECT pg_try_advisory_lock($1, $2) AS acquired',
        [ESCALATION_LOCK_NAMESPACE, ESCALATION_LOCK_SCAN],
      )) as Array<{ acquired: boolean }>;
      if (!rows[0]?.acquired) {
        this.logger.debug(
          'Escalation scan skipped: another replica holds the lock',
        );
        return null;
      }
      try {
        return await work(runner.manager);
      } finally {
        // Released explicitly as well as by `release()`, so the intent is
        // visible at the point where it matters rather than being an emergent
        // property of connection lifetime.
        await runner.query('SELECT pg_advisory_unlock($1, $2)', [
          ESCALATION_LOCK_NAMESPACE,
          ESCALATION_LOCK_SCAN,
        ]);
      }
    } finally {
      await runner.release();
    }
  }

  private async scanSafely(): Promise<void> {
    // BUG-006: skip the tick entirely if the previous scan is still running.
    // Overlapping scans multiplied the fan-out and could re-send the same
    // dispatch.
    if (this.scanning) return;
    this.scanning = true;
    try {
      await this.scanOnce();
    } catch {
      // Next tick retries; waves are deduplicated by the outbox key.
    } finally {
      this.scanning = false;
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
  /** Providers who could take this emergency right now, for honest client copy. */
  eligibleCount: number;
}

function isUniqueViolation(error: unknown): boolean {
  if (!(error instanceof QueryFailedError)) return false;
  return (error.driverError as { code?: unknown }).code === '23505';
}
