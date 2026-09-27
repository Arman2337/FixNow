import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import {
  PUBLIC_ROUTE_KEY,
  REQUIRED_PERMISSION_KEY,
} from './authorization.decorators';
import { AuthorizationService } from './authorization.service';
import type { AuthorizationPrincipal } from './authorization.types';
import type { Permission } from './permission-policies';

export interface AuthorizedRequest extends Request {
  authorizationPrincipal?: AuthorizationPrincipal;
}

@Injectable()
export class AuthorizationGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly authorization: AuthorizationService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(
      PUBLIC_ROUTE_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (isPublic) return true;

    const permission = this.reflector.getAllAndOverride<Permission>(
      REQUIRED_PERMISSION_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!permission) {
      await this.authorization.auditPolicyMissing();
      throw new ForbiddenException('Access denied');
    }

    const request = context.switchToHttp().getRequest<AuthorizedRequest>();
    const token = this.bearerToken(request.headers.authorization);
    request.authorizationPrincipal =
      await this.authorization.authorizeAccessToken(token, permission);
    return true;
  }

  private bearerToken(header: string | undefined): string {
    const match = /^Bearer ([A-Za-z0-9._~-]+)$/.exec(header ?? '');
    if (!match) throw new UnauthorizedException('Authentication required');
    return match[1];
  }
}
