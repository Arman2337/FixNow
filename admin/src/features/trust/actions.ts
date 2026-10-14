"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { reviewSignal, moderateReview, moderatePhoto } from "./api";

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

export async function moderateReviewAction(data: FormData) {
  const id = String(data.get("reviewId") ?? "");
  const status = String(data.get("moderationStatus") ?? "") as "PUBLISHED" | "HIDDEN" | "FLAGGED";
  const reason = String(data.get("reason") ?? "Policy compliance action");
  if (!id || !["PUBLISHED", "HIDDEN", "FLAGGED"].includes(status)) {
    redirect(`/trust?result=failed`);
  }
  const result = await moderateReview(id, status, reason);
  if (!result.ok) redirect(`/trust?result=failed`);
  revalidatePath("/trust");
  redirect(`/trust?result=review-moderated`);
}

export async function moderatePhotoAction(data: FormData) {
  const photoId = String(data.get("photoId") ?? "");
  const status = String(data.get("photoStatus") ?? "") as "APPROVED" | "REJECTED";
  const reason = String(data.get("reason") ?? "Content review moderation");
  if (!photoId || !["APPROVED", "REJECTED"].includes(status)) {
    redirect(`/trust?result=failed`);
  }
  const result = await moderatePhoto(photoId, status, reason);
  if (!result.ok) redirect(`/trust?result=failed`);
  revalidatePath("/trust");
  redirect(`/trust?result=photo-moderated`);
}
