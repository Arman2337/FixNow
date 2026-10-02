import { Injectable } from '@nestjs/common';
import { AccountStatus } from '../../users/account-status';
import type {
  AuthorizationContext,
  AuthorizationDecisionInput,
  AuthorizationOutcome,
} from './authorization.types';
import { PERMISSION_POLICIES } from './permission-policies';

/**
 * Evaluates an authorization decision.
 *
 * SEC-002. This used to answer a boolean, which forced the caller to either
 * fabricate the facts it did not have or deny every request it could not fully
 * evaluate. Both are wrong: fabricating turns the check into `x !== x` and
 * never fires; denying breaks every route whose ownership is proven later, in
 * the layer that actually loads the resource.
 *
 * The honest answer is three-valued:
 *
 *   allowed    — every applicable rule was evaluated and passed
 *   denied     — a rule failed, or a rule could not be evaluated at all
 *   deferred   — the caller/role/audience rules passed, but a rule that needs
 *                the *resource* (ownership, assignment, target identity) has
 *                not been evaluated yet because the resource has not been
 *                loaded
 *
 * `deferred` is not a hole. It raises an obligation on the principal, and
 * `OwnershipProofInterceptor` rejects the request if the handler returns
 * without discharging it. A handler that forgets to check ownership therefore
 * fails closed, which is the property SEC-002 was about.
 */
@Injectable()
export class AuthorizationPolicyService {
  evaluate(
    input: AuthorizationDecisionInput,
    accountStatus: AccountStatus,
  ): AuthorizationOutcome {
    if (accountStatus !== AccountStatus.Active) {
      return { outcome: 'denied' };
    }

    const policy = PERMISSION_POLICIES[input.permission];
    if (!policy) return { outcome: 'denied' };

    if (!input.principal.roles.some((role) => policy.roles.includes(role))) {
      return { outcome: 'denied' };
    }

    const context: AuthorizationContext = input.context ?? {};
    const principalId = input.principal.userId;

    // Rules that are answerable with caller identity alone.
    if (policy.forbidSelfTarget && context.targetPrincipalId !== undefined) {
      if (context.targetPrincipalId === principalId) {
        return { outcome: 'denied' };
      }
    }
    if (
      policy.requireIndependentApproval &&
      context.independentApproval !== undefined &&
      !context.independentApproval
    ) {
      return { outcome: 'denied' };
    }

    // Rules that need the resource. Evaluated only when the caller supplied
    // the facts; otherwise deferred to the layer that loads the resource.
    if (policy.relationship === 'self') {
      if (context.ownerId === undefined) {
        return { outcome: 'deferred', obligation: 'ownership' };
      }
      if (context.ownerId !== principalId) return { outcome: 'denied' };
    }
    if (policy.relationship === 'assigned') {
      if (context.assignedPrincipalId === undefined) {
        return { outcome: 'deferred', obligation: 'assignment' };
      }
      if (context.assignedPrincipalId !== principalId) {
        return { outcome: 'denied' };
      }
    }
    if (policy.forbidSelfTarget && context.targetPrincipalId === undefined) {
      return { outcome: 'deferred', obligation: 'target' };
    }
    if (
      policy.requireIndependentApproval &&
      context.independentApproval === undefined
    ) {
      return { outcome: 'deferred', obligation: 'approval' };
    }

    return { outcome: 'allowed' };
  }

  /**
   * Retained for callers that genuinely hold every fact up front — the
   * websocket subscribe path, which is handed a `resourceId` it has already
   * validated.
   */
  isAllowed(
    input: AuthorizationDecisionInput,
    accountStatus: AccountStatus,
  ): boolean {
    return this.evaluate(input, accountStatus).outcome === 'allowed';
  }
}
