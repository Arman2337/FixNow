import { describe, expect, it } from "vitest";
import { STAFF_PERMISSIONS, hasPermission, type StaffPermission } from "./roles";
import { PERMISSIONS, PERMISSION_POLICIES } from "../../../backend/src/common/authorization/permission-policies";

describe("admin permissions", () => {
  it("keeps every admin permission aligned with the backend authorization boundary", () => {
    for (const [name, roles] of Object.entries(STAFF_PERMISSIONS)) {
      const permission = PERMISSIONS[name as keyof typeof PERMISSIONS];
      expect(permission, name).toBeDefined();
      expect([...roles].sort(), name).toEqual([...PERMISSION_POLICIES[permission].roles].sort());
    }
  });
  it("denies unknown permissions and respects read-only grants", () => {
    expect(hasPermission(["auditor"], "adminServicesRead")).toBe(true);
    expect(hasPermission(["auditor"], "adminServicesUpdate")).toBe(false);
    expect(hasPermission(["support_agent"], "trustSignalsRead")).toBe(false);
    expect(hasPermission(["operations_administrator"], "unknown" as StaffPermission)).toBe(false);
  });
});
