import { managementRequest } from "../management-api";
import type { UserPage, UserSummary } from "./types";

export function listUsers(search?: string, cursor?: string) {
  const query = new URLSearchParams({ limit: "20" });
  if (search) query.set("search", search);
  if (cursor) query.set("cursor", cursor);
  return managementRequest<UserPage>(`/admin/users?${query}`);
}

export function getUser(userId: string) {
  return managementRequest<UserSummary>(`/admin/users/${encodeURIComponent(userId)}`);
}
