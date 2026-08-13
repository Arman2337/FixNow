import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Req,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  Public,
  RequireOwnPermission,
} from '../common/authorization/authorization.decorators';
import type { AuthorizedRequest } from '../common/authorization/authorization.guard';
import { PERMISSIONS } from '../common/authorization/permission-policies';
import { AuthenticationResponse, EmailPasswordDto } from './auth.dto';
import { AuthService } from './auth.service';

@Controller('auth/admin')
export class AdminAuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  login(@Body() input: EmailPasswordDto): Promise<AuthenticationResponse> {
    return this.authService.loginAdmin(input);
  }

  @Get('session')
  @RequireOwnPermission(PERMISSIONS.adminSessionReadSelf)
  session(@Req() request: AuthorizedRequest) {
    const principal = request.authorizationPrincipal!;
    return { userId: principal.userId, roles: principal.roles };
  }
}
