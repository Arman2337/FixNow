import { AccountStatus, canTransitionAccountStatus } from './account-status';

describe('account status lifecycle', () => {
  it('allows defined remediation and deletion transitions', () => {
    expect(
      canTransitionAccountStatus(
        AccountStatus.PendingVerification,
        AccountStatus.Active,
      ),
    ).toBe(true);
    expect(
      canTransitionAccountStatus(
        AccountStatus.Suspended,
        AccountStatus.Restricted,
      ),
    ).toBe(true);
    expect(
      canTransitionAccountStatus(
        AccountStatus.DeletionPending,
        AccountStatus.DeletedAnonymized,
      ),
    ).toBe(true);
  });

  it('makes anonymized deletion terminal and rejects self-transitions', () => {
    expect(
      canTransitionAccountStatus(
        AccountStatus.DeletedAnonymized,
        AccountStatus.Active,
      ),
    ).toBe(false);
    expect(
      canTransitionAccountStatus(AccountStatus.Active, AccountStatus.Active),
    ).toBe(false);
  });
});
