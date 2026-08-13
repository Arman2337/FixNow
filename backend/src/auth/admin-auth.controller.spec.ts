import { AdminAuthController } from './admin-auth.controller';
import type { AuthService } from './auth.service';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';

describe('AdminAuthController', () => {
  const loginAdmin = jest.fn();
  const controller = new AdminAuthController({
    loginAdmin,
  } as unknown as AuthService);

  beforeEach(() => jest.clearAllMocks());

  it('delegates staff login without exposing credential details', async () => {
    const input = {
      email: 'staff@example.com',
      password: 'A secure password value',
    };
    loginAdmin.mockResolvedValue({ userId: 'staff-1', role: 'support_agent' });
    await expect(controller.login(input)).resolves.toMatchObject({
      role: 'support_agent',
    });
    expect(loginAdmin).toHaveBeenCalledWith(input);
  });

  it('returns only the authorized principal session summary', () => {
    const request = {
      authorizationPrincipal: {
        userId: 'staff-1',
        sessionId: 'session-1',
        roles: ['support_agent'],
      },
    } as unknown as AuthorizedRequest;
    expect(controller.session(request)).toEqual({
      userId: 'staff-1',
      roles: ['support_agent'],
    });
  });
});
