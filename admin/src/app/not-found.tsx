import Link from "next/link";

/**
 * ADMIN-001. The 404 this app did not have.
 *
 * Two of the seventeen routes are reached by typing an id - `/bookings/123`,
 * `/support/456` - and an operator following a link from a customer report is
 * exactly the person most likely to mistype one. The framework's default 404
 * offers no navigation, so the recovery is a browser back button, which for a
 * deep link means going somewhere unrelated.
 *
 * The suggestions are the queues an operator is most likely to have been working
 * from, because "go to the bookings queue" is the actual next action in most
 * cases where somebody lands here.
 */
export default function AdminNotFound() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-surface px-space-lg py-space-xl">
      <div className="w-full max-w-lg text-center">
        <span
          aria-hidden="true"
          className="material-symbols-outlined text-on-surface-variant text-[40px]"
        >
          search_off
        </span>
        <h1 className="mt-space-md font-headline-lg text-headline-lg font-bold text-on-surface">
          That record does not exist
        </h1>
        <p className="mt-space-sm text-body-md text-on-surface-variant">
          The link may be mistyped, or the record may have been removed. Nothing
          was changed.
        </p>

        <nav
          aria-label="Suggested pages"
          className="mt-space-lg flex flex-wrap justify-center gap-space-sm"
        >
          <Link
            href="/bookings"
            className="rounded-lg bg-primary px-space-md py-2.5 font-label-lg text-label-lg font-semibold text-on-primary transition-opacity hover:opacity-90"
          >
            Live dispatches
          </Link>
          <Link
            href="/support"
            className="rounded-lg border border-outline px-space-md py-2.5 font-label-lg text-label-lg font-semibold text-on-surface transition-colors hover:bg-surface-container-low"
          >
            Complaints
          </Link>
          <Link
            href="/"
            className="rounded-lg border border-outline px-space-md py-2.5 font-label-lg text-label-lg font-semibold text-on-surface transition-colors hover:bg-surface-container-low"
          >
            Dashboard
          </Link>
        </nav>
      </div>
    </div>
  );
}
