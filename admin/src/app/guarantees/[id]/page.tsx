import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult, fetchManagementApi } from "@/features/management-api";
import { getClaim } from "@/features/guarantees/api";
import { StatusBadge } from "@/features/status-badge";
import { revalidatePath } from "next/cache";
import { listProviders } from "@/features/providers/api";

const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();

export default async function GuaranteeClaimDetailsPage(props: {
  params: Promise<{ id: string }>;
}) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");

  const params = await props.params;
  const claim = await requireManagementResult(await getClaim(params.id));
  const providersPage = await requireManagementResult(await listProviders());
  const providers = providersPage.items;

  async function updateStatusAction(formData: FormData) {
    "use server";
    const status = formData.get("status") as string;
    await fetchManagementApi(`/api/v1/guarantees/claims/${params.id}/status`, {
      method: "PATCH",
      body: JSON.stringify({ status }),
    });
    revalidatePath(`/guarantees/${params.id}`);
  }

  async function scheduleReServiceAction(formData: FormData) {
    "use server";
    const providerId = formData.get("providerId") as string;
    await fetchManagementApi(`/api/v1/guarantees/claims/${params.id}/re-service`, {
      method: "POST",
      body: JSON.stringify({ providerId }),
    });
    revalidatePath(`/guarantees/${params.id}`);
  }

  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Guarantee Claims">
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">
          
          <div className="flex items-center gap-space-sm text-body-sm text-outline">
            <Link href="/guarantees" className="hover:text-primary transition-colors">Guarantee Claims</Link>
            <span>/</span>
            <span className="font-data-mono uppercase">CLAIM-{shortId(claim.id)}</span>
          </div>

          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-space-md">
            <div>
              <h1 className="text-display-sm font-bold flex items-center gap-space-md">
                Claim {shortId(claim.id)}
                <StatusBadge status={claim.status} />
              </h1>
              <p className="text-body-md text-outline mt-1">Submitted on {new Date(claim.createdAt).toLocaleString()}</p>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-space-lg">
            <div className="lg:col-span-2 flex flex-col gap-space-lg">
              <section className="bg-surface border border-outline rounded-lg p-space-lg flex flex-col gap-space-md">
                <h2 className="text-heading-sm font-bold">Customer Description</h2>
                <p className="text-body-md whitespace-pre-wrap">{claim.description}</p>
                
                {claim.evidenceUrls && claim.evidenceUrls.length > 0 && (
                  <div className="mt-space-md">
                    <h3 className="text-body-md font-bold mb-space-sm">Evidence</h3>
                    <div className="flex gap-space-sm flex-wrap">
                      {claim.evidenceUrls.map((url, i) => (
                        <img key={i} src={url} alt="Evidence" className="w-32 h-32 object-cover rounded-md border border-outline" />
                      ))}
                    </div>
                  </div>
                )}
              </section>

              <section className="bg-surface border border-outline rounded-lg p-space-lg flex flex-col gap-space-md">
                <h2 className="text-heading-sm font-bold">Admin Actions</h2>
                <div className="flex items-center gap-space-sm">
                  <form action={updateStatusAction} className="flex items-center gap-space-sm">
                    <select name="status" defaultValue={claim.status} className="bg-surface-elevated border border-outline rounded-md px-3 py-2 text-body-md focus:outline-none focus:border-primary">
                      <option value="PENDING">Pending</option>
                      <option value="IN_REVIEW">In Review</option>
                      <option value="MORE_INFO">More Info Needed</option>
                      <option value="APPROVED">Approved</option>
                      <option value="REJECTED">Rejected</option>
                    </select>
                    <button type="submit" className="bg-primary text-on-primary px-4 py-2 rounded-md font-medium hover:bg-primary-hover transition-colors">
                      Update Status
                    </button>
                  </form>
                </div>

                {claim.status === "APPROVED" && !claim.reServiceBookingId && (
                  <div className="mt-space-lg pt-space-lg border-t border-outline flex flex-col gap-space-md">
                    <h3 className="text-heading-sm font-bold text-accent">Schedule Re-Service</h3>
                    <p className="text-body-sm text-outline">Assign a provider to perform the guarantee work. A zero-cost booking will be created automatically.</p>
                    <form action={scheduleReServiceAction} className="flex items-center gap-space-sm max-w-md">
                      <select name="providerId" className="flex-1 bg-surface-elevated border border-outline rounded-md px-3 py-2 text-body-md focus:outline-none focus:border-primary" required>
                        <option value="">Select a Provider...</option>
                        {providers.map((p) => (
                          <option key={p.id} value={p.id}>{p.firstName} {p.lastName}</option>
                        ))}
                      </select>
                      <button type="submit" className="bg-accent text-on-accent px-4 py-2 rounded-md font-medium hover:opacity-90 transition-opacity whitespace-nowrap">
                        Dispatch
                      </button>
                    </form>
                  </div>
                )}
                
                {claim.reServiceBookingId && (
                  <div className="mt-space-lg pt-space-lg border-t border-outline flex flex-col gap-space-sm">
                    <h3 className="text-body-md font-bold text-green-500">Re-Service Scheduled</h3>
                    <p className="text-body-md">
                      Booking ID: <Link href={`/bookings/${claim.reServiceBookingId}`} className="text-primary hover:underline font-data-mono">{shortId(claim.reServiceBookingId)}</Link>
                    </p>
                    <p className="text-body-md">
                      Assigned Provider: <Link href={`/providers/${claim.assignedProviderId}`} className="text-primary hover:underline font-data-mono">{claim.assignedProviderId ? shortId(claim.assignedProviderId) : "Unassigned"}</Link>
                    </p>
                  </div>
                )}
              </section>
            </div>

            <div className="flex flex-col gap-space-lg">
              <section className="bg-surface border border-outline rounded-lg p-space-lg flex flex-col gap-space-md">
                <h2 className="text-heading-sm font-bold">Details</h2>
                <div className="flex flex-col gap-space-sm text-body-sm">
                  <div className="flex justify-between py-2 border-b border-outline">
                    <span className="text-outline">Booking</span>
                    <Link href={`/bookings/${claim.bookingId}`} className="text-primary hover:underline font-data-mono">{shortId(claim.bookingId)}</Link>
                  </div>
                  <div className="flex justify-between py-2 border-b border-outline">
                    <span className="text-outline">Customer</span>
                    <Link href={`/users/${claim.customerId}`} className="text-primary hover:underline font-data-mono">{shortId(claim.customerId)}</Link>
                  </div>
                  <div className="flex justify-between py-2 border-b border-outline">
                    <span className="text-outline">Original Provider</span>
                    {claim.originalProviderId ? (
                      <Link href={`/providers/${claim.originalProviderId}`} className="text-primary hover:underline font-data-mono">{shortId(claim.originalProviderId)}</Link>
                    ) : (
                      <span className="text-outline">None</span>
                    )}
                  </div>
                </div>
              </section>
            </div>
          </div>

        </div>
      </div>
    </AdminShell>
  );
}
