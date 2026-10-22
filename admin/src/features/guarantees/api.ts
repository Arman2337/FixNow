import { managementRequest } from "../management-api";

export interface GuaranteeClaim {
  id: string;
  bookingId: string;
  customerId: string;
  originalProviderId: string | null;
  status: string;
  description: string;
  evidenceUrls: string[] | null;
  adminNotes: string | null;
  assignedProviderId: string | null;
  reServiceBookingId: string | null;
  createdAt: string;
  updatedAt: string;
}

export type GuaranteeStatus = "PENDING" | "IN_REVIEW" | "MORE_INFO" | "APPROVED" | "REJECTED" | "COMPLETED";

export function listClaims(status?: string, limit = 20, offset = 0, search?: string) {
  const query = new URLSearchParams({ limit: String(limit), offset: String(offset) });
  if (status) query.set("status", status);
  if (search) query.set("search", search);
  return managementRequest<readonly GuaranteeClaim[]>(`/guarantees/claims?${query}`);
}

export function getClaim(id: string) {
  return managementRequest<GuaranteeClaim>(`/guarantees/claims/${encodeURIComponent(id)}`);
}

export function updateClaimStatus(id: string, status: GuaranteeStatus) {
  return managementRequest<GuaranteeClaim>(`/guarantees/claims/${encodeURIComponent(id)}/status`, {
    method: "PATCH",
    body: JSON.stringify({ status }),
  });
}

export function scheduleReService(id: string, providerId: string) {
  return managementRequest<unknown>(`/guarantees/claims/${encodeURIComponent(id)}/re-service`, {
    method: "POST",
    body: JSON.stringify({ providerId }),
  });
}
