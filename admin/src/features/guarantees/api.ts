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

export function listClaims(status?: string) {
  const query = status ? `?${new URLSearchParams({ status })}` : "";
  return managementRequest<readonly GuaranteeClaim[]>(`/guarantees/claims${query}`);
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
