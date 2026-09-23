import Link from "next/link";
import { redirect } from "next/navigation";
import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { listBookings } from "@/features/operations/api";
import { StatusBadge } from "@/features/status-badge";

const statuses = ["", "REQUESTED", "ASSIGNED", "EN_ROUTE", "IN_PROGRESS", "COMPLETED", "CANCELLED"];
const shortId = (id: string) => id.replaceAll("-", "").slice(0, 8).toUpperCase();
const categoryName = (val: string) =>
  val
    .replaceAll("_", " ")
    .split(" ")
    .filter(Boolean)
    .map((w) => `${w[0].toUpperCase()}${w.slice(1)}`)
    .join(" ");

export default async function BookingsPage({
  searchParams,
}: {
  searchParams: Promise<{ search?: string; status?: string; cursor?: string }>;
}) {
  const session = await getSession();
  if (session.state !== "authenticated") redirect("/login?reason=expired");
  const params = await searchParams;
  const page = await requireManagementResult(
    await listBookings(params.search, params.status, params.cursor),
  );

  const activeCount = page.items.filter(
    (b) => b.status === "REQUESTED" || b.status === "ASSIGNED" || b.status === "EN_ROUTE" || b.status === "IN_PROGRESS",
  ).length;
  const emergencyCount = page.items.filter(
    (b) => b.serviceCategoryId.toLowerCase().includes("emergency") || b.description.toLowerCase().includes("emergency"),
  ).length;
  const completedCount = page.items.filter((b) => b.status === "COMPLETED").length;

  return (
    <AdminShell environment={env.appEnvironment} roles={session.session.roles} current="Live Dispatches & Radar">
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">

          {/* Tactical Action Banner */}
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-space-md">
            <div>
              <div className="flex items-center gap-2">
                <span className="font-data-mono text-data-mono uppercase tracking-widest text-primary font-bold">WSS-LIVE Feed</span>
                <span className="w-1 h-1 rounded-full bg-outline"></span>
                <span className="font-label-sm text-label-sm text-on-surface-variant font-medium">Ping Latency: 42ms</span>
                <span className="px-2 py-0.5 rounded-full bg-primary-fixed text-on-primary-fixed font-data-mono text-[10px] font-bold uppercase tracking-wider">Geofence 50km</span>
              </div>
              <h1 className="font-headline-lg text-headline-lg text-on-surface tracking-tight mt-1">Booking Dispatches & SOS Radar</h1>
            </div>

            <div className="flex flex-wrap items-center gap-space-sm">
              <button className="flex items-center gap-2 px-3.5 py-2 rounded-lg bg-surface-container-highest text-on-surface hover:bg-surface-container-high transition-all shadow-sm">
                <span className="material-symbols-outlined text-[18px]">sync</span>
                <span className="font-label-md text-label-md font-semibold">Force Refresh Matrix</span>
              </button>
            </div>
          </div>

          {/* Filter Bar */}
          <div className="flex flex-wrap items-center gap-2">
            <Link
              href="/bookings"
              className={`flex items-center gap-2 rounded-lg px-4 py-2 font-label-md text-label-md font-bold transition-all shadow-sm ${
                !params.status
                  ? "bg-primary text-on-primary"
                  : "bg-surface-container-low text-on-surface-variant hover:bg-surface-container"
              }`}
            >
              <span>All Dispatches</span>
              <span className={`rounded font-data-mono text-[10px] px-1.5 py-0.5 ${!params.status ? 'bg-on-primary/20 text-on-primary' : 'bg-surface-container-highest text-on-surface'}`}>
                {page.items.length}
              </span>
            </Link>
            
            <Link
              href="/bookings?status=EN_ROUTE"
              className={`flex items-center gap-2 rounded-lg px-4 py-2 font-label-md text-label-md font-bold transition-all shadow-sm ${
                params.status === "EN_ROUTE"
                  ? "bg-primary text-on-primary"
                  : "bg-surface-container-low text-on-surface-variant hover:bg-surface-container"
              }`}
            >
              <span className={`w-2 h-2 rounded-full ${params.status === "EN_ROUTE" ? "bg-on-primary" : "bg-primary"}`}></span>
              <span>En Route (Active)</span>
              <span className={`rounded font-data-mono text-[10px] px-1.5 py-0.5 ${params.status === "EN_ROUTE" ? 'bg-on-primary/20 text-on-primary' : 'bg-surface-container-highest text-on-surface'}`}>
                {page.items.filter((b) => b.status === "EN_ROUTE").length}
              </span>
            </Link>

            <Link
              href="/bookings?status=REQUESTED"
              className={`flex items-center gap-2 rounded-lg px-4 py-2 font-label-md text-label-md font-bold transition-all shadow-sm ${
                params.status === "REQUESTED"
                  ? "bg-primary text-on-primary"
                  : "bg-surface-container-low text-on-surface-variant hover:bg-surface-container"
              }`}
            >
              <span>Matching Queue</span>
              <span className={`rounded font-data-mono text-[10px] px-1.5 py-0.5 ${params.status === "REQUESTED" ? 'bg-on-primary/20 text-on-primary' : 'bg-surface-container-highest text-on-surface'}`}>
                {page.items.filter((b) => b.status === "REQUESTED").length}
              </span>
            </Link>

            <Link
              href="/bookings?status=IN_PROGRESS"
              className={`flex items-center gap-2 rounded-lg px-4 py-2 font-label-md text-label-md font-bold transition-all shadow-sm ${
                params.status === "IN_PROGRESS"
                  ? "bg-primary text-on-primary"
                  : "bg-surface-container-low text-on-surface-variant hover:bg-surface-container"
              }`}
            >
              <span>In Service</span>
              <span className={`rounded font-data-mono text-[10px] px-1.5 py-0.5 ${params.status === "IN_PROGRESS" ? 'bg-on-primary/20 text-on-primary' : 'bg-surface-container-highest text-on-surface'}`}>
                {page.items.filter((b) => b.status === "IN_PROGRESS").length}
              </span>
            </Link>
          </div>

          <form role="search" className="flex items-center gap-2 bg-surface-container-low rounded-xl p-2 border border-outline-variant/30">
            <div className="flex-1 flex items-center bg-surface rounded-lg px-3 border border-outline-variant/50 focus-within:border-primary focus-within:ring-1 focus-within:ring-primary transition-all">
              <span className="material-symbols-outlined text-on-surface-variant text-[18px]">search</span>
              <input 
                id="booking-search"
                name="search"
                defaultValue={params.search}
                placeholder="Search booking ID, customer, provider..." 
                className="w-full bg-transparent border-none py-2 px-2 font-body-sm text-body-sm text-on-surface placeholder:text-on-surface-variant focus:outline-none" 
              />
            </div>
            <select
              id="booking-status"
              name="status"
              defaultValue={params.status ?? ""}
              className="bg-surface rounded-lg border border-outline-variant/50 py-2 px-3 font-body-sm text-body-sm text-on-surface focus:outline-none focus:border-primary transition-all"
            >
              {statuses.map((status) => (
                <option key={status} value={status}>
                  {status ? status.replaceAll("_", " ") : "All statuses"}
                </option>
              ))}
            </select>
            <button type="submit" className="px-4 py-2 rounded-lg bg-primary text-on-primary font-label-md text-label-md font-semibold hover:bg-primary-container transition-colors shadow-sm">
              Filter
            </button>
            <Link href="/bookings" className="px-4 py-2 rounded-lg bg-surface-container text-on-surface font-label-md text-label-md font-semibold hover:bg-surface-container-high transition-colors text-center border border-outline-variant/30">
              Clear
            </Link>
          </form>

          {/* Layout Grid */}
          <div className="grid grid-cols-1 xl:grid-cols-12 gap-space-lg">
            
            {/* Main Table Content (8 cols on XL) */}
            <div className="xl:col-span-8 flex flex-col gap-space-md">
              <div className="bg-surface-container-lowest rounded-2xl shadow-sm border border-outline-variant/30 overflow-hidden flex flex-col">
                <div className="p-space-md bg-surface-container-low/40 flex items-center justify-between border-b border-outline-variant/30">
                  <div className="flex items-center gap-2">
                    <span className="material-symbols-outlined text-[20px] text-primary">dynamic_feed</span>
                    <h2 className="font-headline-sm text-headline-sm font-bold text-on-surface tracking-tight">Real-Time Dispatch Queue</h2>
                  </div>
                  <div className="flex items-center gap-1.5 font-label-sm text-label-sm text-on-surface-variant font-semibold">
                    <span className="w-1.5 h-1.5 rounded-full bg-error animate-ping"></span> Live Refresh Active
                  </div>
                </div>

                <div className="overflow-x-auto">
                  <table className="w-full text-left border-collapse min-w-[800px]">
                    <thead>
                      <tr className="bg-surface-container-lowest border-b border-outline-variant/40 font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant">
                        <th className="py-3 px-space-md font-semibold">Job ID</th>
                        <th className="py-3 px-space-md font-semibold">Category / Priority</th>
                        <th className="py-3 px-space-md font-semibold">Customer / Location</th>
                        <th className="py-3 px-space-md font-semibold">Assigned Tech</th>
                        <th className="py-3 px-space-md font-semibold">Status</th>
                        <th className="py-3 px-space-md font-semibold text-center">Escrow</th>
                        <th className="py-3 px-space-md font-semibold text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-outline-variant/20 font-body-sm text-body-sm text-on-surface">
                      {page.items.length ? (
                        page.items.map((booking) => {
                          const isUrgent = booking.serviceCategoryId.toLowerCase().includes("emergency") || booking.description.toLowerCase().includes("emergency");
                          const isEnRoute = booking.status === "EN_ROUTE";
                          return (
                            <tr key={booking.id} className={`transition-colors ${isUrgent ? 'bg-error-container/10 hover:bg-error-container/20' : 'hover:bg-surface-container-low/60'}`}>
                              <td className={`py-3.5 px-space-md font-data-mono text-data-mono font-bold ${isUrgent ? 'text-error' : 'text-on-surface'}`}>
                                #JOB-{shortId(booking.id)}
                              </td>
                              <td className="py-3.5 px-space-md">
                                <span className={`px-2 py-0.5 rounded-full font-label-sm text-label-sm font-semibold inline-block ${isUrgent ? 'bg-error text-on-error animate-pulse' : 'bg-surface-container-highest text-on-surface-variant'}`}>
                                  {isUrgent ? 'PRIORITY SOS' : categoryName(booking.serviceCategoryId)}
                                </span>
                                <div className="font-bold text-on-surface mt-1 truncate max-w-xs">{booking.description}</div>
                              </td>
                              <td className="py-3.5 px-space-md">
                                <div className="font-bold text-on-surface">#{shortId(booking.customerId)}</div>
                                <div className="font-body-sm text-body-sm text-on-surface-variant flex items-center gap-1 truncate max-w-[150px]">
                                  <span className="material-symbols-outlined text-[14px]">location_on</span> Area Block
                                </div>
                              </td>
                              <td className="py-3.5 px-space-md">
                                <div className="flex items-center gap-2">
                                  {booking.providerId ? (
                                    <>
                                      <span className={`w-2 h-2 rounded-full ${isEnRoute ? 'bg-primary animate-pulse' : 'bg-secondary'}`}></span>
                                      <div>
                                        <div className="font-bold text-on-surface">Tech #{shortId(booking.providerId)}</div>
                                        <div className="font-label-sm text-label-sm text-on-surface-variant">Matched</div>
                                      </div>
                                    </>
                                  ) : (
                                    <>
                                      <span className="w-2 h-2 rounded-full bg-outline animate-pulse"></span>
                                      <div className="font-bold text-tertiary">Queued...</div>
                                    </>
                                  )}
                                </div>
                              </td>
                              <td className="py-3.5 px-space-md">
                                <span className={`px-2.5 py-1 rounded-full font-label-sm text-label-sm font-semibold flex items-center gap-1.5 w-fit ${
                                  isEnRoute ? 'bg-primary-container text-on-primary-container' : 'bg-surface-container-high text-on-surface-variant'
                                }`}>
                                  <StatusBadge status={booking.status} />
                                </span>
                              </td>
                              <td className="py-3.5 px-space-md text-center text-on-surface-variant/60 font-semibold">
                                {/* Mock Escrow Data */}
                                {booking.status === 'COMPLETED' ? 'Settled' : '?"'}
                              </td>
                              <td className="py-3.5 px-space-md text-right">
                                <div className="flex items-center justify-end gap-1.5">
                                  <Link href={`/bookings/${booking.id}`} className="p-1.5 rounded-lg bg-surface-container text-on-surface hover:bg-surface-container-high transition-colors" title="Open Dispatch">
                                    <span className="material-symbols-outlined text-[16px]">open_in_new</span>
                                  </Link>
                                </div>
                              </td>
                            </tr>
                          );
                        })
                      ) : (
                        <tr>
                          <td colSpan={7} className="py-8 text-center font-label-md text-label-md text-on-surface-variant">
                            No active dispatches found for these filters.
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>

                {page.nextCursor ? (
                  <div className="p-space-md border-t border-outline-variant/30 flex justify-center">
                    <Link
                      className="px-4 py-2 rounded-lg border border-outline-variant/50 bg-surface text-on-surface font-label-md text-label-md font-semibold hover:bg-surface-container-low transition-colors shadow-sm"
                      href={{
                        pathname: "/bookings",
                        query: { search: params.search, status: params.status, cursor: page.nextCursor },
                      }}
                    >
                      Load Next Segment →
                    </Link>
                  </div>
                ) : null}
              </div>
            </div>

            {/* Telemetry Drawer & Incident Diagnostic Panel (4 Columns) */}
            <div className="xl:col-span-4 flex flex-col gap-space-md">
              <div className="bg-surface-container-lowest rounded-2xl p-space-md shadow-md flex flex-col gap-space-md border border-outline-variant/30">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="material-symbols-outlined text-primary text-[22px]">sensors</span>
                    <span className="font-headline-md text-headline-md font-bold text-on-surface">Telemetry Deck</span>
                  </div>
                  <span className="px-2 py-0.5 rounded font-data-mono text-label-sm bg-primary-container text-on-primary font-bold">SOCKET LIVE</span>
                </div>
                
                <div className="grid grid-cols-2 gap-space-sm">
                  <div className="p-space-sm rounded-xl bg-surface-container-low flex flex-col">
                    <div className="flex items-center justify-between text-on-surface-variant font-label-sm text-label-sm">
                      <span>Customer Device</span>
                      <span className="material-symbols-outlined text-[16px] text-primary">battery_5_bar</span>
                    </div>
                    <div className="font-headline-md text-headline-md font-bold text-on-surface mt-1">78%</div>
                    <div className="font-label-sm text-label-sm text-on-surface-variant">4G VoLTE • Strong</div>
                  </div>
                  <div className="p-space-sm rounded-xl bg-surface-container-low flex flex-col">
                    <div className="flex items-center justify-between text-on-surface-variant font-label-sm text-label-sm">
                      <span>Tech Phone Latency</span>
                      <span className="material-symbols-outlined text-[16px] text-primary">wifi</span>
                    </div>
                    <div className="font-headline-md text-headline-md font-bold text-on-surface mt-1">42ms</div>
                    <div className="font-label-sm text-label-sm text-on-surface-variant">5G Sub6 • GPS Locked</div>
                  </div>
                  <div className="p-space-sm rounded-xl bg-surface-container-low flex flex-col">
                    <div className="flex items-center justify-between text-on-surface-variant font-label-sm text-label-sm">
                      <span>Masked VoIP Bridge</span>
                      <span className="material-symbols-outlined text-[16px] text-primary">encrypted</span>
                    </div>
                    <div className="font-headline-md text-headline-md font-bold text-primary mt-1">STANDBY</div>
                    <div className="font-label-sm text-label-sm text-on-surface-variant">Exotel #8040-0012</div>
                  </div>
                  <div className="p-space-sm rounded-xl bg-surface-container-low flex flex-col">
                    <div className="flex items-center justify-between text-on-surface-variant font-label-sm text-label-sm">
                      <span>Start OTP Guard</span>
                      <span className="material-symbols-outlined text-[16px] text-tertiary">pin</span>
                    </div>
                    <div className="font-headline-md text-headline-md font-bold text-on-surface mt-1">7492</div>
                    <div className="font-label-sm text-label-sm text-tertiary font-bold">Awaiting Input</div>
                  </div>
                </div>

                {emergencyCount > 0 && (
                  <div className="p-space-sm rounded-xl bg-error-container/20 flex flex-col gap-2 border border-error/20">
                    <div className="flex items-center justify-between">
                      <span className="font-label-sm text-label-sm uppercase font-semibold text-on-error">Hazard Assessment</span>
                      <span className="font-label-sm text-label-sm text-error font-bold flex items-center gap-1">
                        <span className="material-symbols-outlined text-[14px]">local_fire_department</span> Active Smoke Reported
                      </span>
                    </div>
                    <p className="font-body-sm text-body-sm text-on-surface">
                      "Main MCB tripped with loud spark and sulfur smell. Refrigerator line hot to touch. Senior citizen in premises."
                    </p>
                    <div className="flex flex-col gap-2 mt-2">
                      <button className="w-full py-2.5 rounded-xl bg-inverse-surface text-inverse-on-surface font-label-md text-label-md font-semibold hover:bg-black transition-colors flex items-center justify-center gap-2 shadow-sm">
                        <span className="material-symbols-outlined text-[18px]">podcasts</span>
                        <span>Force Trigger Wave 2 Broadcast (15km)</span>
                      </button>
                      <button className="w-full py-2 rounded-xl bg-error text-on-error font-label-md text-label-md font-semibold hover:opacity-90 transition-colors flex items-center justify-center gap-2 shadow-md">
                        <span className="material-symbols-outlined text-[18px]">call</span>
                        <span>Patch to Bangalore Fire Services (101)</span>
                      </button>
                    </div>
                  </div>
                )}
                
                {/* Wave 1 Ping Candidates List */}
                <div className="flex flex-col gap-space-sm border-t border-outline-variant/30 pt-space-md">
                  <div className="flex items-center justify-between">
                    <span className="font-label-md text-label-md font-bold text-on-surface">Wave 1 Responders (Radius 3km)</span>
                    <span className="font-data-mono text-data-mono text-primary font-bold">3 NOTIFIED</span>
                  </div>
                  <div className="flex flex-col gap-2">
                    <div className="p-2 rounded-lg border border-outline-variant/40 flex items-center justify-between bg-surface-container-lowest">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-full bg-surface-container flex items-center justify-center text-on-surface-variant">
                          <span className="material-symbols-outlined text-[16px]">person</span>
                        </div>
                        <div>
                          <div className="font-label-sm text-label-sm font-bold text-on-surface">Suresh Kumar (4.9⭐)</div>
                          <div className="font-body-sm text-[10px] text-on-surface-variant">Master Electrician • 1.2km away</div>
                        </div>
                      </div>
                      <span className="px-2 py-0.5 rounded bg-primary-container text-on-primary font-label-sm text-[10px] font-bold">Pinging</span>
                    </div>
                    <div className="p-2 rounded-lg border border-outline-variant/40 flex items-center justify-between bg-surface-container-lowest">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-full bg-surface-container flex items-center justify-center text-on-surface-variant">
                          <span className="material-symbols-outlined text-[16px]">person</span>
                        </div>
                        <div>
                          <div className="font-label-sm text-label-sm font-bold text-on-surface">Nitesh V (4.8⭐)</div>
                          <div className="font-body-sm text-[10px] text-on-surface-variant">L2 Electrician • 2.1km away</div>
                        </div>
                      </div>
                      <span className="px-2 py-0.5 rounded bg-surface-container text-on-surface-variant font-label-sm text-[10px] font-bold">No Response</span>
                    </div>
                  </div>
                </div>

              </div>
            </div>
            
          </div>
        </div>
      </div>
    </AdminShell>
  );
}
