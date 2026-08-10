import { SetMetadata } from '@nestjs/common';
import type { Permission } from './permission-policies';

export const PUBLIC_ROUTE_KEY = 'fixnow.authorization.public';
export const REQUIRED_PERMISSION_KEY = 'fixnow.authorization.permission';

export const Public = () => SetMetadata(PUBLIC_ROUTE_KEY, true);

export const RequirePermission = (permission: Permission) =>
  SetMetadata(REQUIRED_PERMISSION_KEY, permission);
