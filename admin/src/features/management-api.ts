import { accessToken } from "@/auth/session";
import { env } from "@/config/env";

export type ManagementResult<T> = { ok: true; value: T } | { ok: false; status: number };

export async function managementRequest<T>(path: string, init: RequestInit = {}): Promise<ManagementResult<T>> {
  const token = await accessToken();
  if (!token) return { ok: false, status: 401 };
  try {
    const response = await fetch(`${env.apiBaseUrl}${path}`, {
      ...init,
      cache: "no-store",
      headers: { authorization: `Bearer ${token}`, "content-type": "application/json", ...init.headers },
    });
    if (!response.ok) return { ok: false, status: response.status };
    return { ok: true, value: await response.json() as T };
  } catch {
    return { ok: false, status: 503 };
  }
}

export async function requireManagementResult<T>(result: ManagementResult<T>): Promise<T> {
  if (result.ok) return result.value;
  const { redirect } = await import("next/navigation");
  if (result.status === 401) redirect("/login?reason=expired");
  if (result.status === 403) redirect("/unauthorized");
  throw new Error("Management data is temporarily unavailable.");
}
