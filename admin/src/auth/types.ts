export const staffRoles = [
  "provider_reviewer",
  "support_agent",
  "trust_safety_reviewer",
  "finance_operator",
  "service_catalog_manager",
  "operations_administrator",
  "security_administrator",
  "auditor",
] as const;

export type StaffRole = (typeof staffRoles)[number];
export type AdminSession = Readonly<{ userId: string; roles: readonly StaffRole[] }>;
export type AuthenticationResponse = Readonly<{
  userId: string;
  role: StaffRole;
  accessToken: string;
  refreshToken: string;
  tokenType: "Bearer";
  expiresIn: number;
}>;

export function isStaffRole(value: unknown): value is StaffRole {
  return typeof value === "string" && staffRoles.includes(value as StaffRole);
}
