"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { reviewSignal } from "./api";

export async function reviewSignalAction(data: FormData) {
  const id = String(data.get("id") ?? "");
  const status = String(data.get("status") ?? "");
  if (status !== "REVIEWED" && status !== "DISMISSED") {
    redirect(`/trust?result=failed`);
  }
  const result = await reviewSignal(id, status);
  if (!result.ok) redirect(`/trust?result=${result.status === 409 ? "stale" : "failed"}`);
  revalidatePath("/trust");
  redirect(`/trust?result=${status === "REVIEWED" ? "reviewed" : "dismissed"}`);
}
