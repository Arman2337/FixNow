import { LoginForm } from "@/auth/login-form";
import { getSession } from "@/auth/session";
import { redirect } from "next/navigation";

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ reason?: string }> }) {
  const session = await getSession();
  if (session.state === "authenticated") redirect("/");
  const { reason } = await searchParams;
  const expired = reason === "expired" || session.state === "expired";
  
  return (
    <main className="w-full max-w-md mx-auto p-space-lg flex items-center justify-center min-h-screen">
      <div className="flex flex-col w-full relative">
        <div className="relative w-full overflow-hidden rounded-xl bg-surface-container-lowest p-space-lg md:p-space-xl shadow-xl">
          <div className="absolute -top-24 -right-24 w-64 h-64 bg-primary/10 rounded-full blur-3xl pointer-events-none"></div>
          <div className="absolute -bottom-24 -left-24 w-64 h-64 bg-primary-fixed/25 rounded-full blur-3xl pointer-events-none"></div>
          <div className="relative z-10 flex flex-col items-center text-center">
            <div className="relative mb-space-sm flex items-center justify-center">
              <div className="w-16 h-16 rounded-xl bg-surface-container flex items-center justify-center overflow-hidden shadow-sm">
                <img alt="FixNow Corporate Brand Mark" className="w-12 h-12 object-contain" src="https://lh3.googleusercontent.com/aida-public/AB6AXuCVQn8yLUq2oF2ed1CoqsW6emlkVmg6lygsDtd3_kADKeHYWJDTS-PTVOiX6kBlIoaqVkjUupu2hclLrYfvRSbnVYRYFWdeus-_vdtHddmTXoocvN-K92P2Z9Sjct2ca4LpacuERM7cbu8dALbO-Z9iTNPbCqIwN645t4ZEo3pWAjIpT0fzmWN4Y1pDCfcgdxaeZHqy8AEsxMaB-l3ojWqHRxmZP7XB119k9l0oxj5utMAS_Dnay4PS_9_fs05smeI0yw"/>
              </div>
              <div className="absolute -bottom-1 -right-1 w-5 h-5 rounded-full bg-primary flex items-center justify-center shadow">
                <span className="material-symbols-outlined text-on-primary text-[12px]" style={{ fontVariationSettings: "'FILL' 1" }}>verified_user</span>
              </div>
            </div>
            <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-surface-container-high text-on-surface-variant font-label-sm text-label-sm mb-space-xs">
              <span className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse"></span>
              <span>Operations & Dispatch Staff Only</span>
            </div>
            <h1 className="font-headline-md text-headline-md text-on-surface tracking-tight">FixNow Admin Portal</h1>
            <p className="font-body-sm text-body-sm text-on-surface-variant mt-1 max-w-xs leading-snug">
              Enter your corporate credentials to access the live dispatch radar, provider KYC adjudication, and escrow compliance engines.
            </p>
          </div>
          
          <LoginForm expired={expired} />
          
          <div className="relative z-10 mt-space-md text-center">
            <a className="font-label-sm text-label-sm text-on-surface-variant hover:text-primary transition-colors inline-flex items-center gap-1" href="mailto:sec-ops@fixnow.internal">
              <span className="material-symbols-outlined text-[14px]">contact_support</span>
              <span>Trouble signing in? Contact IT Security Operations Desk</span>
            </a>
          </div>
          <div className="relative z-10 mt-space-lg pt-space-md border-t-0 flex flex-col gap-2 text-center bg-surface-container-low/60 -mx-space-lg md:-mx-space-xl -mb-space-lg md:-mb-space-xl p-space-md rounded-b-xl">
            <div className="flex items-center justify-center gap-3 text-on-surface-variant">
              <div className="flex items-center gap-1 font-label-sm text-label-sm">
                <span className="material-symbols-outlined text-primary text-[15px]" style={{ fontVariationSettings: "'FILL' 1" }}>verified</span>
                <span>ISO 27001 Certified</span>
              </div>
              <span className="text-outline-variant">•</span>
              <div className="flex items-center gap-1 font-label-sm text-label-sm">
                <span className="material-symbols-outlined text-primary text-[15px]" style={{ fontVariationSettings: "'FILL' 1" }}>account_balance</span>
                <span>RBI Escrow Regulated</span>
              </div>
            </div>
            <p className="font-body-sm text-[11px] leading-tight text-on-surface-variant max-w-xs mx-auto">
              All administrative actions, live location telemetry queries, and escrow releases are cryptographically signed, immutable, and permanently audited.
            </p>
            <div className="mt-1 inline-flex items-center justify-center gap-2 font-data-mono text-data-mono text-on-surface-variant/90 text-[10px]">
              <span className="w-2 h-2 rounded-full bg-primary animate-pulse"></span>
              <span>Cluster: us-east-04</span>
              <span className="text-outline-variant">|</span>
              <span>Gateway: 1.2ms</span>
              <span className="text-outline-variant">|</span>
              <span className="text-primary font-bold">100% Operational</span>
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}
