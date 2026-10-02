"use client";

import { useEffect } from "react";
import Link from "next/link";

/**
 * ADMIN-001. The error boundary this app did not have.
 *
 * A server component that throws produces Next's default error screen. That
 * screen is legible and completely useless in an operations console: it does not
 * say what failed, it offers no way to retry, and it gives the operator no way
 * back into the app. For someone whose job is to resolve a customer's stuck
 * booking, "something went wrong" with a browser reload button is the wrong
 * tool - reloading re-runs the action that just failed.
 *
 * So this boundary does three things the default does not:
 *
 *  1. Says what to do, which is usually "try again" - a retry is a real
 *     affordance here because the underlying operation is idempotent.
 *  2. Gives a reference to quote. `digest` is the framework's own id for the
 *     server-side error, and it is the only thing that lets an engineer find the
 *     corresponding log line. Without it, an operator's report of "the bookings
 *     page broke" is unactionable.
 *  3. Never shows the raw message in production. `error.message` in development
 *     is a stack trace's first line; in production it can carry a query or an
 *     internal identifier. The message is rendered only when `NODE_ENV` is not
 *     production, which is the same rule the API's exception filter applies.
 */
export default function AdminError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Reported to whatever the deployment collects. Left as a console call rather
    // than a vendor SDK because adding Sentry is a separate decision with its
    // own configuration, and an unconfigured reporter is worse than none - it
    // fails silently and looks like it works.
    console.error(
      `[admin] unhandled render error${error.digest ? ` (digest ${error.digest})` : ""}`,
      error,
    );
  }, [error]);

  const isDevelopment = process.env.NODE_ENV !== "production";

  return (
    <div className="flex min-h-screen items-center justify-center bg-surface px-space-lg py-space-xl">
      <div
        role="alert"
        className="w-full max-w-lg rounded-xl border border-outline-variant/30 bg-surface-container-lowest p-space-lg"
      >
        <div className="flex items-start gap-space-md">
          <span
            aria-hidden="true"
            className="material-symbols-outlined text-error text-[28px]"
          >
            error
          </span>
          <div className="min-w-0 flex-1">
            <h1 className="font-headline-md text-headline-md font-bold text-on-surface">
              This page could not be loaded
            </h1>
            <p className="mt-space-sm text-body-md text-on-surface-variant">
              The request did not complete. Nothing was changed, so it is safe to
              try again.
            </p>

            {error.digest ? (
              <p className="mt-space-md text-label-sm text-on-surface-variant">
                Quote this reference if you report the problem:{" "}
                <code className="rounded bg-surface-container px-1.5 py-0.5 font-mono text-on-surface">
                  {error.digest}
                </code>
              </p>
            ) : null}

            {isDevelopment ? (
              <pre className="mt-space-md overflow-x-auto rounded-lg bg-surface-container p-3 text-[12px] leading-relaxed text-on-surface">
                {error.message}
              </pre>
            ) : null}

            <div className="mt-space-lg flex flex-wrap gap-space-sm">
              <button
                type="button"
                onClick={reset}
                className="rounded-lg bg-primary px-space-md py-2.5 font-label-lg text-label-lg font-semibold text-on-primary transition-opacity hover:opacity-90"
              >
                Try again
              </button>
              <Link
                href="/"
                className="rounded-lg border border-outline px-space-md py-2.5 font-label-lg text-label-lg font-semibold text-on-surface transition-colors hover:bg-surface-container-low"
              >
                Back to dashboard
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
