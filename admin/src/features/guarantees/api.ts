import { getSession } from "@/auth/session";
import { fetchManagementApi } from "../management-api";

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

export async function listClaims(status?: string) {
  const session = await getSession();
  if (session.state !== "authenticated") {
    return { ok: false as const, error: "Unauthorized" };
  }
  const query = status ? `?status=${status}` : "";
  return fetchManagementApi<GuaranteeClaim[]>(`/api/v1/guarantees/claims${query}`, {
    session: session.session,
  });
}

export async function getClaim(id: string) {
  const session = await getSession();
  if (session.state !== "authenticated") {
    return { ok: false as const, error: "Unauthorized" };
  }
  return fetchManagementApi<GuaranteeClaim>(`/api/v1/guarantees/claims/${id}`, {
    session: session.session,
  });
}
