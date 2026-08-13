import { accessToken } from "@/auth/session";
import { env } from "@/config/env";

export async function GET(_request: Request, { params }: { params: Promise<{ applicationId: string; documentId: string }> }) {
  const token = await accessToken();
  if (!token) return new Response(null, { status: 401 });
  const { applicationId, documentId } = await params;
  const response = await fetch(`${env.apiBaseUrl}/admin/provider-applications/${encodeURIComponent(applicationId)}/documents/${encodeURIComponent(documentId)}`, { headers: { authorization: `Bearer ${token}` }, cache: "no-store" });
  if (!response.ok) return new Response(null, { status: response.status });
  return new Response(response.body, { status: 200, headers: { "content-type": response.headers.get("content-type") ?? "application/octet-stream", "content-disposition": "attachment; filename=provider-document", "cache-control": "no-store, private", "x-content-type-options": "nosniff" } });
}
