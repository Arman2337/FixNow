import type { Permission, RoleCode } from './permission-policies';

export interface AuthorizationPrincipal {
  readonly userId: string;
  readonly sessionId: string;
  readonly roles: readonly RoleCode[];

  /**
   * SEC-002: proof that this request's handler actually verified that the caller
   * owns the resource it is about to touch.
   *
   * The guard can prove *who the caller is* — that is a token, a session row and
   * a set of role rows. It cannot prove *whose resource this is*, because the
   * resource is named by a path or body parameter that the guard never loads.
   *
   * So the obligation is transferred rather than faked. The guard raises it, the
   * layer holding the owning column discharges it with a real comparison (see
   * `resource-ownership.ts`), and `OwnershipProofInterceptor` rejects the request
   * if the handler returned without discharging it. A handler that forgets now
   * fails closed instead of shipping a silent hole.
   *
   * Mutable on purpose: it is per-request state on a per-request object, written
   * exactly once by the discharge helper.
   *
   * @internal
   */
  ownershipProven?: boolean;
}

export interface AuthorizationContext {
  readonly ownerId?: string;
  readonly assignedPrincipalId?: string;
  readonly targetPrincipalId?: string;
  readonly independentApproval?: boolean;
}

export interface AuthorizationDecisionInput {
  readonly principal: AuthorizationPrincipal;
  readonly permission: Permission;
  readonly context?: AuthorizationContext;
}

/**
 * What a self/assigned/target-scoped rule still needs before it can be judged.
 *
 * - `ownership`  — the resource's owning column, via `assertOwnedResource`
 * - `assignment` — the assignee column, via `assertAssignedResource`
 * - `target`     — the target's id, via `assertTargetIsNotSelf`
 * - `approval`   — an independent-approval flag, via `assertIndependentApproval`
 */
export type OwnershipObligation =
  'ownership' | 'assignment' | 'target' | 'approval';

export type AuthorizationOutcome =
  | { readonly outcome: 'allowed' }
  | { readonly outcome: 'denied' }
  | {
      readonly outcome: 'deferred';
      readonly obligation: OwnershipObligation;
    };
