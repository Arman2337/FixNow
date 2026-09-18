import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { listClaims } from "@/features/guarantees/api";
import { StatusBadge } from "@/features/status-badge";

const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();

export default async function GuaranteesPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  
  const params = await searchParams;
  const claims = await requireManagementResult(
    await listClaims(params.status),
  );

  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Guarantee Claims">
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
          </div>

          <div className="flex flex-col gap-space-sm border border-outline rounded-lg overflow-hidden bg-surface">
            {claims.map((claim) => (
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
        </div>
      </div>
    </AdminShell>
  );
}
