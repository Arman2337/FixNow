import type { Permission, RoleCode } from './permission-policies';

export interface AuthorizationPrincipal {
  readonly userId: string;
  readonly sessionId: string;
  readonly roles: readonly RoleCode[];
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
