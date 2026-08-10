export const PERMISSIONS = {
  profileReadSelf: 'users.profile.read.self',
  profileUpdateSelf: 'users.profile.update.self',
  sessionRevokeSelf: 'access.session.revoke.self',
  providerApplicationReadSelf: 'providers.application.read.self',
  providerApplicationUpdateSelf: 'providers.application.update.self',
  providerApplicationReviewAssigned: 'providers.application.review.assigned',
  bookingCreateSelf: 'bookings.request.create.self',
  roleGrantAuthorized: 'access.role.grant.authorized',
  securityAuditReadAuthorized: 'access.audit.read.authorized',
} as const;

export type Permission = (typeof PERMISSIONS)[keyof typeof PERMISSIONS];

export type RoleCode =
  | 'customer'
  | 'provider_applicant'
  | 'verified_provider'
  | 'provider_reviewer'
  | 'support_agent'
  | 'trust_safety_reviewer'
  | 'finance_operator'
  | 'service_catalog_manager'
  | 'operations_administrator'
  | 'security_administrator'
  | 'auditor';

export interface PermissionPolicy {
  readonly roles: readonly RoleCode[];
  readonly relationship?: 'self' | 'assigned';
  readonly forbidSelfTarget?: boolean;
  readonly requireIndependentApproval?: boolean;
}

const allHumanRoles: readonly RoleCode[] = [
  'customer',
  'provider_applicant',
  'verified_provider',
  'provider_reviewer',
  'support_agent',
  'trust_safety_reviewer',
  'finance_operator',
  'service_catalog_manager',
  'operations_administrator',
  'security_administrator',
  'auditor',
];

export const PERMISSION_POLICIES: Readonly<
  Record<Permission, PermissionPolicy>
> = {
  [PERMISSIONS.profileReadSelf]: {
    roles: allHumanRoles,
    relationship: 'self',
  },
  [PERMISSIONS.profileUpdateSelf]: {
    roles: allHumanRoles,
    relationship: 'self',
  },
  [PERMISSIONS.sessionRevokeSelf]: {
    roles: allHumanRoles,
    relationship: 'self',
  },
  [PERMISSIONS.providerApplicationReadSelf]: {
    roles: ['provider_applicant', 'verified_provider'],
    relationship: 'self',
  },
  [PERMISSIONS.providerApplicationUpdateSelf]: {
    roles: ['provider_applicant', 'verified_provider'],
    relationship: 'self',
  },
  [PERMISSIONS.providerApplicationReviewAssigned]: {
    roles: ['provider_reviewer', 'operations_administrator'],
    relationship: 'assigned',
  },
  [PERMISSIONS.bookingCreateSelf]: {
    roles: ['customer'],
    relationship: 'self',
  },
  [PERMISSIONS.roleGrantAuthorized]: {
    roles: ['security_administrator'],
    forbidSelfTarget: true,
    requireIndependentApproval: true,
  },
  [PERMISSIONS.securityAuditReadAuthorized]: {
    roles: ['security_administrator', 'auditor'],
  },
};
