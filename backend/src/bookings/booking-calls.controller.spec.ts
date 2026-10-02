import { ForbiddenException } from '@nestjs/common';
import { BookingCallsController } from './booking-calls.controller';
import type { BookingCallsService } from './booking-calls.service';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';

describe('BookingCallsController', () => {
  let controller: BookingCallsController;
  let service: jest.Mocked<BookingCallsService>;

  const userId = '00000000-0000-4000-8000-000000000001';
  const bookingId = '00000000-0000-4000-8000-000000000101';
  const callId = '00000000-0000-4000-8000-000000000301';

  const req = {
    authorizationPrincipal: { userId, roles: ['customer'] },
  } as unknown as AuthorizedRequest;

  const mockCallDto = {
    id: callId,
    bookingId,
    callerUserId: userId,
    callerRole: 'CUSTOMER' as const,
    calleeUserId: 'provider-1',
    status: 'RINGING' as const,
    startedAt: '2026-08-27T10:00:00Z',
  };

  beforeEach(() => {
    service = {
      initiateCall: jest.fn(),
      answerCall: jest.fn(),
      rejectCall: jest.fn(),
      hangupCall: jest.fn(),
    } as unknown as jest.Mocked<BookingCallsService>;

    controller = new BookingCallsController(service);
  });

  it('delegates initiate to service', async () => {
    service.initiateCall.mockResolvedValue({ call: mockCallDto });

    const result = await controller.initiate(req, bookingId);

    // SEC-002: the principal is handed to the service so the booking-party
    // obligation is discharged where the booking is loaded.
    expect(service.initiateCall.mock.calls).toEqual([
      [bookingId, userId, req.authorizationPrincipal],
    ]);
    expect(result.call.id).toBe(callId);
  });

  it('delegates answer to service', async () => {
    service.answerCall.mockResolvedValue({
      ...mockCallDto,
      status: 'CONNECTED',
    });

    const result = await controller.answer(req, bookingId, callId);

    expect(service.answerCall.mock.calls).toEqual([
      [bookingId, callId, userId],
    ]);
    expect(result.status).toBe('CONNECTED');
  });

  it('delegates reject to service', async () => {
    service.rejectCall.mockResolvedValue({
      ...mockCallDto,
      status: 'REJECTED',
    });

    const result = await controller.reject(req, bookingId, callId);

    expect(service.rejectCall.mock.calls).toEqual([
      [bookingId, callId, userId],
    ]);
    expect(result.status).toBe('REJECTED');
  });

  it('delegates hangup to service', async () => {
    service.hangupCall.mockResolvedValue({
      ...mockCallDto,
      status: 'ENDED',
      durationSeconds: 45,
    });

    const result = await controller.hangup(req, bookingId, callId);

    expect(service.hangupCall.mock.calls).toEqual([
      [bookingId, callId, userId],
    ]);
    expect(result.status).toBe('ENDED');
  });

  // SEC-002: a call's two endpoints are the booking's two parties, so proving
  // the caller is one of them is what discharges the booking-ownership duty.
  it('refuses to answer a call the caller is not an endpoint of', async () => {
    service.answerCall.mockResolvedValue({
      ...mockCallDto,
      callerUserId: 'someone-else',
      calleeUserId: 'another-provider',
      status: 'CONNECTED',
    });

    await expect(
      controller.answer(req, bookingId, callId),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('refuses to hang up a call the caller is not an endpoint of', async () => {
    service.hangupCall.mockResolvedValue({
      ...mockCallDto,
      callerUserId: 'someone-else',
      calleeUserId: 'another-provider',
      status: 'ENDED',
    });

    await expect(
      controller.hangup(req, bookingId, callId),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
