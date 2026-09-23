import { getSession } from "@/auth/session";
import { AdminShell } from "@/components/admin-shell";
import { env } from "@/config/env";
import { requireManagementResult } from "@/features/management-api";
import { getAnalytics } from "@/features/operations/api";
import Link from "next/link";
import { redirect } from "next/navigation";

export default async function Home() {
  const result = await getSession();
  if (result.state !== "authenticated") {
    if (result.state === "anonymous") redirect("/login");
    if (result.state === "expired") redirect("/login?reason=expired");
    redirect("/unauthorized");
  }
  const canViewAnalytics = result.session.roles.some((role) => role === "operations_administrator" || role === "auditor");
  const analytics = canViewAnalytics ? await requireManagementResult(await getAnalytics()) : null;
  const canManageBookings = result.session.roles.some((role) => ["support_agent", "trust_safety_reviewer", "operations_administrator", "auditor"].includes(role));

  if (!analytics) {
    return (
      <AdminShell environment={env.appEnvironment} roles={result.session.roles}>
        <section aria-labelledby="access-heading" className="mt-8 rounded-2xl border border-outline-variant/30 bg-surface-container-lowest p-6 shadow-sm">
          <p className="m-0 text-xs font-bold uppercase tracking-wider text-primary">Your Staff Access</p>
          <h2 id="access-heading" className="mt-2 mb-0 text-xl font-bold text-on-surface">Choose an operation from the navigation</h2>
          <p className="mt-2 mb-0 max-w-2xl text-sm text-on-surface-variant">Your role does not include platform-wide analytics. Use the navigation modules to manage the operations assigned to you.</p>
        </section>
      </AdminShell>
    );
  }

  return (
    <AdminShell environment={env.appEnvironment} roles={result.session.roles} current="Overview Dashboard">
      <div className="flex flex-col w-full">
        <div className="p-space-lg lg:p-margin-desktop flex flex-col gap-space-lg">
          
          {/* Top Action & Context Banner */}
          <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-space-md">
            <div>
              <div className="flex items-center gap-2">
                <span className="font-data-mono text-data-mono uppercase tracking-widest text-primary font-bold">{env.appEnvironment} Operational Grid</span>
                <span className="w-1 h-1 rounded-full bg-outline"></span>
                <span className="font-label-sm text-label-sm text-on-surface-variant font-medium">Synced 3s ago</span>
                <span className="px-2 py-0.5 rounded-full bg-primary-fixed text-on-primary-fixed font-data-mono text-[10px] font-bold uppercase tracking-wider">ADR-0016 Active</span>
              </div>
              <h1 className="font-headline-lg text-headline-lg text-on-surface tracking-tight mt-1">Live Operations Radar</h1>
            </div>
            
            {/* Quick Operational Controls */}
            <div className="flex flex-wrap items-center gap-space-sm">
              <button className="flex items-center gap-2 px-3.5 py-2.5 rounded-lg bg-surface-container-highest text-on-surface hover:bg-surface-container-high transition-all shadow-sm">
                <span className="material-symbols-outlined text-[18px] text-tertiary">campaign</span>
                <span className="font-label-md text-label-md">Global Broadcast</span>
              </button>
              <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-surface-container-low shadow-sm">
                <span className="font-label-sm text-label-sm font-semibold text-on-surface-variant">Emergency Hotline</span>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input defaultChecked className="sr-only peer" type="checkbox" />
                  <div className="w-9 h-5 bg-secondary-fixed-dim peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-primary"></div>
                </label>
              </div>
              <button className="flex items-center gap-2 px-3.5 py-2.5 rounded-lg bg-surface-container-highest text-on-surface hover:bg-surface-container-high transition-all shadow-sm">
                <span className="material-symbols-outlined text-[18px]">receipt_long</span>
                <span className="font-label-md text-label-md">GST Ledger Export</span>
              </button>
              <button className="flex items-center gap-2 px-4 py-2.5 rounded-lg bg-primary text-on-primary hover:bg-primary-container transition-all shadow-md">
                <span className="material-symbols-outlined text-[18px]">add_task</span>
                <span className="font-label-md text-label-md">Manual Job Override</span>
              </button>
            </div>
          </div>

          {/* 1. Top KPI Metric Cards (Bento Metric Strip) */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-space-md">
            <div className="bg-surface-container-lowest p-space-md rounded-xl shadow-sm relative overflow-hidden flex flex-col justify-between">
              <div className="flex items-center justify-between">
                <span className="font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant font-bold">Active Dispatches</span>
                <span className="flex h-2.5 w-2.5 relative">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-error opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-error"></span>
                </span>
              </div>
              <div className="mt-2">
                <div className="flex items-baseline gap-2">
                  <span className="font-headline-xl text-headline-xl text-on-surface tracking-tight">{analytics.bookings.pending}</span>
                  <span className="font-label-md text-label-md text-on-surface-variant font-medium">Live</span>
                </div>
                <div className="mt-2.5 flex items-center gap-1.5 px-2 py-1 rounded bg-error-container text-on-error-container font-data-mono text-data-mono">
                  <span className="material-symbols-outlined text-[14px] text-error animate-pulse">crisis_alert</span>
                  <span className="font-bold">4 Priority SOS Waves</span>
                </div>
              </div>
              <div className="mt-3 flex items-center justify-between text-on-surface-variant font-body-sm text-body-sm">
                <span>Wave #1 SLA critical</span>
                <span className="font-data-mono text-error font-bold">&lt; 3m rem</span>
              </div>
            </div>

            <div className="bg-surface-container-lowest p-space-md rounded-xl shadow-sm flex flex-col justify-between">
              <div className="flex items-center justify-between">
                <span className="font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant font-bold">Online Field Techs</span>
                <span className="material-symbols-outlined text-primary text-[20px]">engineering</span>
              </div>
              <div className="mt-2">
                <div className="flex items-baseline gap-2">
                  <span className="font-headline-xl text-headline-xl text-on-surface tracking-tight">{analytics.providers.active}</span>
                  <span className="font-label-sm text-label-sm text-primary font-bold">/ {analytics.providers.total} Available</span>
                </div>
                <div className="font-body-sm text-body-sm text-on-surface-variant mt-1">6 Active Bangalore Zones</div>
              </div>
              <div className="mt-3 flex gap-1">
                <div className="h-1.5 flex-1 rounded-full bg-primary" title="HSR: 11 Techs"></div>
                <div className="h-1.5 flex-1 rounded-full bg-primary" title="Koramangala: 9 Techs"></div>
                <div className="h-1.5 flex-1 rounded-full bg-primary" title="Indiranagar: 8 Techs"></div>
                <div className="h-1.5 flex-1 rounded-full bg-primary" title="Bellandur: 6 Techs"></div>
                <div className="h-1.5 flex-1 rounded-full bg-primary-fixed-dim" title="Whitefield: 5 Techs"></div>
                <div className="h-1.5 flex-1 rounded-full bg-secondary-fixed-dim" title="Jayanagar: 3 Techs"></div>
              </div>
            </div>

            <div className="bg-surface-container-lowest p-space-md rounded-xl shadow-sm flex flex-col justify-between">
              <div className="flex items-center justify-between">
                <span className="font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant font-bold">GBV (Today)</span>
                <span className="px-2 py-0.5 rounded-full bg-primary-fixed text-on-primary-fixed font-data-mono text-data-mono font-bold">+14.2%</span>
              </div>
              <div className="mt-2">
                <div className="font-headline-lg text-headline-lg text-on-surface tracking-tight">₹11,84,250</div>
                <div className="font-body-sm text-body-sm text-on-surface-variant mt-0.5">₹11.61L yesterday same hour</div>
              </div>
              <div className="mt-3 flex items-center justify-between font-body-sm text-body-sm text-on-surface-variant">
                <span>Avg ticket value</span>
                <span className="font-data-mono font-semibold text-on-surface">₹11,480</span>
              </div>
            </div>

            <div className="bg-surface-container-lowest p-space-md rounded-xl shadow-sm flex flex-col justify-between">
              <div className="flex items-center justify-between">
                <span className="font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant font-bold">Platform SLA</span>
                <span className="material-symbols-outlined text-primary text-[20px]">verified</span>
              </div>
              <div className="mt-2">
                <div className="flex items-baseline gap-2">
                  <span className="font-headline-xl text-headline-xl text-on-surface tracking-tight">99.4%</span>
                  <span className="font-data-mono text-data-mono text-primary font-bold">Target 98%</span>
                </div>
                <div className="flex items-center gap-3 mt-1 font-body-sm text-body-sm text-on-surface-variant">
                  <span>Accept: <strong className="font-data-mono text-on-surface">{analytics.trust.averageAcceptMinutes}m</strong></span>
                  <span>Arrival: <strong className="font-data-mono text-on-surface">96.8%</strong></span>
                </div>
              </div>
              <div className="mt-3 w-full bg-surface-container rounded-full h-1.5 overflow-hidden">
                <div className="bg-primary h-full rounded-full" style={{ width: "99.4%" }}></div>
              </div>
            </div>

            <div className="bg-surface-container-lowest p-space-md rounded-xl shadow-sm flex flex-col justify-between">
              <div className="flex items-center justify-between">
                <span className="font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant font-bold">Escrow Locked</span>
                <span className="material-symbols-outlined text-tertiary text-[20px]">shield_lock</span>
              </div>
              <div className="mt-2">
                <div className="font-headline-lg text-headline-lg text-on-surface tracking-tight">₹142,600</div>
                <div className="font-body-sm text-body-sm text-on-surface-variant mt-0.5">Safety & Dispute Vault</div>
              </div>
              <div className="mt-3 flex items-center justify-between font-label-sm text-label-sm">
                <span className="text-on-surface-variant">Policy ADR-0016</span>
                <span className="font-data-mono text-primary font-bold">100% Guaranteed</span>
              </div>
            </div>
          </div>
          
          {/* 2. Central Command Grid */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-space-lg">
            {/* LEFT/CENTER (8/12) */}
            <div className="lg:col-span-8 flex flex-col gap-space-md">
              <div className="bg-surface-container-lowest rounded-xl shadow-sm overflow-hidden flex flex-col">
                <div className="p-space-md flex flex-col sm:flex-row sm:items-center justify-between gap-space-sm bg-surface-container-low/40">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center text-on-primary">
                      <span className="material-symbols-outlined text-[18px]">stream</span>
                    </div>
                    <div>
                      <h2 className="font-headline-md text-headline-md text-on-surface tracking-tight">Active Dispatches & Escalations</h2>
                      <span className="font-body-sm text-body-sm text-on-surface-variant">Dynamic telemetry feed synchronized with GPS mesh</span>
                    </div>
                  </div>
                  <div className="flex items-center gap-1 bg-surface-container-lowest p-1 rounded-lg shadow-sm">
                    <button className="px-3 py-1.5 rounded-lg bg-primary text-on-primary font-label-sm text-label-sm font-semibold">All ({analytics.bookings.pending})</button>
                    <button className="px-3 py-1.5 rounded-lg text-on-surface-variant hover:text-on-surface font-label-sm text-label-sm font-semibold flex items-center gap-1">
                      <span className="w-1.5 h-1.5 rounded-full bg-error"></span>
                      SOS Waves (4)
                    </button>
                    <button className="px-3 py-1.5 rounded-lg text-on-surface-variant hover:text-on-surface font-label-sm text-label-sm font-semibold">In Progress (8)</button>
                    <button className="px-3 py-1.5 rounded-lg text-on-surface-variant hover:text-on-surface font-label-sm text-label-sm font-semibold">En Route (6)</button>
                  </div>
                </div>
                
                <div className="overflow-x-auto">
                  <table className="w-full text-left border-collapse">
                    <thead>
                      <tr className="bg-surface-container-low font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant">
                        <th className="py-3 px-4 font-semibold">Job ID & Timeline</th>
                        <th className="py-3 px-4 font-semibold">Priority & Service</th>
                        <th className="py-3 px-4 font-semibold">Customer</th>
                        <th className="py-3 px-4 font-semibold">Assigned Specialist</th>
                        <th className="py-3 px-4 font-semibold">ETA / Geo</th>
                        <th className="py-3 px-4 font-semibold">Escrow</th>
                        <th className="py-3 px-4 font-semibold">Status / SLA</th>
                        <th className="py-3 px-4 text-right font-semibold">Quick Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y-0 text-body-sm font-body-sm text-on-surface">
                      
                      <tr className="hover:bg-error-container/20 transition-colors bg-error-container/10">
                        <td className="py-3.5 px-4 align-middle">
                          <div className="flex items-center gap-2">
                            <span className="font-data-mono text-data-mono font-bold text-error">#SOS-1092</span>
                          </div>
                          <span className="font-data-mono text-[10px] text-error font-semibold">Trigger: 14:28:10</span>
                        </td>
                        <td className="py-3.5 px-4 align-middle">
                          <div className="flex items-center gap-1.5">
                            <span className="px-2 py-0.5 rounded bg-error text-on-error font-data-mono text-data-mono font-bold uppercase tracking-wider animate-pulse">Wave 1</span>
                          </div>
                          <div className="font-label-md text-label-md font-semibold text-on-surface mt-0.5">Electrical Sparking Panel</div>
                        </td>
                        <td className="py-3.5 px-4 align-middle">
                          <div className="font-label-md text-label-md font-semibold text-on-surface">Dr. Meera Nambiar</div>
                          <div className="font-label-sm text-label-sm text-on-surface-variant flex items-center gap-1">
                            <span className="material-symbols-outlined text-[13px]">call</span> +91 98450 •••••
                          </div>
                        </td>
                        <td className="py-3.5 px-4 align-middle">
                          <div className="flex items-center gap-2">
                            <img className="w-7 h-7 rounded-full object-cover" src="https://lh3.googleusercontent.com/aida-public/AB6AXuBiAOPtKbAyYtK2QgZ3Rx8bHKDyVuQVG0vtbTKCscPLmlvH93ZgTLxY4zydrIhK3Y-3HqA5CbnMwZTYIbMswFdm4aw7cYq_Qm5RiWfo6bwjIjhkB3Fz8-QMzPHE18HpsVeg8abAkLtwkSYFX9vx3dl6V1EyOuZLVD6g4aINcQLp8BuHh3TekIItsuY0QnMdyKALo9h3BQaI8OfDO_n-pW5wtCcT-1UUndIn6e2eddSsFseJglcK4N0u" alt="Specialist" />
                            <div>
                              <div className="font-label-md text-label-md font-semibold text-on-surface leading-tight">Ramesh Gowda</div>
                              <div className="flex items-center text-primary font-data-mono text-data-mono">
                                <span className="material-symbols-outlined text-[13px]" style={{ fontVariationSettings: "'FILL' 1" }}>star</span> 4.96 (Master)
                              </div>
                            </div>
                          </div>
                        </td>
                        <td className="py-3.5 px-4 align-middle">
                          <div className="font-data-mono text-data-mono font-bold text-error flex items-center gap-1">
                            <span className="material-symbols-outlined text-[14px]">timer</span> 3m remaining
                          </div>
                          <span className="font-label-sm text-label-sm text-on-surface-variant">12.934, 77.610 (HSR Sec 2)</span>
                        </td>
                        <td className="py-3.5 px-4 align-middle">
                          <span className="font-data-mono text-data-mono font-bold text-on-surface">₹12,450</span>
                          <span className="block font-label-sm text-label-sm text-primary font-semibold">Locked</span>
                        </td>
                        <td className="py-3.5 px-4 align-middle">
                          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-error-container text-on-error-container font-label-sm text-label-sm font-bold">
                            <span className="w-1.5 h-1.5 rounded-full bg-error animate-ping"></span> Critical SOS
                          </span>
                          <div className="w-24 bg-surface-container rounded-full h-1.5 mt-1.5 overflow-hidden">
                            <div className="bg-error h-full rounded-full" style={{ width: "88%" }}></div>
                          </div>
                        </td>
                        <td className="py-3.5 px-4 align-middle text-right">
                          <div className="flex items-center justify-end gap-1">
                            <button className="p-1.5 rounded-lg bg-error text-on-error hover:opacity-90 transition-all shadow-sm">
                              <span className="material-symbols-outlined text-[16px]">phone_in_talk</span>
                            </button>
                            <button className="p-1.5 rounded-lg bg-surface-container-highest text-on-surface hover:bg-surface-container-high transition-all">
                              <span className="material-symbols-outlined text-[16px]">sensors</span>
                            </button>
                          </div>
                        </td>
                      </tr>
                      
                    </tbody>
                  </table>
                </div>
                
                <div className="p-space-md bg-surface-container-low/30 flex flex-wrap items-center justify-between gap-space-sm text-on-surface-variant font-body-sm text-body-sm">
                  <div className="flex items-center gap-space-md">
                    <span>Auto-dispatch engine: <strong className="font-data-mono text-primary font-bold">ACTIVE</strong></span>
                    <span>•</span>
                    <span>Dynamic surge multiplier: <strong className="font-data-mono text-on-surface">1.0x (Normal)</strong></span>
                  </div>
                  <div className="flex items-center gap-2 font-data-mono text-data-mono">
                    <span>Showing 1 of {analytics.bookings.pending} live dispatches</span>
                    <button className="px-2 py-1 rounded bg-surface-container text-on-surface font-semibold hover:bg-surface-container-high">View All</button>
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-space-md">
                <div className="bg-surface-container-lowest p-space-md rounded-xl shadow-sm flex flex-col justify-between">
                  <div className="flex items-center justify-between">
                    <div>
                      <span className="font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant font-bold">Dispatch Match Latency</span>
                      <div className="font-headline-md text-headline-md text-on-surface tracking-tight mt-0.5">1.4s <span className="font-label-sm text-label-sm text-primary font-bold">(-0.3s)</span></div>
                    </div>
                    <span className="material-symbols-outlined text-primary text-[22px]">speed</span>
                  </div>
                  <div className="mt-4 h-16 w-full">
                    <svg className="w-full h-full text-primary" fill="none" preserveAspectRatio="none" viewBox="0 0 300 60">
                      <path d="M0,45 Q25,38 50,42 T100,28 T150,32 T200,18 T250,22 T300,12" fill="none" stroke="currentColor" strokeLinecap="round" strokeWidth="2.5"></path>
                      <path d="M0,45 Q25,38 50,42 T100,28 T150,32 T200,18 T250,22 T300,12 L300,60 L0,60 Z" fill="currentColor" fillOpacity="0.08"></path>
                    </svg>
                  </div>
                  <div className="flex justify-between font-data-mono text-[10px] text-on-surface-variant mt-2">
                    <span>10:00 AM</span>
                    <span>12:00 PM</span>
                    <span>02:00 PM</span>
                    <span>Now</span>
                  </div>
                </div>
                
                <div className="bg-surface-container-lowest p-space-md rounded-xl shadow-sm flex flex-col justify-between">
                  <div className="flex items-center justify-between">
                    <div>
                      <span className="font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant font-bold">ADR-0016 Escrow Health</span>
                      <div className="font-headline-md text-headline-md text-on-surface tracking-tight mt-0.5">99.8% Clean</div>
                    </div>
                    <span className="material-symbols-outlined text-primary-container text-[22px]">verified_user</span>
                  </div>
                  <div className="mt-3 flex items-center gap-4">
                    <div className="relative w-16 h-16 flex items-center justify-center shrink-0">
                      <svg className="w-16 h-16 transform -rotate-90" viewBox="0 0 36 36">
                        <path className="text-surface-container" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="currentColor" strokeWidth="3.5"></path>
                        <path className="text-primary" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="currentColor" strokeDasharray="98, 100" strokeLinecap="round" strokeWidth="3.5"></path>
                      </svg>
                      <span className="absolute font-data-mono text-data-mono font-bold text-on-surface">₹142.6K</span>
                    </div>
                    <div className="flex flex-col gap-1 text-on-surface-variant font-body-sm text-body-sm">
                      <div className="flex items-center gap-2">
                        <span className="w-2 h-2 rounded-full bg-primary"></span>
                        <span>Dispute free: <strong>99.8%</strong></span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="w-2 h-2 rounded-full bg-tertiary"></span>
                        <span>Warranty buffer: <strong>₹18,400</strong></span>
                      </div>
                    </div>
                  </div>
                  <div className="flex justify-between font-label-sm text-label-sm text-on-surface-variant mt-2">
                    <span>Automatic release: 48h post-OTP</span>
                    <span className="text-primary font-semibold">Zero chargebacks</span>
                  </div>
                </div>
              </div>
            </div>

            {/* RIGHT (4/12) */}
            <div className="lg:col-span-4 flex flex-col gap-space-md">
              <div className="bg-surface-container-lowest rounded-xl shadow-sm overflow-hidden flex flex-col">
                <div className="p-space-md flex items-center justify-between bg-surface-container-low/40">
                  <div className="flex items-center gap-2">
                    <span className="material-symbols-outlined text-primary text-[20px]">explore</span>
                    <span className="font-headline-md text-headline-md text-on-surface tracking-tight">Bengaluru Cluster Radar</span>
                  </div>
                </div>
                <div className="relative h-64 w-full bg-[#E5E9F0] overflow-hidden">
                  <div className="absolute inset-0 bg-primary/5 pointer-events-none"></div>
                  
                  <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 flex flex-col items-center">
                    <span className="relative flex h-8 w-8 items-center justify-center">
                      <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-error opacity-80"></span>
                      <span className="relative inline-flex rounded-full h-5 w-5 bg-error text-on-error items-center justify-center shadow-lg">
                        <span className="material-symbols-outlined text-[13px] font-bold">bolt</span>
                      </span>
                    </span>
                    <span className="mt-1 px-2 py-0.5 rounded bg-inverse-surface/90 text-inverse-on-surface font-data-mono text-[10px] font-semibold backdrop-blur-sm shadow-md">SOS-1092 (HSR)</span>
                  </div>
                  
                  <div className="absolute top-1/2 left-1/3 flex flex-col items-center">
                    <div className="w-6 h-6 rounded-full bg-primary text-on-primary flex items-center justify-center shadow-md ring-2 ring-surface-container-lowest">
                      <span className="material-symbols-outlined text-[14px]">directions_bike</span>
                    </div>
                    <span className="mt-1 px-1.5 py-0.5 rounded bg-inverse-surface/80 text-inverse-on-surface font-data-mono text-[9px] backdrop-blur-sm">Sunil (1.2km)</span>
                  </div>
                </div>
                
                <div className="p-space-md flex flex-col gap-space-sm">
                  <span className="font-label-sm text-label-sm uppercase tracking-wider text-on-surface-variant font-bold">Zone Allocation Breakdown</span>
                  <div className="flex flex-col gap-2">
                    <div>
                      <div className="flex justify-between font-label-sm text-label-sm mb-1">
                        <span className="font-semibold text-on-surface">HSR Layout & Haralur</span>
                        <span className="font-data-mono text-primary font-bold">11 Techs (100% Demand Met)</span>
                      </div>
                      <div className="w-full bg-surface-container rounded-full h-1.5 overflow-hidden">
                        <div className="bg-primary h-full rounded-full" style={{ width: "100%" }}></div>
                      </div>
                    </div>
                    <div>
                      <div className="flex justify-between font-label-sm text-label-sm mb-1">
                        <span className="font-semibold text-on-surface">Whitefield & Kadugodi</span>
                        <span className="font-data-mono text-tertiary font-bold">5 Techs (Surge Alert: 74%)</span>
                      </div>
                      <div className="w-full bg-surface-container rounded-full h-1.5 overflow-hidden">
                        <div className="bg-tertiary-container h-full rounded-full" style={{ width: "74%" }}></div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-surface-container-lowest p-space-md rounded-xl shadow-sm flex flex-col gap-space-sm">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="material-symbols-outlined text-error text-[18px]">security</span>
                    <span className="font-label-md text-label-md font-bold text-on-surface uppercase tracking-wide">Trust & Safety Live Feed</span>
                  </div>
                  <span className="font-data-mono text-data-mono text-on-surface-variant font-semibold">ADR Shield v2</span>
                </div>
                <div className="flex flex-col gap-2.5 mt-1">
                  <div className="p-2.5 rounded-lg bg-surface-container-low flex items-start gap-2.5">
                    <span className="material-symbols-outlined text-primary text-[18px] shrink-0 mt-0.5">verified</span>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <span className="font-label-md text-label-md font-semibold text-on-surface truncate">Tech #T-4401 Aadhaar FaceMatch</span>
                        <span className="font-data-mono text-[10px] text-on-surface-variant shrink-0">1m ago</span>
                      </div>
                      <p className="font-body-sm text-body-sm text-on-surface-variant line-clamp-1 mt-0.5">99.4% confidence score before entering premises.</p>
                    </div>
                  </div>
                  <div className="p-2.5 rounded-lg bg-error-container/20 flex items-start gap-2.5">
                    <span className="material-symbols-outlined text-error text-[18px] shrink-0 mt-0.5">warning</span>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <span className="font-label-md text-label-md font-semibold text-on-error-container truncate">Route Deviation Detected</span>
                        <span className="font-data-mono text-[10px] text-on-error-container shrink-0">4m ago</span>
                      </div>
                      <p className="font-body-sm text-body-sm text-on-surface-variant line-clamp-1 mt-0.5">Tech diverted 800m off mapped path near Silk Board. Auto ping sent.</p>
                    </div>
                  </div>
                </div>
                <button className="w-full py-2 rounded-lg bg-surface-container-high text-on-surface font-label-sm text-label-sm font-semibold hover:bg-surface-container-highest transition-colors text-center mt-1">
                  Audit Safety Logs (24 flagged today)
                </button>
              </div>

            </div>
          </div>
          
        </div>
      </div>
    </AdminShell>
  );
}
