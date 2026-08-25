import { managementRequest } from "../management-api";
import type { TrustSignalSummary, TrustSignalStatus } from "./types";

export const listSignals = () =>
  managementRequest<readonly TrustSignalSummary[]>("/admin/trust/signals");

export const reviewSignal = (
  id: string,
  status: Extract<TrustSignalStatus, "REVIEWED" | "DISMISSED">,
) =>
  managementRequest<TrustSignalSummary>(
    `/admin/trust/signals/${encodeURIComponent(id)}`,
    { method: "PATCH", body: JSON.stringify({ status }) },
  );
