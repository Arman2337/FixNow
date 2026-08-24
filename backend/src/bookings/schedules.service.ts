import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type {
  RecurringScheduleContract,
  ScheduleAction,
  ScheduleCadence,
} from '../../../shared/recurring.types';
import { ServiceCategoryEntity } from '../services/service-category.entity';
import { Booking } from './domain/booking.entity';
import { RecurringSchedule } from './domain/recurring-schedule.entity';
import { BookingsService } from './bookings.service';
import type { CreateScheduleDto } from './schedules.dto';

/** A past-due occurrence may still be confirmed within this grace window. */
export const OCCURRENCE_CONFIRM_GRACE_MS = 15 * 60_000;
const MAX_FIRST_OCCURRENCE_DAYS = 365;

/**
 * Advances one cadence step.
 *
 * ponytail: WEEKLY steps a fixed 168h and MONTHLY clamps the day of month
 * (Jan 31 → Feb 28). DST markets would drift an hour; the current market
 * (INR) has none. Upgrade path: a tzdb-aware generator worker.
 */
export function nextOccurrenceAfter(
  occurrence: Date,
  cadence: ScheduleCadence,
): Date {
  if (cadence === 'WEEKLY') {
    return new Date(occurrence.getTime() + 7 * 24 * 3_600_000);
  }
  const year = occurrence.getUTCFullYear();
  const month = occurrence.getUTCMonth();
  const lastDayOfNextMonth = new Date(
    Date.UTC(year, month + 2, 0),
  ).getUTCDate();
  return new Date(
    Date.UTC(
      year,
      month + 1,
      Math.min(occurrence.getUTCDate(), lastDayOfNextMonth),
      occurrence.getUTCHours(),
      occurrence.getUTCMinutes(),
      occurrence.getUTCSeconds(),
    ),
  );
}

@Injectable()
export class SchedulesService {
  constructor(
    @InjectRepository(RecurringSchedule)
    private readonly schedules: Repository<RecurringSchedule>,
    @InjectRepository(ServiceCategoryEntity)
    private readonly categories: Repository<ServiceCategoryEntity>,
    private readonly bookings: BookingsService,
  ) {}

  async create(
    customerId: string,
    dto: CreateScheduleDto,
  ): Promise<RecurringScheduleContract> {
    const firstOccurrence = new Date(dto.firstOccurrenceAt);
    if (
      Number.isNaN(firstOccurrence.getTime()) ||
      firstOccurrence.getTime() < Date.now() ||
      firstOccurrence.getTime() >
        Date.now() + MAX_FIRST_OCCURRENCE_DAYS * 24 * 3_600_000
    ) {
      throw new BadRequestException(
        'The first visit must be in the future within the next year.',
      );
    }
    const category = await this.categories.findOneBy({
      id: dto.serviceCategoryId,
    });
    if (!category || !category.isActive) {
      throw new BadRequestException('That service cannot be scheduled.');
    }
    const schedule = await this.schedules.save(
      this.schedules.create({
        customerId,
        serviceCategoryId: dto.serviceCategoryId,
        description: dto.description,
        locationLat: dto.locationLat,
        locationLng: dto.locationLng,
        cadence: dto.cadence,
        status: 'ACTIVE',
        nextOccurrenceAt: firstOccurrence,
      }),
    );
    return this.present(schedule);
  }

  /** Non-terminal schedules for one customer, soonest visit first. */
  async listSelf(customerId: string): Promise<RecurringScheduleContract[]> {
    const rows = await this.schedules.find({
      where: [
        { customerId, status: 'ACTIVE' },
        { customerId, status: 'PAUSED' },
      ],
      order: { nextOccurrenceAt: 'ASC' },
    });
    return rows.map((row) => this.present(row));
  }

  async updateStatus(
    customerId: string,
    id: string,
    action: ScheduleAction,
  ): Promise<RecurringScheduleContract> {
    const schedule = await this.ownedSchedule(customerId, id);
    if (schedule.status === 'CANCELLED') {
      throw new ConflictException('This schedule was cancelled.');
    }
    if (action === 'pause' && schedule.status === 'ACTIVE') {
      schedule.status = 'PAUSED';
    } else if (action === 'resume') {
      if (schedule.status !== 'PAUSED') {
        throw new ConflictException('Only a paused schedule can be resumed.');
      }
      schedule.status = 'ACTIVE';
      // A paused schedule generates nothing; on resume, skip missed slots
      // instead of stacking overdue occurrences.
      while (schedule.nextOccurrenceAt.getTime() <= Date.now()) {
        schedule.nextOccurrenceAt = nextOccurrenceAfter(
          schedule.nextOccurrenceAt,
          schedule.cadence,
        );
      }
    } else if (action === 'cancel') {
      schedule.status = 'CANCELLED';
    } else {
      throw new ConflictException('That action does not apply.');
    }
    return this.present(await this.schedules.save(schedule));
  }

  /**
   * Confirms the next occurrence as an ordinary booking through the
   * existing idempotent creation path. The per-occurrence idempotency key
   * plus the compare-and-advance below make concurrent double-taps produce
   * exactly one booking per occurrence.
   */
  async confirmOccurrence(
    customerId: string,
    id: string,
    now = new Date(),
  ): Promise<{ booking: Booking; schedule: RecurringScheduleContract }> {
    const schedule = await this.ownedSchedule(customerId, id);
    if (schedule.status !== 'ACTIVE') {
      throw new ConflictException(
        'Resume the schedule before confirming a visit.',
      );
    }
    const occurrence = schedule.nextOccurrenceAt;
    if (occurrence.getTime() < now.getTime() - OCCURRENCE_CONFIRM_GRACE_MS) {
      throw new ConflictException(
        'That visit time has passed. Refresh to see the next available slot.',
      );
    }
    const booking = await this.bookings.create(
      customerId,
      {
        serviceCategoryId: schedule.serviceCategoryId,
        description: schedule.description,
        locationLat: Number(schedule.locationLat),
        locationLng: Number(schedule.locationLng),
        scheduledAt: occurrence.toISOString(),
      },
      `schedule-${schedule.id}-${occurrence.toISOString()}`,
    );
    const advanced = await this.schedules.update(
      { id: schedule.id, status: 'ACTIVE', nextOccurrenceAt: occurrence },
      { nextOccurrenceAt: nextOccurrenceAfter(occurrence, schedule.cadence) },
    );
    if (advanced.affected) {
      schedule.nextOccurrenceAt = nextOccurrenceAfter(
        occurrence,
        schedule.cadence,
      );
    } else {
      // A concurrent confirmation already advanced the slot.
      const raced = await this.schedules.findOneByOrFail({ id });
      schedule.nextOccurrenceAt = raced.nextOccurrenceAt;
    }
    return { booking, schedule: this.present(schedule) };
  }

  private async ownedSchedule(
    customerId: string,
    id: string,
  ): Promise<RecurringSchedule> {
    const schedule = await this.schedules.findOneBy({ id, customerId });
    if (!schedule) {
      throw new NotFoundException('Repeating schedule not found.');
    }
    return schedule;
  }

  private present(schedule: RecurringSchedule): RecurringScheduleContract {
    return {
      id: schedule.id,
      serviceCategoryId: schedule.serviceCategoryId,
      description: schedule.description,
      locationLat: Number(schedule.locationLat),
      locationLng: Number(schedule.locationLng),
      cadence: schedule.cadence,
      status: schedule.status,
      nextOccurrenceAt:
        schedule.status === 'CANCELLED'
          ? null
          : schedule.nextOccurrenceAt.toISOString(),
    };
  }
}
