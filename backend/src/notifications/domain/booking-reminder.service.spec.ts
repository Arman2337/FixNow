import { BookingReminderService } from './booking-reminder.service';

describe('BookingReminderService', () => {
  const bookingId = '00000000-0000-4000-8000-00000000b001';
  const customerId = '00000000-0000-4000-8000-00000000b002';
  const providerId = '00000000-0000-4000-8000-00000000b003';

  const bookings = { find: jest.fn() };
  const send = jest.fn().mockResolvedValue(undefined);
  const service = new BookingReminderService(
    bookings as never,
    { send } as never,
  );

  beforeEach(() => jest.clearAllMocks());

  const upcoming = (overrides: Record<string, unknown> = {}) => ({
    id: bookingId,
    customerId,
    providerId,
    ...overrides,
  });

  it('reminds both the customer and the assigned provider with permanent dedupe keys', async () => {
    bookings.find.mockResolvedValue([upcoming()]);
    await expect(service.scanOnce()).resolves.toBe(1);
    expect(send).toHaveBeenCalledWith(
      customerId,
      'booking:reminder',
      `reminder:booking:${bookingId}:customer`,
      expect.objectContaining({
        body: 'Your FixNow service is starting soon.',
      }),
      bookingId,
    );
    expect(send).toHaveBeenCalledWith(
      providerId,
      'booking:reminder',
      `reminder:booking:${bookingId}:provider`,
      expect.objectContaining({
        body: 'You have an assigned FixNow job starting soon.',
      }),
      bookingId,
    );
  });

  it('reminds only the customer when no provider is assigned yet', async () => {
    bookings.find.mockResolvedValue([upcoming({ providerId: null })]);
    await service.scanOnce();
    expect(send).toHaveBeenCalledTimes(1);
    expect(send).toHaveBeenCalledWith(
      customerId,
      'booking:reminder',
      expect.any(String),
      expect.anything(),
      bookingId,
    );
  });

  it('queries only eligible upcoming bookings inside the lead window', async () => {
    bookings.find.mockResolvedValue([]);
    await service.scanOnce();
    const query = (
      bookings.find.mock.calls as Array<[Record<string, unknown>]>
    )[0][0];
    const statusOperator = query['where'] as {
      status: { value: string[] };
    };
    expect(statusOperator.status.value).toEqual(
      expect.arrayContaining(['REQUESTED', 'ASSIGNED']),
    );
    expect(query['take']).toBe(50);
  });

  it('the interval wrapper swallows scan failures so ticks never crash the app', async () => {
    bookings.find.mockRejectedValue(new Error('db down'));
    await expect(
      (service as unknown as { scanSafely(): Promise<void> }).scanSafely(),
    ).resolves.toBeUndefined();
  });

  it('stops its timer on module destroy', () => {
    const clearSpy = jest.spyOn(global, 'clearInterval');
    // Simulate a started timer without running real intervals in tests.
    (service as unknown as { timer: NodeJS.Timeout }).timer =
      {} as NodeJS.Timeout;
    service.onModuleDestroy();
    expect(clearSpy).toHaveBeenCalled();
    clearSpy.mockRestore();
  });
});
