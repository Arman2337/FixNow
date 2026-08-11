import { AccountStatus } from '../../users/account-status';
import { AuthorizationPolicyService } from './authorization-policy.service';
import type { AuthorizationPrincipal } from './authorization.types';
import { PERMISSIONS } from './permission-policies';

describe('AuthorizationPolicyService', () => {
  const policy = new AuthorizationPolicyService();
  const principal = (
    userId: string,
    roles: AuthorizationPrincipal['roles'],
  ): AuthorizationPrincipal => ({ userId, sessionId: 'session-1', roles });

  it('allows an active customer to act on their own resource', () => {
    expect(
      policy.isAllowed(
        {
          principal: principal('customer-1', ['customer']),
          permission: PERMISSIONS.bookingCreateSelf,
          context: { ownerId: 'customer-1' },
        },
        AccountStatus.Active,
      ),
    ).toBe(true);
  });

  it('denies cross-role access', () => {
    expect(
      policy.isAllowed(
        {
          principal: principal('applicant-1', ['provider_applicant']),
          permission: PERMISSIONS.bookingCreateSelf,
          context: { ownerId: 'applicant-1' },
        },
        AccountStatus.Active,
      ),
    ).toBe(false);
  });

  it('allows only a verified provider to manage their own availability', () => {
    expect(
      policy.isAllowed(
        {
          principal: principal('provider-1', ['verified_provider']),
          permission: PERMISSIONS.providerAvailabilityUpdate,
          context: { ownerId: 'provider-1' },
        },
        AccountStatus.Active,
      ),
    ).toBe(true);
    expect(
      policy.isAllowed(
        {
          principal: principal('applicant-1', ['provider_applicant']),
          permission: PERMISSIONS.providerAvailabilityUpdate,
          context: { ownerId: 'applicant-1' },
        },
        AccountStatus.Active,
      ),
    ).toBe(false);
    expect(
      policy.isAllowed(
        {
          principal: principal('provider-1', ['verified_provider']),
          permission: PERMISSIONS.providerAvailabilityUpdate,
          context: { ownerId: 'provider-2' },
        },
        AccountStatus.Active,
      ),
    ).toBe(false);
  });

  it.each([
    AccountStatus.PendingVerification,
    AccountStatus.Restricted,
    AccountStatus.Suspended,
    AccountStatus.Deactivated,
    AccountStatus.DeletionPending,
    AccountStatus.DeletedAnonymized,
  ])('denies inactive account status %s', (status) => {
    expect(
      policy.isAllowed(
        {
          principal: principal('customer-1', ['customer']),
          permission: PERMISSIONS.profileReadSelf,
          context: { ownerId: 'customer-1' },
        },
        status,
      ),
    ).toBe(false);
  });

  it('denies identifier tampering against another owner', () => {
    expect(
      policy.isAllowed(
        {
          principal: principal('customer-1', ['customer']),
          permission: PERMISSIONS.profileReadSelf,
          context: { ownerId: 'customer-2' },
        },
        AccountStatus.Active,
      ),
    ).toBe(false);
  });

  it('requires an authoritative reviewer assignment', () => {
    expect(
      policy.isAllowed(
        {
          principal: principal('reviewer-1', ['provider_reviewer']),
          permission: PERMISSIONS.providerApplicationReviewAssigned,
          context: { assignedPrincipalId: 'reviewer-2' },
        },
        AccountStatus.Active,
      ),
    ).toBe(false);
  });

  it('denies a non-security role attempting to grant roles', () => {
    expect(
      policy.isAllowed(
        {
          principal: principal('customer-1', ['customer']),
          permission: PERMISSIONS.roleGrantAuthorized,
          context: {
            targetPrincipalId: 'staff-1',
            independentApproval: true,
          },
        },
        AccountStatus.Active,
      ),
    ).toBe(false);
  });

  it('prevents security administrators from self-granting', () => {
    expect(
      policy.isAllowed(
        {
          principal: principal('security-1', ['security_administrator']),
          permission: PERMISSIONS.roleGrantAuthorized,
          context: {
            targetPrincipalId: 'security-1',
            independentApproval: true,
          },
        },
        AccountStatus.Active,
      ),
    ).toBe(false);
  });

  it('requires independent approval for an authorized role grant', () => {
    const input = {
      principal: principal('security-1', ['security_administrator']),
      permission: PERMISSIONS.roleGrantAuthorized,
      context: { targetPrincipalId: 'staff-1' },
    } as const;
    expect(policy.isAllowed(input, AccountStatus.Active)).toBe(false);
    expect(
      policy.isAllowed(
        { ...input, context: { ...input.context, independentApproval: true } },
        AccountStatus.Active,
      ),
    ).toBe(true);
  });
});
