import { managementRequest } from "../management-api";
import type { ProviderApplicationDetail, ProviderApplicationPage, ProviderDocument, ProviderStatus } from "./types";

export function listProviderApplications(search?: string, status?: string, cursor?: string) {
  const query = new URLSearchParams({ limit: "20" });
  if (search) query.set("search", search);
  if (status) query.set("status", status);
  if (cursor) query.set("cursor", cursor);
  return managementRequest<ProviderApplicationPage>(`/admin/provider-applications?${query}`);
}
export const getProviderApplication = (id: string) => managementRequest<ProviderApplicationDetail>(`/admin/provider-applications/${encodeURIComponent(id)}`);
export const listProviderDocuments = (id: string) => managementRequest<{ documents: readonly ProviderDocument[] }>(`/admin/provider-applications/${encodeURIComponent(id)}/documents`);
export const claimProviderApplication = (id: string, expectedVersion: number) => managementRequest<ProviderApplicationDetail>(`/admin/provider-applications/${encodeURIComponent(id)}/claim`, { method: "POST", body: JSON.stringify({ expectedVersion }) });
export const decideProviderApplication = (id: string, expectedVersion: number, decision: ProviderStatus, reason: string) => managementRequest<ProviderApplicationDetail>(`/admin/provider-applications/${encodeURIComponent(id)}/decision`, { method: "POST", body: JSON.stringify({ expectedVersion, decision, reason }) });
