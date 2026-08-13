import { cookies } from "next/headers";
import { readAdminSession } from "./api";
import type { AdminSession, AuthenticationResponse } from "./types";
import type { ApiResult } from "./api";

const accessCookie = "fixnow_admin_access";
const refreshCookie = "fixnow_admin_refresh";
const baseCookie = {
  httpOnly: true,
  sameSite: "strict" as const,
  secure: process.env.NODE_ENV === "production",
  path: "/",
  priority: "high" as const,
};

export async function saveSession(tokens: AuthenticationResponse): Promise<void> {
  const store = await cookies();
  store.set(accessCookie, tokens.accessToken, { ...baseCookie, maxAge: tokens.expiresIn });
  store.set(refreshCookie, tokens.refreshToken, { ...baseCookie, maxAge: 30 * 24 * 60 * 60 });
}

export async function clearSession(): Promise<void> {
  const store = await cookies();
  store.delete(accessCookie);
  store.delete(refreshCookie);
}

export async function refreshToken(): Promise<string | null> {
  return (await cookies()).get(refreshCookie)?.value ?? null;
}

export async function accessToken(): Promise<string | null> {
  return (await cookies()).get(accessCookie)?.value ?? null;
}

export async function getSession(): Promise<
  | { state: "authenticated"; session: AdminSession }
  | { state: "anonymous" | "expired" | "unauthorized" }
> {
  const store = await cookies();
  const accessToken = store.get(accessCookie)?.value;
  if (!accessToken) return classifySession(false, store.has(refreshCookie));
  const result = await readAdminSession(accessToken);
  return classifySession(true, store.has(refreshCookie), result);
}

export function classifySession(
  hasAccess: boolean,
  hasRefresh: boolean,
  result?: ApiResult<AdminSession>,
):
  | { state: "authenticated"; session: AdminSession }
  | { state: "anonymous" | "expired" | "unauthorized" } {
  if (!hasAccess) return { state: hasRefresh ? "expired" : "anonymous" };
  if (result?.ok) return { state: "authenticated", session: result.value };
  return { state: result?.status === 403 ? "unauthorized" : "expired" };
}
