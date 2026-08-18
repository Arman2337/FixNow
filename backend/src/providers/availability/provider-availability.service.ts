import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';
import { ProviderAvailabilityStatus } from '../../../../shared/provider-availability.types';
import { ProviderApplicationEntity } from '../provider-application.entity';
import { ProviderOnboardingStatus } from '../provider-onboarding-status';
import {
  ProviderAvailabilityResponseDto,
  UpdateProviderScheduleDto,
  UpdateProviderStatusDto,
} from './provider-availability.dto';
import { ProviderAvailabilityEntity } from './provider-availability.entity';

const MAX_STATUS_DURATION_MS = 12 * 60 * 60 * 1000;

@Injectable()
export class ProviderAvailabilityService {
  constructor(private readonly dataSource: DataSource) {}

  async getOwn(userId: string): Promise<ProviderAvailabilityResponseDto> {
    await this.assertVerified(this.dataSource.manager, userId, false);
    return this.dataSource.transaction(async (manager) => {
      const repository = manager.getRepository(ProviderAvailabilityEntity);
      let entity = await repository.findOne({ where: { userId }, lock: { mode: 'pessimistic_write' } });
      if (!entity) {
        entity = await repository.save(
          repository.create({
            userId,
            timeZone: 'UTC',
            weeklyRules: [],
            exceptions: [],
            status: ProviderAvailabilityStatus.Offline,
            statusExpiresAt: null,
            version: 0,
          })
        );
      }
      return this.toResponse(entity);
    });
  }

  async updateSchedule(
    userId: string,
    dto: UpdateProviderScheduleDto,
  ): Promise<ProviderAvailabilityResponseDto> {
    this.validateTimeZone(dto.timeZone);
    this.validateSchedule(dto);
    return this.mutate(userId, dto.expectedVersion, (entity) => {
      entity.timeZone = dto.timeZone;
      entity.weeklyRules = dto.weeklyRules;
      entity.exceptions = dto.exceptions;
    });
  }

  async updateStatus(
    userId: string,
    dto: UpdateProviderStatusDto,
  ): Promise<ProviderAvailabilityResponseDto> {
    const expiresAt = dto.expiresAt ? new Date(dto.expiresAt) : null;
    if (expiresAt && !Number.isFinite(expiresAt.getTime()))
      throw new ConflictException('Invalid status expiry');
    if (dto.status === ProviderAvailabilityStatus.Offline && expiresAt)
      throw new ConflictException('Offline status cannot expire');
    if (dto.status !== ProviderAvailabilityStatus.Offline) {
      const duration = expiresAt ? expiresAt.getTime() - Date.now() : 0;
      if (duration <= 0 || duration > MAX_STATUS_DURATION_MS)
        throw new ConflictException(
          'Online and busy status require an expiry within 12 hours',
        );
    }
    return this.mutate(userId, dto.expectedVersion, (entity) => {
      entity.status = dto.status;
      entity.statusExpiresAt = expiresAt;
    });
  }

  private async mutate(
    userId: string,
    expectedVersion: number,
    change: (entity: ProviderAvailabilityEntity) => void,
  ): Promise<ProviderAvailabilityResponseDto> {
    return this.dataSource.transaction(async (manager) => {
      await this.assertVerified(manager, userId, true);
      const repository = manager.getRepository(ProviderAvailabilityEntity);
      let entity = await repository.findOne({
        where: { userId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!entity) {
        if (expectedVersion !== 0)
          throw new ConflictException('Provider availability changed');
        entity = repository.create({
          userId,
          timeZone: 'UTC',
          weeklyRules: [],
          exceptions: [],
          status: ProviderAvailabilityStatus.Offline,
          statusExpiresAt: null,
          version: 0,
        });
      } else if (entity.version !== expectedVersion) {
        throw new ConflictException('Provider availability changed');
      }
      change(entity);
      entity.version += 1;
      return this.toResponse(await repository.save(entity));
    });
  }

  private async assertVerified(
    manager: EntityManager,
    userId: string,
    lockForUpdate: boolean,
  ): Promise<void> {
    const application = await manager
      .getRepository(ProviderApplicationEntity)
      .findOne({
        where: { userId },
        ...(lockForUpdate
          ? { lock: { mode: 'pessimistic_write' as const } }
          : {}),
      });
    if (!application)
      throw new NotFoundException('Provider application not found');
    if (application.status !== ProviderOnboardingStatus.Approved)
      throw new ForbiddenException('Verified provider access required');
  }

  private validateTimeZone(timeZone: string): void {
    try {
      new Intl.DateTimeFormat('en-US', { timeZone }).format();
    } catch {
      throw new ConflictException('Invalid IANA time zone');
    }
  }

  private validateSchedule(dto: UpdateProviderScheduleDto): void {
    const days = new Set<number>();
    for (const rule of dto.weeklyRules) {
      if (
        !Number.isInteger(rule.dayOfWeek) ||
        rule.dayOfWeek < 0 ||
        rule.dayOfWeek > 6
      )
        throw new ConflictException('Invalid weekly schedule day');
      if (days.has(rule.dayOfWeek))
        throw new ConflictException('Duplicate weekly schedule day');
      days.add(rule.dayOfWeek);
      this.validateIntervals(rule.intervals);
    }
    const dates = new Set<string>();
    for (const exception of dto.exceptions) {
      if (dates.has(exception.date))
        throw new ConflictException('Duplicate schedule exception date');
      dates.add(exception.date);
      this.validateExceptionDate(exception.date);
      if (exception.unavailable && exception.intervals.length)
        throw new ConflictException(
          'Unavailable exceptions cannot contain intervals',
        );
      if (!exception.unavailable && !exception.intervals.length)
        throw new ConflictException(
          'Available exceptions require at least one interval',
        );
      this.validateIntervals(exception.intervals);
    }
  }

  private validateExceptionDate(date: string): void {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date))
      throw new ConflictException('Invalid schedule exception date');
    const parsed = new Date(`${date}T00:00:00.000Z`);
    if (
      !Number.isFinite(parsed.getTime()) ||
      parsed.toISOString().slice(0, 10) !== date
    )
      throw new ConflictException('Invalid schedule exception date');
  }

  private validateIntervals(
    intervals: Array<{ startMinute: number; endMinute: number }>,
  ): void {
    const sorted = [...intervals].sort((a, b) => a.startMinute - b.startMinute);
    for (let index = 0; index < sorted.length; index += 1) {
      if (
        !Number.isInteger(sorted[index].startMinute) ||
        !Number.isInteger(sorted[index].endMinute) ||
        sorted[index].startMinute < 0 ||
        sorted[index].endMinute > 1440
      )
        throw new ConflictException('Availability interval is out of bounds');
      if (sorted[index].startMinute >= sorted[index].endMinute)
        throw new ConflictException('Availability interval must have duration');
      if (index > 0 && sorted[index].startMinute < sorted[index - 1].endMinute)
        throw new ConflictException('Availability intervals overlap');
    }
  }

  private toResponse(
    entity: ProviderAvailabilityEntity,
  ): ProviderAvailabilityResponseDto {
    const expired =
      entity.status !== ProviderAvailabilityStatus.Offline &&
      (!entity.statusExpiresAt ||
        entity.statusExpiresAt.getTime() <= Date.now());
    return {
      id: entity.id,
      userId: entity.userId,
      timeZone: entity.timeZone,
      weeklyRules: entity.weeklyRules,
      exceptions: entity.exceptions,
      status: expired ? ProviderAvailabilityStatus.Offline : entity.status,
      statusExpiresAt: expired ? null : entity.statusExpiresAt,
      version: entity.version,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    };
  }
}
