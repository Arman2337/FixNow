import { Injectable } from '@nestjs/common';
import { AccountStatus } from '../../users/account-status';
import type {
  AuthorizationContext,
  AuthorizationDecisionInput,
} from './authorization.types';
import { PERMISSION_POLICIES } from './permission-policies';

@Injectable()
export class AuthorizationPolicyService {
  isAllowed(
    input: AuthorizationDecisionInput,
    accountStatus: AccountStatus,
  ): boolean {
    if (accountStatus !== AccountStatus.Active) return false;

    const policy = PERMISSION_POLICIES[input.permission];
    if (!policy) return false;
    if (!input.principal.roles.some((role) => policy.roles.includes(role))) {
      return false;
    }

    const context: AuthorizationContext = input.context ?? {};
    if (
      policy.relationship === 'self' &&
      context.ownerId !== input.principal.userId
    ) {
      return false;
    }
    if (
      policy.relationship === 'assigned' &&
      context.assignedPrincipalId !== input.principal.userId
    ) {
      return false;
    }
    if (
      policy.forbidSelfTarget &&
      context.targetPrincipalId === input.principal.userId
    ) {
      return false;
    }
    if (policy.requireIndependentApproval && !context.independentApproval) {
      return false;
    }

    return true;
  }
}
