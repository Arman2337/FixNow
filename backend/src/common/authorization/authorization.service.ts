import {
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { MoreThan, IsNull, DataSource } from 'typeorm';
import { AuthAuditEventEntity } from '../../auth/auth-audit-event.entity';
import { AuthSessionEntity } from '../../auth/auth-session.entity';
import {
  ACCESS_TOKEN_AUDIENCE,
  ADMIN_ACCESS_TOKEN_AUDIENCE,
  ACCESS_TOKEN_ISSUER,
} from '../../auth/auth.constants';
import { UserRoleEntity } from '../../users/user-role.entity';
import { UserEntity } from '../../users/user.entity';
import type {
  AuthorizationContext,
  AuthorizationPrincipal,
} from './authorization.types';
import { AuthorizationPolicyService } from './authorization-policy.service';
import {
  PERMISSION_POLICIES,
  type Permission,
  type RoleCode,
} from './permission-policies';

interface AccessTokenClaims {
  sub?: string;
  sessionId?: string;
}

@Injectable()
export class AuthorizationService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly jwtService: JwtService,
    private readonly policy: AuthorizationPolicyService,
  ) {}

  async authorizeAccessToken(
    token: string,
    permission: Permission,
    context?: AuthorizationContext,
    ownResource = false,
  ): Promise<AuthorizationPrincipal> {
    let claims: AccessTokenClaims;
    try {
      claims = await this.jwtService.verifyAsync<AccessTokenClaims>(token, {
        issuer: ACCESS_TOKEN_ISSUER,
        audience:
          PERMISSION_POLICIES[permission].audience === 'admin'
            ? ADMIN_ACCESS_TOKEN_AUDIENCE
            : ACCESS_TOKEN_AUDIENCE,
      });
    } catch {
      await this.audit(null, 'authorization.authentication', 'denied');
      throw new UnauthorizedException('Authentication required');
    }

    if (
      !claims.sub ||
      !claims.sessionId ||
      !this.isUuid(claims.sub) ||
      !this.isUuid(claims.sessionId)
    ) {
      await this.audit(null, 'authorization.authentication', 'denied');
      throw new UnauthorizedException('Authentication required');
    }

    const [user, session, grants] = await Promise.all([
      this.dataSource.getRepository(UserEntity).findOneBy({ id: claims.sub }),
      this.dataSource.getRepository(AuthSessionEntity).findOneBy({
        id: claims.sessionId,
        userId: claims.sub,
      }),
      this.dataSource.getRepository(UserRoleEntity).find({
        where: [
          { userId: claims.sub, expiresAt: IsNull() },
          { userId: claims.sub, expiresAt: MoreThan(new Date()) },
        ],
        relations: { role: true },
      }),
    ]);

    if (
      !user ||
      !session ||
      session.revokedAt ||
      session.expiresAt.getTime() <= Date.now()
    ) {
      await this.audit(
        user?.id ?? null,
        'authorization.authentication',
        'denied',
      );
      throw new UnauthorizedException('Authentication required');
    }

    const principal: AuthorizationPrincipal = {
      userId: user.id,
      sessionId: session.id,
      roles: grants.map((grant) => grant.role.code as RoleCode),
    };
    const resolvedContext = ownResource
      ? { ...context, ownerId: user.id }
      : context;
    const allowed = this.policy.isAllowed(
      { principal, permission, context: resolvedContext },
      user.status,
    );
    await this.audit(
      user.id,
      allowed ? 'authorization.allowed' : 'authorization.denied',
      allowed ? 'success' : 'denied',
    );
    if (!allowed) throw new ForbiddenException('Access denied');
    return principal;
  }

  async auditPolicyMissing(): Promise<void> {
    await this.audit(null, 'authorization.policy_missing', 'denied');
  }

  private isUuid(value: string): boolean {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      value,
    );
  }

  private async audit(
    userId: string | null,
    eventType: string,
    outcome: string,
  ): Promise<void> {
    await this.dataSource.getRepository(AuthAuditEventEntity).save({
      userId,
      eventType,
      outcome,
    });
  }
}
