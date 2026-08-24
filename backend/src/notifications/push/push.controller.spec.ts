import { PushDeviceController } from './push.controller';
import { PushDeviceService } from './push.service';
import type { AuthorizedRequest } from '../../common/authorization/authorization.guard';

describe('PushDeviceController', () => {
  const devices = {
    register: jest.fn(),
    list: jest.fn(),
    revoke: jest.fn(),
  };
  const controller = new PushDeviceController(
    devices as unknown as PushDeviceService,
  );
  const request = {
    authorizationPrincipal: {
      userId: 'authenticated-user',
      sessionId: 'session-1',
      roles: ['customer'],
    },
  } as unknown as AuthorizedRequest;
  const registration = { token: 'd'.repeat(64), platform: 'ANDROID' };

  beforeEach(() => jest.clearAllMocks());

  it('registers using the authenticated principal identity', async () => {
    devices.register.mockResolvedValue({ id: 'device-1' });
    await controller.register(request, registration as never);
    expect(devices.register).toHaveBeenCalledWith(
      'authenticated-user',
      registration,
    );
  });

  it('lists devices scoped to the principal', async () => {
    devices.list.mockResolvedValue([]);
    await controller.list(request);
    expect(devices.list).toHaveBeenCalledWith('authenticated-user');
  });

  it('revokes through the principal-scoped service call', async () => {
    devices.revoke.mockResolvedValue(undefined);
    await controller.revoke(request, 'device-9');
    expect(devices.revoke).toHaveBeenCalledWith(
      'authenticated-user',
      'device-9',
    );
  });
});
