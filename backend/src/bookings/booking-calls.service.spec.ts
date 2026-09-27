import { ConflictException, ForbiddenException } from '@nestjs/common';
import type { Repository } from 'typeorm';
import { BookingStatus } from '../../../shared/booking-lifecycle.types';
import { Booking } from './domain/booking.entity';
import { BookingCall } from './domain/booking-call.entity';
import { BookingMessage } from './domain/booking-message.entity';
import { BookingCallsService } from './booking-calls.service';
import type { BookingProjectionService } from '../realtime/booking-projection.service';

describe('BookingCallsService', () => {
  let service: BookingCallsService;
  let bookingsRepo: jest.Mocked<Repository<Booking>>;
  let callsRepo: jest.Mocked<Repository<BookingCall>>;
  let messagesRepo: jest.Mocked<Repository<BookingMessage>>;
  let projections: jest.Mocked<BookingProjectionService>;

  const customerId = '00000000-0000-4000-8000-000000000001';
  const providerId = '00000000-0000-4000-8000-000000000002';
  const strangerId = '00000000-0000-4000-8000-000000000099';
  const bookingId = '00000000-0000-4000-8000-000000000101';
  const callId = '00000000-0000-4000-8000-000000000301';

  const mockBooking = (status = BookingStatus.ASSIGNED): Booking =>
    Object.assign(new Booking(), {
      id: bookingId,
      customerId,
      providerId,
      status,
      version: 1,
    });

  const mockCall = (overrides: Partial<BookingCall> = {}): BookingCall =>
    Object.assign(new BookingCall(), {
      id: callId,
      bookingId,
      callerUserId: customerId,
      callerRole: 'CUSTOMER',
      calleeUserId: providerId,
      status: 'RINGING',
      startedAt: new Date('2026-08-27T10:00:00Z'),
      connectedAt: null,
      endedAt: null,
      durationSeconds: null,
      ...overrides,
    });

  beforeEach(() => {
    bookingsRepo = {
      findOne: jest.fn(),
    } as unknown as jest.Mocked<Repository<Booking>>;

    callsRepo = {
      findOne: jest.fn(),
      create: jest.fn((dto: Partial<BookingCall>) =>
        Object.assign(new BookingCall(), dto, {
          id: callId,
          startedAt: new Date(),
        }),
      ),
      save: jest.fn((entity) => Promise.resolve(entity)),
      update: jest.fn().mockResolvedValue({ affected: 0 }),
    } as unknown as jest.Mocked<Repository<BookingCall>>;

    messagesRepo = {
      create: jest.fn((dto: Partial<BookingMessage>) =>
        Object.assign(new BookingMessage(), dto, {
          id: 'msg-id',
          createdAt: new Date(),
        }),
      ),
      save: jest.fn((entity) => Promise.resolve(entity)),
    } as unknown as jest.Mocked<Repository<BookingMessage>>;

    projections = {
      publishCallSignal: jest.fn(),
      publishChatMessage: jest.fn(),
    } as unknown as jest.Mocked<BookingProjectionService>;

    service = new BookingCallsService(
      bookingsRepo,
      callsRepo,
      messagesRepo,
      projections,
    );
  });

  describe('initiateCall', () => {
    it('creates call and broadcasts call.incoming.v1 during ASSIGNED status', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.ASSIGNED),
      );

      const result = await service.initiateCall(bookingId, customerId);

      expect(result.call.status).toBe('RINGING');
      expect(result.call.calleeUserId).toBe(providerId);
      const [signalBookingId, signalType, signal] =
        projections.publishCallSignal.mock.calls[0] ?? [];
      expect(signalBookingId).toBe(bookingId);
      expect(signalType).toBe('call.incoming.v1');
      expect(signal).toMatchObject({ status: 'RINGING' });
    });

    it('creates call during EN_ROUTE status', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.EN_ROUTE),
      );

      const result = await service.initiateCall(bookingId, customerId);

      expect(result.call.status).toBe('RINGING');
    });

    it('rejects call when booking is CANCELLED with ConflictException', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.CANCELLED),
      );

      await expect(service.initiateCall(bookingId, customerId)).rejects.toThrow(
        ConflictException,
      );
    });

    it('rejects call when booking is COMPLETED with ConflictException', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.COMPLETED),
      );

      await expect(service.initiateCall(bookingId, customerId)).rejects.toThrow(
        ConflictException,
      );
    });

    it('rejects call from non-participant with ForbiddenException', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.ASSIGNED),
      );

      await expect(service.initiateCall(bookingId, strangerId)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('returns active call when found', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.ASSIGNED),
      );
      callsRepo.findOne.mockResolvedValue(mockCall());

      const result = await service.getActiveCall(bookingId, customerId);
      expect(result).not.toBeNull();
      expect(result?.status).toBe('RINGING');
    });

    it('returns null when no active call exists', async () => {
      bookingsRepo.findOne.mockResolvedValue(
        mockBooking(BookingStatus.ASSIGNED),
      );
      callsRepo.findOne.mockResolvedValue(null);

      const result = await service.getActiveCall(bookingId, customerId);
      expect(result).toBeNull();
    });
  });

  describe('answerCall', () => {
    it('connects call and broadcasts call.answered.v1', async () => {
      callsRepo.findOne.mockResolvedValue(mockCall());

      const result = await service.answerCall(bookingId, callId, providerId);

      expect(result.status).toBe('CONNECTED');
      expect(result.connectedAt).toBeDefined();
      const [signalBookingId, signalType, signal] =
        projections.publishCallSignal.mock.calls[0] ?? [];
      expect(signalBookingId).toBe(bookingId);
      expect(signalType).toBe('call.answered.v1');
      expect(signal).toMatchObject({ status: 'CONNECTED' });
    });

    it('rejects answer from wrong user with ForbiddenException', async () => {
      callsRepo.findOne.mockResolvedValue(mockCall());

      await expect(
        service.answerCall(bookingId, callId, strangerId),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('rejectCall', () => {
    it('marks call REJECTED, broadcasts signal, and logs missed call in chat', async () => {
      callsRepo.findOne.mockResolvedValue(mockCall());

      const result = await service.rejectCall(bookingId, callId, providerId);

      expect(result.status).toBe('REJECTED');
      const [signalBookingId, signalType] =
        projections.publishCallSignal.mock.calls[0] ?? [];
      expect(signalBookingId).toBe(bookingId);
      expect(signalType).toBe('call.rejected.v1');
      const savedMessage = messagesRepo.save.mock.calls[0]?.[0];
      expect(savedMessage?.messageText).toContain('Missed in-app audio call');
    });
  });

  describe('hangupCall', () => {
    it('computes duration, sets status ENDED, and logs summary into chat', async () => {
      const connected = mockCall({
        status: 'CONNECTED',
        connectedAt: new Date(Date.now() - 134000), // 2m 14s ago
      });
      callsRepo.findOne.mockResolvedValue(connected);

      const result = await service.hangupCall(bookingId, callId, customerId);

      expect(result.status).toBe('ENDED');
      expect(result.durationSeconds).toBeGreaterThanOrEqual(130);
      const [signalBookingId, signalType] =
        projections.publishCallSignal.mock.calls[0] ?? [];
      expect(signalBookingId).toBe(bookingId);
      expect(signalType).toBe('call.ended.v1');
      const savedMessage = messagesRepo.save.mock.calls[0]?.[0];
      expect(savedMessage?.messageText).toMatch(
        /📞 In-app audio call ended • \d+m \d+s/,
      );
    });
  });

  // The transcript entry used to be written with the caller's id and role
  // whatever the actor was, so a callee hanging up or rejecting was recorded as
  // though the caller had done it. This is the record a dispute is read from.
  describe('call transcript attributes the actor, not the caller', () => {
    it('records the callee when the callee rejects the call', async () => {
      callsRepo.findOne.mockResolvedValue(mockCall());

      // providerId is the callee here.
      await service.rejectCall(bookingId, callId, providerId);

      const saved = messagesRepo.save.mock.calls[0]?.[0];
      expect(saved?.senderUserId).toBe(providerId);
      expect(saved?.senderRole).toBe('PROVIDER');
    });

    it('records the caller when the caller rejects their own call', async () => {
      callsRepo.findOne.mockResolvedValue(mockCall());

      await service.rejectCall(bookingId, callId, customerId);

      const saved = messagesRepo.save.mock.calls[0]?.[0];
      expect(saved?.senderUserId).toBe(customerId);
      expect(saved?.senderRole).toBe('CUSTOMER');
    });

    it('records the callee when the callee hangs up', async () => {
      callsRepo.findOne.mockResolvedValue(
        mockCall({
          status: 'CONNECTED',
          connectedAt: new Date(Date.now() - 5000),
        }),
      );

      await service.hangupCall(bookingId, callId, providerId);

      const saved = messagesRepo.save.mock.calls[0]?.[0];
      expect(saved?.senderUserId).toBe(providerId);
      expect(saved?.senderRole).toBe('PROVIDER');
    });

    it('derives the actor role correctly when the provider placed the call', async () => {
      // A provider-initiated call flips which side is the caller.
      callsRepo.findOne.mockResolvedValue(
        mockCall({
          callerUserId: providerId,
          callerRole: 'PROVIDER',
          calleeUserId: customerId,
          status: 'CONNECTED',
          connectedAt: new Date(Date.now() - 5000),
        }),
      );

      // The customer (now the callee) ends it.
      await service.hangupCall(bookingId, callId, customerId);

      const saved = messagesRepo.save.mock.calls[0]?.[0];
      expect(saved?.senderUserId).toBe(customerId);
      expect(saved?.senderRole).toBe('CUSTOMER');
    });
  });
});
