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
  adminServicesRead: 'admin.services.read',
  adminServicesUpdate: 'admin.services.update',
  adminServicesDelete: 'admin.services.delete',
  adminSkillsUpdate: 'admin.skills.update',
  adminSkillsVerify: 'admin.skills.verify',
  adminSkillsDelete: 'admin.skills.delete',
  bookingCreateSelf: 'bookings.request.create.self',
  bookingScheduleManageSelf: 'bookings.schedule.manage.self',
  paymentOrderManageSelf: 'payments.order.manage.self',
  paymentRefundCreate: 'payments.refund.create',
  paymentInvoiceReadSelf: 'payments.invoice.read.self',
  providerEarningsReadSelf: 'provider.earnings.read.self',
  bookingAccept: 'bookings.accept',
  bookingAvailableRead: 'bookings.available.read',
  bookingUpdateStatus: 'bookings.update.status',
  bookingCancelSelf: 'bookings.cancel.self',
  bookingHistoryReadSelf: 'bookings.history.read.self',
  reviewCreateSelf: 'ratings.review.create.self',
  reviewReadBooking: 'ratings.review.read.booking',
  reviewModerate: 'ratings.review.moderate',
  trustSignalsRead: 'trust.signals.read',
  trustSignalsUpdate: 'trust.signals.update',
  realtimeConnect: 'realtime.connect',
  realtimeSubscribeSelf: 'realtime.subscribe.self',
  roleGrantAuthorized: 'access.role.grant.authorized',
  securityAuditReadAuthorized: 'access.audit.read.authorized',
  adminSessionReadSelf: 'admin.session.read.self',
  adminUsersRead: 'admin.users.read',
  adminProviderApplicationsRead: 'admin.provider-applications.read',
  adminProviderDocumentsRead: 'admin.provider-documents.read.assigned',
  adminBookingsRead: 'admin.bookings.read',
  adminBookingsIntervene: 'admin.bookings.intervene',
  pushTokenManageSelf: 'notifications.push.token.manage.self',
  trustAcceptTimeReadSelf: 'trust.accept-time.read.self',
  complaintsCreate: 'complaints.create',
  aiRecommendationCreate: 'ai.recommendation.create',
  aiPriceEstimateReadSelf: 'ai.price-estimate.read.self',
  complaintsReadSelf: 'complaints.read.self',
  adminComplaintsRead: 'admin.complaints.read',
  adminComplaintsUpdate: 'admin.complaints.update',
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
  readonly audience?: 'mobile' | 'admin';
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
  [PERMISSIONS.adminSessionReadSelf]: {
    roles: [
      'provider_reviewer',
      'support_agent',
      'trust_safety_reviewer',
      'finance_operator',
      'service_catalog_manager',
      'operations_administrator',
      'security_administrator',
      'auditor',
    ],
    audience: 'admin',
    relationship: 'self',
  },
  [PERMISSIONS.adminUsersRead]: {
    roles: [
      'support_agent',
      'operations_administrator',
      'security_administrator',
      'auditor',
    ],
    audience: 'admin',
  },
  [PERMISSIONS.adminProviderApplicationsRead]: {
    roles: ['provider_reviewer', 'operations_administrator', 'auditor'],
    audience: 'admin',
  },
  [PERMISSIONS.adminProviderDocumentsRead]: {
    roles: ['provider_reviewer', 'operations_administrator'],
    audience: 'admin',
  },
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
    audience: 'admin',
  },
  [PERMISSIONS.providerVerificationReview]: {
    roles: ['provider_reviewer', 'operations_administrator'],
    audience: 'admin',
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
    audience: 'admin',
  },
  [PERMISSIONS.adminServicesRead]: {
    roles: ['service_catalog_manager', 'operations_administrator', 'auditor'],
    audience: 'admin',
  },
  [PERMISSIONS.adminServicesUpdate]: {
    roles: ['service_catalog_manager', 'operations_administrator'],
    audience: 'admin',
  },
  [PERMISSIONS.adminServicesDelete]: {
    roles: ['service_catalog_manager', 'operations_administrator'],
    audience: 'admin',
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
  [PERMISSIONS.bookingScheduleManageSelf]: {
    roles: ['customer'],
    audience: 'mobile',
    relationship: 'self',
  },
  [PERMISSIONS.bookingAccept]: {
    roles: ['verified_provider'],
  },
  [PERMISSIONS.bookingAvailableRead]: {
    roles: ['verified_provider'],
    audience: 'mobile',
  },
  [PERMISSIONS.bookingUpdateStatus]: {
    roles: ['verified_provider'],
    relationship: 'self',
  },
  [PERMISSIONS.bookingCancelSelf]: {
    roles: ['customer', 'verified_provider'],
    relationship: 'self',
  },
  [PERMISSIONS.bookingHistoryReadSelf]: {
    roles: ['customer', 'verified_provider'],
    relationship: 'self',
  },
  [PERMISSIONS.reviewCreateSelf]: {
    roles: ['customer'],
    relationship: 'self',
  },
  [PERMISSIONS.reviewReadBooking]: {
    roles: ['customer', 'verified_provider'],
    relationship: 'self',
  },
  [PERMISSIONS.reviewModerate]: {
    roles: ['trust_safety_reviewer', 'operations_administrator'],
    audience: 'admin',
  },
  [PERMISSIONS.trustSignalsRead]: {
    roles: ['trust_safety_reviewer', 'operations_administrator'],
    audience: 'admin',
  },
  [PERMISSIONS.trustSignalsUpdate]: {
    roles: ['trust_safety_reviewer', 'operations_administrator'],
    audience: 'admin',
  },
  [PERMISSIONS.adminBookingsRead]: {
    roles: [
      'support_agent',
      'trust_safety_reviewer',
      'operations_administrator',
      'auditor',
    ],
    audience: 'admin',
  },
  [PERMISSIONS.adminBookingsIntervene]: {
    roles: ['trust_safety_reviewer', 'operations_administrator'],
    audience: 'admin',
  },
  [PERMISSIONS.realtimeConnect]: {
    roles: allHumanRoles,
  },
  [PERMISSIONS.realtimeSubscribeSelf]: {
    roles: allHumanRoles,
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
  [PERMISSIONS.complaintsCreate]: {
    roles: ['customer', 'verified_provider'],
  },
  [PERMISSIONS.aiRecommendationCreate]: {
    roles: ['customer'],
    relationship: 'self',
  },
  [PERMISSIONS.aiPriceEstimateReadSelf]: {
    roles: ['customer'],
    relationship: 'self',
  },
  [PERMISSIONS.complaintsReadSelf]: {
    roles: ['customer', 'verified_provider'],
    relationship: 'self',
  },
  [PERMISSIONS.pushTokenManageSelf]: {
    roles: allHumanRoles,
    relationship: 'self',
  },
  [PERMISSIONS.trustAcceptTimeReadSelf]: {
    roles: ['verified_provider'],
    audience: 'mobile',
    relationship: 'self',
  },
  [PERMISSIONS.paymentOrderManageSelf]: {
    roles: ['customer'],
    audience: 'mobile',
    relationship: 'self',
  },
  [PERMISSIONS.paymentRefundCreate]: {
    roles: ['support_agent', 'operations_administrator'],
    audience: 'admin',
  },
  [PERMISSIONS.paymentInvoiceReadSelf]: {
    roles: ['customer'],
    audience: 'mobile',
    relationship: 'self',
  },
  [PERMISSIONS.providerEarningsReadSelf]: {
    roles: ['verified_provider'],
    audience: 'mobile',
    relationship: 'self',
  },
  [PERMISSIONS.adminComplaintsRead]: {
    roles: [
      'support_agent',
      'trust_safety_reviewer',
      'operations_administrator',
    ],
    audience: 'admin',
  },
  [PERMISSIONS.adminComplaintsUpdate]: {
    roles: [
      'support_agent',
      'trust_safety_reviewer',
      'operations_administrator',
    ],
    audience: 'admin',
  },
};
