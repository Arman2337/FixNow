"use server";

import { redirect } from "next/navigation";
import { loginAdmin, logoutAdmin, refreshAdmin } from "./api";
import { clearSession, refreshToken, saveSession } from "./session";
import { isStaffRole } from "./types";
import { validateLoginInput } from "./validation";

export type LoginState = Readonly<{
  errors?: { email?: string; password?: string };
  message?: string;
}>;

export async function loginAction(_state: LoginState, formData: FormData): Promise<LoginState> {
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const password = String(formData.get("password") ?? "");
  const validation = validateLoginInput(email, password);
  if (validation.errors) return validation;

  const result = await loginAdmin(email, password);
  if (!result.ok) {
    if (result.status === 429) return { message: "Too many attempts. Wait a minute, then try again." };
    if (result.status >= 500) return { message: "Sign-in is temporarily unavailable. Try again shortly." };
    return { message: "Email or password not recognized, or staff access is unavailable." };
  }
  await saveSession(result.value);
  redirect("/");
}

export async function refreshAction(): Promise<void> {
  const token = await refreshToken();
  if (!token) redirect("/login?reason=expired");
  const result = await refreshAdmin(token);
  if (!result.ok || !isStaffRole(result.value.role)) {
    await clearSession();
    redirect("/login?reason=expired");
  }
  await saveSession(result.value);
  redirect("/");
}

export async function logoutAction(): Promise<void> {
  const token = await refreshToken();
  if (token) await logoutAdmin(token);
  await clearSession();
  redirect("/login?reason=signed-out");
}
