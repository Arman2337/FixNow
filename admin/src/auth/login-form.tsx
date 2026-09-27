"use client";

import { useActionState, useState } from "react";
import { loginAction, type LoginState } from "./actions";
import { refreshAction } from "./actions";

const initialState: LoginState = {};

export function LoginForm({ expired }: { expired?: boolean }) {
  const [state, action, pending] = useActionState(loginAction, initialState);
  const [showPwd, setShowPwd] = useState(false);

  return (
    <>
      {expired && (
        <div role="status" className="relative z-10 mt-6 rounded-xl border border-warning bg-warning-soft p-4">
          <p className="m-0 font-label-md text-label-md text-on-surface">Your session expired</p>
          <p className="mt-1 mb-0 text-body-sm text-on-surface-variant">
            Continue securely if your staff session is still valid, or sign in again.
          </p>
          <form action={refreshAction}>
            <button className="mt-3 h-11 rounded-lg border border-outline-variant px-4 text-label-md font-label-md">
              Continue session
            </button>
          </form>
        </div>
      )}

      <form action={action} noValidate className="relative z-10 mt-space-lg flex flex-col gap-space-md" id="admin-auth-form">
        {state.message && (
          <div role="alert" className="rounded-lg border border-error bg-error-container p-3 text-sm text-on-error-container">
            {state.message}
          </div>
        )}

        <div className="flex flex-col gap-1.5 text-left">
          <label className="font-label-md text-label-md text-on-surface flex items-center justify-between" htmlFor="email">
            <span>Corporate Email / LDAP ID</span>
            <span className="font-data-mono text-data-mono text-on-surface-variant/80">@fixnow.internal</span>
          </label>
          <div className="relative flex items-center">
            <span className="material-symbols-outlined absolute left-3 text-on-surface-variant text-[20px]">badge</span>
            <input
              id="email"
              name="email"
              type="email"
              autoComplete="username"
              required
              placeholder="dispatcher.id@fixnow.internal"
              className="w-full h-12 pl-10 pr-3 rounded-lg bg-surface-container-low font-body-md text-body-md text-on-surface outline-none focus:bg-surface-container-lowest focus:shadow-md transition-all placeholder:text-on-surface-variant/50"
            />
          </div>
          {state.errors?.email && <p className="mt-1 text-sm text-error">{state.errors.email}</p>}
        </div>

        <div className="flex flex-col gap-1.5 text-left">
          <label className="font-label-md text-label-md text-on-surface flex items-center justify-between" htmlFor="password">
            <span>Password</span>
          </label>
          <div className="relative flex items-center">
            <span className="material-symbols-outlined absolute left-3 text-on-surface-variant text-[20px]">lock</span>
            <input
              id="password"
              name="password"
              type={showPwd ? "text" : "password"}
              autoComplete="current-password"
              required
              placeholder="••••••••••••••••"
              className="w-full h-12 pl-10 pr-10 rounded-lg bg-surface-container-low font-body-md text-body-md text-on-surface outline-none focus:bg-surface-container-lowest focus:shadow-md transition-all placeholder:text-on-surface-variant/50"
            />
            <button
              type="button"
              onClick={() => setShowPwd(!showPwd)}
              aria-label="Toggle password visibility"
              className="absolute right-3 text-on-surface-variant hover:text-on-surface flex items-center justify-center p-1 rounded transition-colors"
            >
              <span className="material-symbols-outlined text-[20px]">{showPwd ? "visibility_off" : "visibility"}</span>
            </button>
          </div>
          {state.errors?.password && <p className="mt-1 text-sm text-error">{state.errors.password}</p>}
        </div>

        <div className="p-3 rounded-lg bg-surface-container flex items-start gap-2.5 text-left">
          <span className="material-symbols-outlined text-primary text-[18px] shrink-0 mt-0.5" style={{ fontVariationSettings: "'FILL' 1" }}>shield_person</span>
          <div className="flex flex-col">
            <span className="font-label-sm text-label-sm text-on-surface">Access is assigned by the server</span>
            <span className="font-body-sm text-body-sm text-on-surface-variant leading-tight">Your staff roles determine which operations and data you can access after sign-in.</span>
          </div>
        </div>

        <div className="flex flex-col gap-2.5 mt-space-xs">
          <button
            type="submit"
            disabled={pending}
            className="w-full h-12 rounded-xl bg-primary text-on-primary font-label-md text-label-md flex items-center justify-center gap-2 shadow-md hover:bg-primary-container active:scale-[0.99] transition-all disabled:opacity-60 disabled:cursor-not-allowed"
          >
            <span className="material-symbols-outlined text-[20px]">lock_open</span>
            <span>{pending ? "Authenticating..." : "Authenticate & Access Console"}</span>
          </button>
          <button
            type="button"
            disabled
            aria-describedby="sso-unavailable"
            className="w-full h-12 rounded-xl bg-surface-container text-on-surface font-label-md text-label-md flex items-center justify-center gap-2 opacity-60 cursor-not-allowed"
          >
            <span className="material-symbols-outlined text-[20px] text-secondary">domain</span>
            <span>Corporate SSO unavailable</span>
          </button>
          <p id="sso-unavailable" className="m-0 text-center text-xs text-on-surface-variant">Ask an administrator to configure an approved SSO provider.</p>
        </div>
      </form>
    </>
  );
}
