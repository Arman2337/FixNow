"use server";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { cancelBooking, createCategory, deleteCategory, updateCategory } from "./api";

const categoryBody = (data: FormData) => ({ name: String(data.get("name") ?? "").trim(), slug: String(data.get("slug") ?? "").trim(), description: String(data.get("description") ?? "").trim(), displayOrder: Number(data.get("displayOrder")), isActive: data.get("isActive") === "on", isEmergency: data.get("isEmergency") === "on" });
export async function saveCategoryAction(data: FormData) { const id = String(data.get("id") ?? ""); const body = categoryBody(data); const result = id ? await updateCategory(id, body) : await createCategory(body); if (!result.ok) redirect("/services?result=failed"); revalidatePath("/services"); redirect("/services?result=saved"); }
export async function deleteCategoryAction(data: FormData) { const id = String(data.get("id") ?? ""); if (data.get("confirmed") !== "on") redirect("/services?result=confirmation-required"); const result = await deleteCategory(id); if (!result.ok) redirect("/services?result=failed"); revalidatePath("/services"); redirect("/services?result=deleted"); }
export async function cancelBookingAction(data: FormData) { const id = String(data.get("id") ?? ""); const reason = String(data.get("reason") ?? "").trim(); if (data.get("confirmed") !== "on" || reason.length < 3) redirect(`/bookings/${id}?result=confirmation-required`); const result = await cancelBooking(id, Number(data.get("expectedVersion")), reason); if (!result.ok) redirect(`/bookings/${id}?result=${result.status === 409 ? "stale" : "failed"}`); revalidatePath(`/bookings/${id}`); redirect(`/bookings/${id}?result=cancelled`); }
