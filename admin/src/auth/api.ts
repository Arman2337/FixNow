import { env } from "@/config/env";
import type { AdminSession, AuthenticationResponse } from "./types";
import { isStaffRole } from "./types";

export type ApiResult<T> =
  | { ok: true; value: T }
  | { ok: false; status: number };

async function request<T>(path: string, init: RequestInit): Promise<ApiResult<T>> {
  try {
    const response = await fetch(`${env.apiBaseUrl}${path}`, {
      ...init,
      cache: "no-store",
      headers: { "content-type": "application/json", ...init.headers },
    });
    if (!response.ok) return { ok: false, status: response.status };
    if (response.status === 204) return { ok: true, value: undefined as T };
    return { ok: true, value: await response.json() as T };
  } catch {
    return { ok: false, status: 503 };
  }
}

export async function loginAdmin(email: string, password: string) {
  const result = await request<AuthenticationResponse>("/auth/admin/login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
  if (!result.ok || !isStaffRole(result.value.role)) return result.ok ? { ok: false as const, status: 403 } : result;
  return result;
}

export async function readAdminSession(accessToken: string) {
  const result = await request<AdminSession>("/auth/admin/session", {
    method: "GET",
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (!result.ok) return result;
  const roles = result.value.roles.filter(isStaffRole);
  if (roles.length === 0) return { ok: false as const, status: 403 };
  return { ok: true as const, value: { ...result.value, roles } };
}

export const refreshAdmin = (refreshToken: string) =>
  request<AuthenticationResponse>("/auth/token/refresh", {
    method: "POST",
    body: JSON.stringify({ refreshToken }),
  });

export const logoutAdmin = (refreshToken: string) =>
  request<void>("/auth/logout", {
    method: "POST",
    body: JSON.stringify({ refreshToken }),
  });
