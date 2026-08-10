import { applyDecorators, SetMetadata } from '@nestjs/common';
import type { Permission } from './permission-policies';

export const PUBLIC_ROUTE_KEY = 'fixnow.authorization.public';
export const REQUIRED_PERMISSION_KEY = 'fixnow.authorization.permission';
export const OWN_RESOURCE_KEY = 'fixnow.authorization.own-resource';

export const Public = () => SetMetadata(PUBLIC_ROUTE_KEY, true);

export const RequirePermission = (permission: Permission) =>
  SetMetadata(REQUIRED_PERMISSION_KEY, permission);

export const RequireOwnPermission = (permission: Permission) =>
  applyDecorators(
    SetMetadata(REQUIRED_PERMISSION_KEY, permission),
    SetMetadata(OWN_RESOURCE_KEY, true),
  );
