import { BadRequestException, ConflictException } from '@nestjs/common';
import { SchedulesService, nextOccurrenceAfter } from './schedules.service';

describe('nextOccurrenceAfter cadence math', () => {
  it('steps a weekly schedule by exactly one week', () => {
    const from = new Date('2026-08-24T10:00:00.000Z');
    expect(nextOccurrenceAfter(from, 'WEEKLY').toISOString()).toBe(
      '2026-08-31T10:00:00.000Z',
    );
  });

  it('clamps a monthly schedule to the shorter month', () => {
    const january = new Date('2027-01-31T09:30:00.000Z');
    expect(nextOccurrenceAfter(january, 'MONTHLY').toISOString()).toBe(
      '2027-02-28T09:30:00.000Z',
    );
  });

  it('preserves the day of month across leap years', () => {
    const february = new Date('2024-02-29T08:00:00.000Z');
    expect(nextOccurrenceAfter(february, 'MONTHLY').toISOString()).toBe(
      '2024-03-29T08:00:00.000Z',
    );
  });
});

describe('SchedulesService', () => {
  const customerId = '00000000-0000-4000-8000-00000000000c';
  const categoryId = '11111111-1111-4111-8111-111111111111';
  const now = new Date('2026-08-24T12:00:00.000Z');

  const schedules = {
    create: jest.fn(<T extends object>(value: T): T => value),
    save: jest.fn((value) =>
      Promise.resolve({
        id: 'ssssssss-1111-4111-8111-111111111111',
        createdAt: now,
        updatedAt: now,
        status: 'ACTIVE',
        ...value,
      }),
    ),
    find: jest.fn(),
    findOneBy: jest.fn(),
    findOneByOrFail: jest.fn(),
    update: jest.fn().mockResolvedValue({ affected: 1 }),
  };
  const categories = { findOneBy: jest.fn() };
  const bookings = { create: jest.fn() };
  const service = new SchedulesService(
    schedules as never,
    categories as never,
    bookings as never,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    categories.findOneBy.mockResolvedValue({ id: categoryId, isActive: true });
    schedules.update.mockResolvedValue({ affected: 1 });
  });

  describe('create', () => {
    const dto = {
      serviceCategoryId: categoryId,
      description: 'Weekly housekeeping',
      locationLat: 17.385,
      locationLng: 78.4867,
      cadence: 'WEEKLY' as const,
      firstOccurrenceAt: '2026-08-31T04:30:00.000Z',
    };

    it('creates an active schedule anchored on the first occurrence', async () => {
      const result = await service.create(customerId, dto);
      expect(result.status).toBe('ACTIVE');
      expect(result.nextOccurrenceAt).toBe('2026-08-31T04:30:00.000Z');
    });

    it('rejects an inactive or missing category', async () => {
      categories.findOneBy.mockResolvedValue(null);
      await expect(service.create(customerId, dto)).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it.each(['2026-08-24T11:00:00.000Z', '2027-09-01T12:00:00.000Z'])(
      'rejects a first occurrence outside the allowed window (%s)',
      async (firstOccurrenceAt) => {
        await expect(
          service.create(customerId, { ...dto, firstOccurrenceAt }),
        ).rejects.toBeInstanceOf(BadRequestException);
      },
    );
  });

  describe('updateStatus', () => {
    const active = () => ({
      id: 'ssssssss-1111-4111-8111-111111111111',
      customerId,
      serviceCategoryId: categoryId,
      description: 'd',
      locationLat: '17.3850000',
      locationLng: '78.4867000',
      cadence: 'WEEKLY' as const,
      status: 'ACTIVE' as const,
      nextOccurrenceAt: new Date('2026-08-25T12:00:00.000Z'),
    });

    it('pauses and cancels; cancelled is terminal', async () => {
      schedules.findOneBy.mockResolvedValue(active());
      await service.updateStatus(customerId, 's1', 'pause');
      expect(schedules.save).toHaveBeenLastCalledWith(
        expect.objectContaining({ status: 'PAUSED' }),
      );
      await service.updateStatus(customerId, 's1', 'cancel');
      expect(schedules.save).toHaveBeenLastCalledWith(
        expect.objectContaining({ status: 'CANCELLED' }),
      );
      schedules.findOneBy.mockResolvedValue({
        ...active(),
        status: 'CANCELLED',
      });
      await expect(
        service.updateStatus(customerId, 's1', 'resume'),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('skips missed slots when resuming so paused periods generate nothing', async () => {
      // Paused with three overdue weekly slots before "now".
      schedules.findOneBy.mockResolvedValue({
        ...active(),
        status: 'PAUSED',
        nextOccurrenceAt: new Date('2026-08-03T12:00:00.000Z'),
      });
      const resumed = await service.updateStatus(customerId, 's1', 'resume');
      expect(resumed.nextOccurrenceAt).toBe('2026-08-31T12:00:00.000Z');
      expect(bookings.create).not.toHaveBeenCalled();
    });

    it('cannot resume a schedule that was never paused', async () => {
      schedules.findOneBy.mockResolvedValue(active());
      await expect(
        service.updateStatus(customerId, 's1', 'resume'),
      ).rejects.toBeInstanceOf(ConflictException);
    });
  });

  describe('confirmOccurrence', () => {
    const owned = (overrides: Record<string, unknown> = {}) => ({
      id: 'ssssssss-1111-4111-8111-111111111111',
      customerId,
      serviceCategoryId: categoryId,
      description: 'Weekly housekeeping',
      locationLat: '17.3850000',
      locationLng: '78.4867000',
      cadence: 'WEEKLY',
      status: 'ACTIVE',
      nextOccurrenceAt: new Date('2026-08-25T12:00:00.000Z'),
      ...overrides,
    });
    const booking = { id: 'bbbbbbbb-1111-4111-8111-111111111111' };

    it('confirms through the idempotent booking path and advances one slot', async () => {
      schedules.findOneBy.mockImplementation(
        ({ status }: { status?: string }) =>
          status === undefined
            ? Promise.resolve(owned())
            : Promise.resolve(
                owned({
                  nextOccurrenceAt: new Date('2026-09-01T12:00:00.000Z'),
                }),
              ),
      );
      bookings.create.mockResolvedValue(booking);

      const result = await service.confirmOccurrence(customerId, 's1', now);

      expect(bookings.create).toHaveBeenCalledWith(
        customerId,
        expect.objectContaining({
          scheduledAt: '2026-08-25T12:00:00.000Z',
        }),
        'schedule-ssssssss-1111-4111-8111-111111111111-2026-08-25T12:00:00.000Z',
      );
      expect(schedules.update).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'ACTIVE',
          nextOccurrenceAt: new Date('2026-08-25T12:00:00.000Z'),
        }),
        { nextOccurrenceAt: new Date('2026-09-01T12:00:00.000Z') },
      );
      expect(result.schedule.nextOccurrenceAt).toBe('2026-09-01T12:00:00.000Z');
    });

    it('survives a concurrent advance without double-booking the slot', async () => {
      schedules.findOneBy.mockResolvedValueOnce(owned());
      bookings.create.mockResolvedValue(booking);
      // The compare-and-advance loses the race.
      schedules.update.mockResolvedValue({ affected: 0 });
      schedules.findOneByOrFail.mockResolvedValue(
        owned({ nextOccurrenceAt: new Date('2026-09-01T12:00:00.000Z') }),
      );

      const result = await service.confirmOccurrence(customerId, 's1', now);

      // The idempotency key is per occurrence, so the racing create call
      // resolves to the same booking rather than a second one.
      expect(result.booking).toBe(booking);
      expect(result.schedule.nextOccurrenceAt).toBe('2026-09-01T12:00:00.000Z');
    });

    it('refuses confirmation for a paused schedule', async () => {
      schedules.findOneBy.mockResolvedValue(owned({ status: 'PAUSED' }));
      await expect(
        service.confirmOccurrence(customerId, 's1', now),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(bookings.create).not.toHaveBeenCalled();
    });

    it('refuses a past-due occurrence beyond the grace window', async () => {
      schedules.findOneBy.mockResolvedValue(
        owned({
          nextOccurrenceAt: new Date('2026-08-20T12:00:00.000Z'),
        }),
      );
      await expect(
        service.confirmOccurrence(customerId, 's1', now),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(bookings.create).not.toHaveBeenCalled();
    });
  });
});
