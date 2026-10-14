import type { StaffRole } from "./types";
import { staffRoles } from "./types";

export { staffRoles, type StaffRole };

export const STAFF_PERMISSIONS = {
  adminSessionReadSelf: [
    "provider_reviewer",
    "support_agent",
    "trust_safety_reviewer",
    "finance_operator",
    "service_catalog_manager",
    "operations_administrator",
    "security_administrator",
    "auditor",
  ],
  adminUsersRead: [
    "support_agent",
    "operations_administrator",
    "security_administrator",
    "auditor",
  ],
  adminProviderApplicationsRead: [
    "provider_reviewer",
    "operations_administrator",
    "auditor",
  ],
  adminProviderDocumentsRead: [
    "provider_reviewer",
    "operations_administrator",
  ],
  adminServicesRead: [
    "service_catalog_manager",
    "operations_administrator",
    "auditor",
  ],
  adminServicesCreate: [
    "service_catalog_manager",
    "operations_administrator",
  ],
  adminServicesUpdate: [
    "service_catalog_manager",
    "operations_administrator",
  ],
  adminServicesDelete: [
    "service_catalog_manager",
    "operations_administrator",
  ],
  adminBookingsRead: [
    "support_agent",
    "trust_safety_reviewer",
    "operations_administrator",
    "auditor",
  ],
  adminBookingsIntervene: [
    "trust_safety_reviewer",
    "operations_administrator",
  ],
  adminComplaintsRead: [
    "support_agent",
    "trust_safety_reviewer",
    "operations_administrator",
  ],
  adminComplaintsUpdate: [
    "support_agent",
    "trust_safety_reviewer",
    "operations_administrator",
  ],
  adminGuaranteesRead: [
    "support_agent",
    "trust_safety_reviewer",
    "operations_administrator",
    "auditor",
  ],
  adminGuaranteesUpdate: [
    "support_agent",
    "trust_safety_reviewer",
    "operations_administrator",
  ],
  trustSignalsRead: [
    "trust_safety_reviewer",
    "operations_administrator",
  ],
  trustSignalsUpdate: [
    "trust_safety_reviewer",
    "operations_administrator",
  ],
  reviewModerate: [
    "trust_safety_reviewer",
    "operations_administrator",
  ],
  adminAnalyticsRead: [
    "operations_administrator",
    "auditor",
  ],
  adminSystemHealthRead: [
    "operations_administrator",
    "security_administrator",
    "auditor",
  ],
} as const satisfies Record<string, readonly StaffRole[]>;

export type StaffPermission = keyof typeof STAFF_PERMISSIONS;

export function hasPermission(
  roles: readonly StaffRole[],
  permission: StaffPermission,
): boolean {
  const allowed = STAFF_PERMISSIONS[permission] as readonly StaffRole[] | undefined;
  if (!allowed) return false;
  return roles.some((role) => allowed.includes(role));
}

export function canMutateServices(roles: readonly StaffRole[]): boolean {
  return hasPermission(roles, "adminServicesCreate") || hasPermission(roles, "adminServicesUpdate");
}

export function canModerateReviews(roles: readonly StaffRole[]): boolean {
  return hasPermission(roles, "reviewModerate");
}
