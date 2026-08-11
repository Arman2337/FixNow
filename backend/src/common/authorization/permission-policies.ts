export const PERMISSIONS = {
  profileReadSelf: 'users.profile.read.self',
  profileUpdateSelf: 'users.profile.update.self',
  sessionRevokeSelf: 'access.session.revoke.self',
  providerApplicationReadSelf: 'providers.application.read.self',
  providerApplicationUpdateSelf: 'providers.application.update.self',
  providerApplicationReviewAssigned: 'providers.application.review.assigned',
  providerVerificationReview: 'providers.verification.review',
  providerSkillsRead: 'provider.skills.read',
  providerSkillsReadAny: 'provider.skills.read.any',
  providerSkillsCreate: 'provider.skills.create',
  providerSkillsUpdate: 'provider.skills.update',
  providerSkillsDelete: 'provider.skills.delete',
  providerProfileRead: 'provider.profile.read',
  providerProfileUpdate: 'provider.profile.update',
  providerAvailabilityRead: 'provider.availability.read',
  providerAvailabilityUpdate: 'provider.availability.update',
  providerDocumentsCreate: 'provider.documents.create',
  providerDocumentsRead: 'provider.documents.read',
  providerDocumentsDelete: 'provider.documents.delete',
  adminServicesCreate: 'admin.services.create',
  adminServicesUpdate: 'admin.services.update',
  adminServicesDelete: 'admin.services.delete',
  adminSkillsUpdate: 'admin.skills.update',
  adminSkillsVerify: 'admin.skills.verify',
  adminSkillsDelete: 'admin.skills.delete',
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
  [PERMISSIONS.providerVerificationReview]: {
    roles: ['provider_reviewer', 'operations_administrator'],
  },
  [PERMISSIONS.providerSkillsRead]: {
    roles: [
      'provider_applicant',
      'verified_provider',
      'provider_reviewer',
      'service_catalog_manager',
      'operations_administrator',
    ],
    relationship: 'self',
  },
  [PERMISSIONS.providerSkillsReadAny]: {
    roles: [
      'provider_reviewer',
      'service_catalog_manager',
      'operations_administrator',
      'auditor',
    ],
  },
  [PERMISSIONS.providerSkillsCreate]: {
    roles: ['provider_applicant', 'verified_provider'],
  },
  [PERMISSIONS.providerSkillsUpdate]: {
    roles: ['provider_applicant', 'verified_provider'],
  },
  [PERMISSIONS.providerSkillsDelete]: {
    roles: ['provider_applicant', 'verified_provider'],
  },
  [PERMISSIONS.providerProfileRead]: {
    roles: ['provider_applicant', 'verified_provider'],
    relationship: 'self',
  },
  [PERMISSIONS.providerProfileUpdate]: {
    roles: ['provider_applicant', 'verified_provider'],
    relationship: 'self',
  },
  [PERMISSIONS.providerAvailabilityRead]: {
    roles: ['verified_provider'],
    relationship: 'self',
  },
  [PERMISSIONS.providerAvailabilityUpdate]: {
    roles: ['verified_provider'],
    relationship: 'self',
  },
  [PERMISSIONS.providerDocumentsCreate]: {
    roles: ['provider_applicant'],
    relationship: 'self',
  },
  [PERMISSIONS.providerDocumentsRead]: {
    roles: ['provider_applicant'],
    relationship: 'self',
  },
  [PERMISSIONS.providerDocumentsDelete]: {
    roles: ['provider_applicant'],
    relationship: 'self',
  },
  [PERMISSIONS.adminServicesCreate]: {
    roles: ['service_catalog_manager', 'operations_administrator'],
  },
  [PERMISSIONS.adminServicesUpdate]: {
    roles: ['service_catalog_manager', 'operations_administrator'],
  },
  [PERMISSIONS.adminServicesDelete]: {
    roles: ['service_catalog_manager', 'operations_administrator'],
  },
  [PERMISSIONS.adminSkillsUpdate]: {
    roles: [
      'provider_reviewer',
      'service_catalog_manager',
      'operations_administrator',
    ],
  },
  [PERMISSIONS.adminSkillsVerify]: {
    roles: [
      'provider_reviewer',
      'service_catalog_manager',
      'operations_administrator',
    ],
  },
  [PERMISSIONS.adminSkillsDelete]: {
    roles: ['service_catalog_manager', 'operations_administrator'],
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
