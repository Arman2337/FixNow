import { pageNumber as parsePageNumber } from "@/lib/format";
import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { listClaims } from "@/features/guarantees/api";
import { StatusBadge } from "@/features/status-badge";
import { hasPermission } from "@/auth/roles";

import { shortId } from "@/lib/format";

export default async function GuaranteesPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; page?: string; search?: string }>;
}) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");

  if (!hasPermission(session.session.roles, "adminGuaranteesRead")) {
    redirect("/unauthorized");
  }
  
  const params = await searchParams;
  const pageNumber = parsePageNumber(params.page);
  const pageSize = 10;
  const claims = await requireManagementResult(
    await listClaims(params.status, pageSize + 1, (pageNumber - 1) * pageSize, params.search),
  );
  const hasNextPage = claims.length > pageSize;
  const pagedClaims = claims.slice(0, pageSize);

  return (
    <AdminShell
      environment={env.appEnvironment}
      roles={session.session.roles}
      email={session.session.email}
      displayName={session.session.displayName}
      current="Guarantee Claims"
    >
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-space-md">
            <div>
              <div className="flex items-center gap-2">
                <span className="font-data-mono text-data-mono uppercase tracking-widest text-primary font-bold">Guarantee Claims</span>
              </div>
              <h1 className="text-display-sm font-bold mt-2">Manage Claims</h1>
              <p className="text-body-md text-outline">Review and process 30-day guarantee claims.</p>
            </div>
            <div className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest px-4 py-2.5 text-sm text-on-surface">
              <span className="block text-xs uppercase tracking-wider text-on-surface-variant">Claims Count</span>
              <strong>{pagedClaims.length} claim{pagedClaims.length === 1 ? "" : "s"} on this page</strong>
            </div>
          </div>

          <div className="flex flex-col gap-space-sm border border-outline rounded-lg overflow-hidden bg-surface">
            {pagedClaims.map((claim) => (
              <Link
                key={claim.id}
                href={`/guarantees/${claim.id}`}
                className="flex items-center gap-space-md p-space-md hover:bg-surface-elevated transition-colors border-b border-outline last:border-b-0"
              >
                <div className="flex flex-col gap-1 w-[120px]">
                  <span className="font-data-mono text-data-mono text-outline uppercase">
                    CLAIM-{shortId(claim.id)}
                  </span>
                  <span className="text-body-sm text-outline">
                    {new Date(claim.createdAt).toLocaleDateString()}
                  </span>
                </div>
                
                <div className="flex-1 min-w-0">
                  <p className="text-body-md font-medium truncate">
                    {claim.description}
                  </p>
                  <p className="text-body-sm text-outline mt-1 truncate">
                    Booking: {shortId(claim.bookingId)}
                  </p>
                </div>
                
                <div className="w-[140px] flex justify-end">
                  <StatusBadge status={claim.status} />
                </div>
              </Link>
            ))}
            {claims.length === 0 && (
              <div className="p-space-xl text-center text-outline">
                No guarantee claims found.
              </div>
            )}
          </div>

          {(hasNextPage || pageNumber > 1) && (
            <div className="flex items-center justify-between border-t border-outline-variant/20 pt-4">
              <div>
                {pageNumber > 1 ? (
                  <Link
                    href={{ pathname: "/guarantees", query: { status: params.status, search: params.search, page: String(pageNumber - 1) } }}
                    className="px-4 py-2 rounded-xl border border-outline-variant/40 bg-surface-container-low text-on-surface font-label-md text-sm font-semibold hover:bg-surface-container transition-colors inline-flex items-center gap-1"
                  >
                    <span className="material-symbols-outlined text-[16px]">arrow_back</span>
                    <span>Previous page</span>
                  </Link>
                ) : <div />}
              </div>
              <span className="font-body-sm text-sm text-on-surface-variant">Page {pageNumber}</span>
              <div>
                {hasNextPage ? (
                  <Link
                    href={{ pathname: "/guarantees", query: { status: params.status, search: params.search, page: String(pageNumber + 1) } }}
                    className="px-4 py-2 rounded-xl bg-primary text-on-primary font-label-md text-sm font-semibold hover:bg-primary/90 transition-colors inline-flex items-center gap-1"
                  >
                    <span>Next page</span>
                    <span className="material-symbols-outlined text-[16px]">arrow_forward</span>
                  </Link>
                ) : <div />}
              </div>
            </div>
          )}

        </div>
      </div>
    </AdminShell>
  );
}
