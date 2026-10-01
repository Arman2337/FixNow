"use client";

/**
 * ADMIN-001. The last-resort boundary.
 *
 * `error.tsx` covers everything below the root layout, but it renders inside
 * that layout - so if the failure is in the layout itself, there is nothing left
 * to catch it and the operator gets an unstyled white page with no navigation at
 * all. `global-error.tsx` replaces the root layout, so it has to provide its own
 * `html` and `body` and cannot use the app's design tokens via Tailwind's
 * `@theme` block in the ordinary way.
 *
 * That is exactly why the styling here is inline rather than class-based: the
 * global stylesheet is loaded by the root layout, which is the thing that just
 * failed. Self-contained is the only kind of styling that works at this level.
 */
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="en">
      <body
        style={{
          margin: 0,
          minHeight: "100vh",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: "#f8f9ff",
          color: "#0b1c30",
          fontFamily:
            "system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif",
          padding: "2rem",
        }}
      >
        <div
          role="alert"
          style={{
            maxWidth: 480,
            textAlign: "center",
            background: "#ffffff",
            border: "1px solid #bccac0",
            borderRadius: 14,
            padding: "1.5rem",
          }}
        >
          <h1 style={{ fontSize: 22, fontWeight: 700, margin: 0 }}>
            The admin console failed to start
          </h1>
          <p
            style={{
              fontSize: 15,
              lineHeight: 1.6,
              color: "#3d4a42",
              marginTop: "0.75rem",
            }}
          >
            This is a problem with the console itself rather than with the page you
            asked for. Retrying often clears it.
          </p>
          {error.digest ? (
            <p style={{ fontSize: 12, color: "#3d4a42", marginTop: "0.75rem" }}>
              Reference: <code>{error.digest}</code>
            </p>
          ) : null}
          <button
            type="button"
            onClick={reset}
            style={{
              marginTop: "1.5rem",
              background: "#006948",
              color: "#ffffff",
              border: 0,
              borderRadius: 10,
              padding: "0.625rem 1.25rem",
              fontSize: 14,
              fontWeight: 600,
              cursor: "pointer",
            }}
          >
            Reload the console
          </button>
        </div>
      </body>
    </html>
  );
}
