"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { claimProviderApplication, decideProviderApplication } from "./api";
import type { ProviderStatus } from "./types";
import { validDecision } from "./validation";

export async function claimAction(formData: FormData): Promise<void> {
  const id = String(formData.get("applicationId") ?? "");
  const version = Number(formData.get("expectedVersion"));
  const result = await claimProviderApplication(id, version);
  if (!result.ok) redirect(`/providers/${id}?result=${result.status === 409 ? "stale" : "failed"}`);
  revalidatePath(`/providers/${id}`);
  redirect(`/providers/${id}?result=claimed`);
}

export async function decisionAction(formData: FormData): Promise<void> {
  const id = String(formData.get("applicationId") ?? "");
  const version = Number(formData.get("expectedVersion"));
  const decision = String(formData.get("decision") ?? "") as ProviderStatus;
  const reason = String(formData.get("reason") ?? "").trim();
  if (!validDecision(decision, reason)) redirect(`/providers/${id}?result=invalid`);
  const result = await decideProviderApplication(id, version, decision, reason);
  if (!result.ok) redirect(`/providers/${id}?result=${result.status === 409 ? "stale" : result.status === 403 ? "forbidden" : "failed"}`);
  revalidatePath(`/providers/${id}`);
  redirect(`/providers/${id}?result=decided`);
}
