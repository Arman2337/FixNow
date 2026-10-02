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

/**
 * API-002. Per-route limits for the three unauthenticated session endpoints.
 *
 * These three sat on the global 60/min bucket, which is the wrong shape for all
 * three reasons:
 *
 *  - `token/refresh` is the endpoint that turns a stolen refresh token into an
 *    access token, and each call is a transaction that takes a `FOR UPDATE` row
 *    lock on the session plus three or four writes. At 60/min an attacker
 *    holding one stolen token gets 60 authenticated transactions a minute, and
 *    because every one of them is legitimate-looking, none of them is
 *    distinguishable in the logs from a real client retrying.
 *  - the limit is global, so one abusive caller exhausts the bucket for every
 *    legitimate user behind the same NAT or proxy.
 *  - `logout-all` writes to every session a user has, so it is the most
 *    expensive write available on an unauthenticated route.
 *
 * The values are deliberately above what a real client needs — a mobile app
 * refreshing on focus can fire several in a burst, and one retry after a flaky
 * network is normal — and deliberately below what an attacker wants. Throttling
 * these routes too hard produces the worst failure mode of all: a user who gets
 * logged out during a patch rollout and cannot get back in.
 */
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

  /**
   * Rotating refresh is the most valuable unauthenticated operation in the
   * system, so it gets its own bucket rather than sharing one. 30/min leaves
   * ample headroom for a burst of parallel foreground/background refreshes
   * while capping a stolen token's usefulness.
   */
  @Public()
  @Post('token/refresh')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  refresh(@Body() input: RefreshTokenDto): Promise<AuthenticationResponse> {
    return this.lifecycle.refresh(input.refreshToken);
  }

  /**
   * Logout is cheap but unauthenticated, and an attacker can pair it with a
   * guessed token hash to burn connection-pool time. 60/min matches what a real
   * client needs and costs an attacker little.
   */
  @Public()
  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  logout(@Body() input: RefreshTokenDto): Promise<void> {
    return this.lifecycle.logout(input.refreshToken, false);
  }

  /**
   * Revokes every session for the account, so one call can invalidate a token
   * family that took many refreshes to build. Held to 10/min: no real user logs
   * out of all devices more than once every few seconds, and the limit still
   * allows an account-wide revocation during a suspected compromise.
   */
  @Public()
  @Post('logout-all')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  logoutAll(@Body() input: RefreshTokenDto): Promise<void> {
    return this.lifecycle.logout(input.refreshToken, true);
  }
}
