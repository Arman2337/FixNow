"use client";

import { useActionState } from "react";
import { loginAction, type LoginState } from "./actions";

const initialState: LoginState = {};

export function LoginForm() {
  const [state, action, pending] = useActionState(loginAction, initialState);
  return (
    <form action={action} noValidate className="mt-8 space-y-5">
      {state.message ? <div role="alert" className="rounded-xl border border-[var(--color-danger)] bg-[var(--color-danger-soft)] p-3 text-sm text-[var(--color-text-primary)]">{state.message}</div> : null}
      <div>
        <label htmlFor="email" className="block text-sm font-semibold">Work email</label>
        <input id="email" name="email" type="email" autoComplete="username" required aria-describedby={state.errors?.email ? "email-error" : undefined} aria-invalid={Boolean(state.errors?.email)} className="mt-2 min-h-12 w-full rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] px-4 text-base text-[var(--color-text-primary)]" />
        {state.errors?.email ? <p id="email-error" className="mt-2 text-sm text-[var(--color-danger)]">{state.errors.email}</p> : null}
      </div>
      <div>
        <label htmlFor="password" className="block text-sm font-semibold">Password</label>
        <input id="password" name="password" type="password" autoComplete="current-password" required aria-describedby={state.errors?.password ? "password-error" : undefined} aria-invalid={Boolean(state.errors?.password)} className="mt-2 min-h-12 w-full rounded-xl border border-[var(--color-border-default)] bg-[var(--color-surface-secondary)] px-4 text-base text-[var(--color-text-primary)]" />
        {state.errors?.password ? <p id="password-error" className="mt-2 text-sm text-[var(--color-danger)]">{state.errors.password}</p> : null}
      </div>
      <button type="submit" disabled={pending} className="min-h-12 w-full rounded-xl bg-[var(--color-primary)] px-5 text-sm font-semibold text-[var(--color-on-primary)] disabled:cursor-not-allowed disabled:opacity-60">
        {pending ? "Signing in…" : "Sign in securely"}
      </button>
    </form>
  );
}
