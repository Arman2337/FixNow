import type { CSSProperties } from "react";

/**
 * ADMIN-001. The four boundary files this app did not have.
 *
 * Every one of the seventeen admin pages fetches on the server - Server Actions
 * and `await`ed queries, per the project's stated architecture - and none of them
 * had a `loading.tsx`, an `error.tsx` or a `not-found.tsx`. The consequences are
 * worse than a missing spinner:
 *
 *  - A slow dashboard blocked the whole document, so the browser showed a blank
 *    page with no indication that anything was happening. An operator could not
 *    tell "loading" from "hung", and the natural response was to reload, which
 *    re-ran the expensive aggregation.
 *  - A failed Server Action produced Next's default error screen, which is
 *    legible but says nothing about what failed or what to do next - and in an
 *    operations console the answer to "what do I do" is the whole point.
 *  - A mistyped URL rendered the framework's default 404, offering no way back
 *    into the app.
 *
 * These live at the app root rather than per-segment, so all seventeen routes
 * are covered by four files. That is deliberate: seventeen copies is seventeen
 * chances to drift, and the audit's complaint was partly that the app had
 * *private* state clones in six places already.
 *
 * Every state here is derived from the design tokens - no literal colours, no
 * raw hex - so the boundaries cannot become a second, divergent visual language.
 */

/** Skeleton block. Sized by the caller; this only provides the shimmer. */
function Skeleton({
  className = "",
  style,
}: {
  className?: string;
  style?: CSSProperties;
}) {
  return (
    <div
      aria-hidden="true"
      className={`animate-pulse rounded-md bg-surface-container ${className}`}
      style={style}
    />
  );
}

/**
 * The loading state.
 *
 * `role="status"` with a visually hidden label, because a skeleton with no
 * announcement is invisible to a screen reader - the operator hears silence and
 * has no way to know the page is coming. The label is deliberately short: it is
 * announced on every navigation, and a paragraph would be read aloud on each one.
 */
export default function AdminLoading() {
  return (
    <div
      role="status"
      aria-live="polite"
      aria-busy="true"
      className="min-h-screen bg-surface px-space-lg py-space-xl"
    >
      <span className="sr-only">Loading…</span>

      <div className="mx-auto w-full max-w-7xl">
        <div className="mb-space-xl flex items-center justify-between">
          <div>
            <Skeleton className="h-8 w-56" />
            <Skeleton className="mt-2 h-4 w-80" />
          </div>
          <Skeleton className="h-10 w-32 rounded-lg" />
        </div>

        <div className="grid grid-cols-2 gap-space-md lg:grid-cols-4">
          {Array.from({ length: 4 }, (_, index) => (
            <div
              key={index}
              className="rounded-xl border border-outline-variant/30 bg-surface-container-lowest p-space-md"
            >
              <Skeleton className="h-3 w-24" />
              <Skeleton className="mt-3 h-7 w-16" />
            </div>
          ))}
        </div>

        <div className="mt-space-lg rounded-xl border border-outline-variant/30 bg-surface-container-lowest p-space-md">
          <Skeleton className="h-5 w-40" />
          <div className="mt-space-md space-y-2">
            {Array.from({ length: 8 }, (_, index) => (
              <Skeleton key={index} className="h-11 w-full" />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
