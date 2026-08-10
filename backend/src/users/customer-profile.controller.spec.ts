import { CustomerProfileController } from './customer-profile.controller';
import { CustomerProfileService } from './customer-profile.service';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';

describe('CustomerProfileController', () => {
  const profiles = { read: jest.fn(), update: jest.fn() };
  const controller = new CustomerProfileController(
    profiles as unknown as CustomerProfileService,
  );
  const request = {
    authorizationPrincipal: {
      userId: 'authenticated-user',
      sessionId: 'session-1',
      roles: ['customer'],
    },
  } as unknown as AuthorizedRequest;

  beforeEach(() => jest.clearAllMocks());

  it('reads only the authenticated principal profile', async () => {
    profiles.read.mockResolvedValue({ displayName: null });
    await expect(controller.read(request)).resolves.toEqual({
      displayName: null,
    });
    expect(profiles.read).toHaveBeenCalledWith('authenticated-user');
  });

  it('updates only the authenticated principal profile', async () => {
    profiles.update.mockResolvedValue({ displayName: 'Ada' });
    await expect(
      controller.update(request, { displayName: 'Ada' }),
    ).resolves.toEqual({ displayName: 'Ada' });
    expect(profiles.update).toHaveBeenCalledWith('authenticated-user', 'Ada');
  });
});
