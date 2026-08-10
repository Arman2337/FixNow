import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthenticationResponse } from './auth.dto';
import {
  RefreshTokenDto,
  RequestOtpDto,
  VerifyOtpDto,
} from './token-lifecycle.dto';
import { TokenLifecycleService } from './token-lifecycle.service';
import { Public } from '../common/authorization/authorization.decorators';

@Controller('auth')
export class TokenLifecycleController {
  constructor(private readonly lifecycle: TokenLifecycleService) {}

  @Public()
  @Post('otp/request')
  @HttpCode(HttpStatus.ACCEPTED)
  @Throttle({ default: { limit: 3, ttl: 60_000 } })
  async requestOtp(@Body() input: RequestOtpDto): Promise<{ accepted: true }> {
    await this.lifecycle.requestOtp(input.email);
    return { accepted: true };
  }

  @Public()
  @Post('otp/verify')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  verifyOtp(@Body() input: VerifyOtpDto): Promise<void> {
    return this.lifecycle.verifyOtp(input.email, input.code);
  }

  @Public()
  @Post('token/refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() input: RefreshTokenDto): Promise<AuthenticationResponse> {
    return this.lifecycle.refresh(input.refreshToken);
  }

  @Public()
  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  logout(@Body() input: RefreshTokenDto): Promise<void> {
    return this.lifecycle.logout(input.refreshToken, false);
  }

  @Public()
  @Post('logout-all')
  @HttpCode(HttpStatus.NO_CONTENT)
  logoutAll(@Body() input: RefreshTokenDto): Promise<void> {
    return this.lifecycle.logout(input.refreshToken, true);
  }
}
