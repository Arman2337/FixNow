import { managementRequest } from "../management-api";
import type { TrustSignalSummary, TrustSignalStatus } from "./types";

export function listSignals(limit?: number, offset?: number, status?: TrustSignalStatus) {
  const query = new URLSearchParams();
  if (limit !== undefined) query.set("limit", String(limit));
  if (offset !== undefined) query.set("offset", String(offset));
  if (status) query.set("status", status);
  return managementRequest<readonly TrustSignalSummary[]>(
    `/admin/trust/signals${query.toString() ? `?${query}` : ""}`,
  );
}

export const reviewSignal = (
  id: string,
  status: Extract<TrustSignalStatus, "REVIEWED" | "DISMISSED">,
) =>
  managementRequest<TrustSignalSummary>(
    `/admin/trust/signals/${encodeURIComponent(id)}`,
    { method: "PATCH", body: JSON.stringify({ status }) },
  );

export const moderateReview = (
  id: string,
  moderationStatus: "PUBLISHED" | "HIDDEN" | "FLAGGED",
  reason: string,
) =>
  managementRequest<{ review: unknown }>(
    `/admin/reviews/${encodeURIComponent(id)}/moderation`,
    {
      method: "PATCH",
      body: JSON.stringify({ moderationStatus, reason }),
    },
  );

export const moderatePhoto = (
  photoId: string,
  status: "APPROVED" | "REJECTED",
  reason: string,
) =>
  managementRequest<{ photo: unknown }>(
    `/admin/reviews/photos/${encodeURIComponent(photoId)}/moderation`,
    {
      method: "PATCH",
      body: JSON.stringify({ status, reason }),
    },
  );
