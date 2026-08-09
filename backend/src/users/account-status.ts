export enum AccountStatus {
  PendingVerification = 'pending_verification',
  Active = 'active',
  Restricted = 'restricted',
  Suspended = 'suspended',
  Deactivated = 'deactivated',
  DeletionPending = 'deletion_pending',
  DeletedAnonymized = 'deleted_anonymized',
}

const allowedTransitions: Readonly<
  Record<AccountStatus, readonly AccountStatus[]>
> = {
  [AccountStatus.PendingVerification]: [
    AccountStatus.Active,
    AccountStatus.Suspended,
    AccountStatus.DeletionPending,
  ],
  [AccountStatus.Active]: [
    AccountStatus.Restricted,
    AccountStatus.Suspended,
    AccountStatus.Deactivated,
    AccountStatus.DeletionPending,
  ],
  [AccountStatus.Restricted]: [
    AccountStatus.Active,
    AccountStatus.Suspended,
    AccountStatus.Deactivated,
    AccountStatus.DeletionPending,
  ],
  [AccountStatus.Suspended]: [
    AccountStatus.Active,
    AccountStatus.Restricted,
    AccountStatus.Deactivated,
    AccountStatus.DeletionPending,
  ],
  [AccountStatus.Deactivated]: [
    AccountStatus.Active,
    AccountStatus.DeletionPending,
  ],
  [AccountStatus.DeletionPending]: [
    AccountStatus.Active,
    AccountStatus.DeletedAnonymized,
  ],
  [AccountStatus.DeletedAnonymized]: [],
};

export function canTransitionAccountStatus(
  from: AccountStatus,
  to: AccountStatus,
): boolean {
  return allowedTransitions[from].includes(to);
}
