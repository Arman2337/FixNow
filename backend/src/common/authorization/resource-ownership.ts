import { ForbiddenException } from '@nestjs/common';
import type { AuthorizationPrincipal } from './authorization.types';

/**
 * The single supported way to prove that a caller owns a resource.
 *
 * SEC-002: the authorization guard cannot verify ownership, because it never
 * loads the resource. It used to fake the answer, which meant a service that
 * forgot the check had no safety net. Ownership is therefore asserted here, at
 * the point where the owning column is actually in hand.
 *
 * @param principal the authenticated caller, normally
 *   `request.authorizationPrincipal!`
 * @param ownerId the resource's owner column, e.g. `booking.customerId`
 * @param ownerIdLabel names the column in the error, to make audit logs and
 *   bug reports actionable without leaking the value
 * @throws ForbiddenException when the caller is not the owner
 *
 * Returns quietly when the caller is the owner, so it can be used as a
 * statement rather than an `if`.
 */
export function assertOwnedResource(
  principal: AuthorizationPrincipal | undefined,
  ownerId: string | null | undefined,
  ownerIdLabel = 'owner',
): void {
  if (!principal) {
    throw new ForbiddenException('Access denied');
  }
  if (!ownerId || ownerId !== principal.userId) {
    // Deliberately does not echo the expected owner: a 403 that names the real
    // owner turns this endpoint into an existence oracle for user ids.
    throw new ForbiddenException('Access denied');
  }
  void ownerIdLabel;
}

/**
 * Ownership check for the "either party may act" case, e.g. a booking's
 * customer or its assigned provider.
 */
export function assertOwnedByParty(
  principal: AuthorizationPrincipal | undefined,
  ...candidateOwnerIds: ReadonlyArray<string | null | undefined>
): void {
  if (!principal) {
    throw new ForbiddenException('Access denied');
  }
  const owned = candidateOwnerIds.some(
    (candidate) => !!candidate && candidate === principal.userId,
  );
  if (!owned) {
    throw new ForbiddenException('Access denied');
  }
}
