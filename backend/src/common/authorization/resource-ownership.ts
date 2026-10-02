import { ForbiddenException } from '@nestjs/common';
import type { AuthorizationPrincipal } from './authorization.types';

/**
 * The supported ways to discharge a deferred self/assigned/target-scoped
 * authorization obligation.
 *
 * SEC-002: the guard can prove *who the caller is* (token + session + role
 * rows) but cannot prove *whose resource this is*, because the resource is
 * named by a path or body parameter it never loads. The old code resolved that
 * by writing the caller's own id into the owner field, which made the policy's
 * `ownerId !== userId` comparison evaluate `x !== x` — a check that could never
 * fail on any of ~30 routes.
 *
 * So the obligation is transferred to the one layer that has the owning column
 * in hand and cannot be skipped:
 *
 *   1. the guard marks the principal's ownership obligation as outstanding
 *   2. the handler calls one of the helpers below, which compares the real
 *      column against the caller and clears the obligation
 *   3. `OwnershipProofInterceptor` rejects the request if the handler returned
 *      with the obligation still outstanding
 *
 * A handler that forgets to check ownership now fails closed instead of
 * shipping a silent hole.
 */

/**
 * Proves the caller owns the resource, by comparing the resource's real owning
 * column against the caller's id.
 *
 * @param principal `request.authorizationPrincipal!`
 * @param ownerId the resource's owner column, e.g. `booking.customerId`
 * @param ownerIdLabel names the column in audit logs, so a bug report is
 *   actionable without the error leaking the value itself
 * @throws ForbiddenException when the caller is not the owner
 */
export function assertOwnedResource(
  principal: AuthorizationPrincipal | undefined,
  ownerId: string | null | undefined,
  ownerIdLabel = 'owner',
): void {
  if (!principal) throw new ForbiddenException('Access denied');
  if (!ownerId || ownerId !== principal.userId) {
    // Deliberately does not echo the expected owner: a 403 that names the real
    // owner turns this endpoint into an existence oracle for user ids.
    throw new ForbiddenException('Access denied');
  }
  principal.ownershipProven = true;
  void ownerIdLabel;
}

/**
 * Proves the caller owns the resource for the "either party may act" case, e.g.
 * a booking's customer or its assigned provider.
 */
export function assertOwnedByParty(
  principal: AuthorizationPrincipal | undefined,
  ...candidateOwnerIds: ReadonlyArray<string | null | undefined>
): void {
  if (!principal) throw new ForbiddenException('Access denied');
  const owned = candidateOwnerIds.some(
    (candidate) => !!candidate && candidate === principal.userId,
  );
  if (!owned) throw new ForbiddenException('Access denied');
  principal.ownershipProven = true;
}

/**
 * The collection-shaped counterpart to `assertOwnedResource`.
 *
 * Routes that act on "my addresses", "my availability", "my notifications" do
 * not name one resource; they name a set, and the ownership guarantee is
 * carried by the query predicate (`where: { userId }`). That predicate is easy
 * to forget on a new method and impossible for a reader to verify, so the
 * handler hands the rows it actually read or wrote to this function and every
 * row's owner column is compared against the caller.
 *
 * Passing an empty array is rejected rather than accepted: a handler that
 * matched nothing has proven nothing, and treating it as a pass would let a
 * dropped `where` clause turn a list endpoint into a leak of other people's
 * rows.
 */
export function assertScopedToCaller(
  principal: AuthorizationPrincipal | undefined,
  rows: ReadonlyArray<object>,
  ownerKey: string,
): void {
  if (!principal) throw new ForbiddenException('Access denied');
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new ForbiddenException('Access denied');
  }
  // Read through an index signature on a local `Record<string, unknown>`, which
  // keeps the property access typed instead of `any` while still accepting
  // entity instances at the call site.
  const owned = rows.every((row) => {
    const record = row as Record<string, unknown>;
    return record[ownerKey] === principal.userId;
  });
  if (!owned) throw new ForbiddenException('Access denied');
  principal.ownershipProven = true;
}

/**
 * `assertScopedToCaller` for collections that are legitimately empty, and for
 * the TypeORM entities that `assertScopedToCaller`'s index-signature parameter
 * type cannot accept (an entity class has no `[key: string]: unknown` index).
 *
 * A customer with no saved addresses, or a provider who has never confirmed a
 * recurring schedule, gets an empty list. `assertScopedToCaller` answers 403 for
 * that, which is the wrong answer: an empty result set contains nothing that
 * could leak, and the guarantee the caller needs is precisely that the query
 * could not have matched a foreign row.
 *
 * The failure this guards against — a dropped `where: { userId }` — cannot
 * produce an empty result set; it produces *other people's* rows, which the
 * non-empty branch rejects. So the empty branch is a real (if vacuous) proof
 * rather than a skip.
 */
export function assertOwnedCollection(
  principal: AuthorizationPrincipal | undefined,
  rows: ReadonlyArray<object>,
  ownerKey: string,
): void {
  if (!principal) throw new ForbiddenException('Access denied');
  if (!Array.isArray(rows) || rows.length === 0) {
    principal.ownershipProven = true;
    return;
  }
  // Narrowing cast: every row is read by owner key at runtime, exactly as
  // `assertScopedToCaller` does. TypeScript cannot see that through a TypeORM
  // entity class, which has no index signature.
  assertScopedToCaller(
    principal,
    rows as ReadonlyArray<Record<string, unknown>>,
    ownerKey,
  );
}

/**
 * Discharges an `assigned` obligation: proves the caller is the party the
 * resource is assigned to.
 */
export function assertAssignedResource(
  principal: AuthorizationPrincipal | undefined,
  assigneeId: string | null | undefined,
  assigneeIdLabel = 'assignee',
): void {
  if (!principal) throw new ForbiddenException('Access denied');
  if (!assigneeId || assigneeId !== principal.userId) {
    throw new ForbiddenException('Access denied');
  }
  principal.ownershipProven = true;
  void assigneeIdLabel;
}

/**
 * Discharges a `forbidSelfTarget` obligation: proves the action is not aimed at
 * the caller's own account.
 */
export function assertTargetIsNotSelf(
  principal: AuthorizationPrincipal | undefined,
  targetId: string | null | undefined,
): void {
  if (!principal) throw new ForbiddenException('Access denied');
  if (!targetId || targetId === principal.userId) {
    throw new ForbiddenException('Access denied');
  }
  principal.ownershipProven = true;
}

/**
 * Discharges a `requireIndependentApproval` obligation.
 */
export function assertIndependentApproval(
  principal: AuthorizationPrincipal | undefined,
  independentApproval: boolean,
): void {
  if (!principal) throw new ForbiddenException('Access denied');
  if (!independentApproval) throw new ForbiddenException('Access denied');
  principal.ownershipProven = true;
}

/**
 * Marks a route as having no resource to prove ownership over.
 *
 * A handful of self-scoped permissions address the caller's own singleton —
 * `/users/me/profile`, `/auth/admin/session` — where the resource *is* the
 * caller and there is no separate owning column to compare. Those routes must
 * still say so explicitly, so that a self-scoped route can never reach a
 * handler without either a real ownership assertion or this marker.
 */
export function assertNoResourceToProve(
  principal: AuthorizationPrincipal | undefined,
): void {
  if (!principal) throw new ForbiddenException('Access denied');
  principal.ownershipProven = true;
}
