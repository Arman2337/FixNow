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

    expect(service.initiateCall).toHaveBeenCalledWith(bookingId, userId);
    expect(result.call.id).toBe(callId);
  });

  it('delegates answer to service', async () => {
    service.answerCall.mockResolvedValue({
      ...mockCallDto,
      status: 'CONNECTED',
    });

    const result = await controller.answer(req, bookingId, callId);

    expect(service.answerCall).toHaveBeenCalledWith(bookingId, callId, userId);
    expect(result.status).toBe('CONNECTED');
  });

  it('delegates reject to service', async () => {
    service.rejectCall.mockResolvedValue({
      ...mockCallDto,
      status: 'REJECTED',
    });

    const result = await controller.reject(req, bookingId, callId);

    expect(service.rejectCall).toHaveBeenCalledWith(bookingId, callId, userId);
    expect(result.status).toBe('REJECTED');
  });

  it('delegates hangup to service', async () => {
    service.hangupCall.mockResolvedValue({
      ...mockCallDto,
      status: 'ENDED',
      durationSeconds: 45,
    });

    const result = await controller.hangup(req, bookingId, callId);

    expect(service.hangupCall).toHaveBeenCalledWith(bookingId, callId, userId);
    expect(result.status).toBe('ENDED');
  });
});
