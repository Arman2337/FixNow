import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  AuthenticationResponse,
  EmailPasswordDto,
  PasswordResetConfirmDto,
  PasswordResetRequestDto,
} from './auth.dto';
import { AuthService } from './auth.service';
import { Public } from '../common/authorization/authorization.decorators';

@Controller('auth/customer')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('register')
  @Throttle({ default: { limit: 3, ttl: 60_000 } })
  register(@Body() input: EmailPasswordDto): Promise<AuthenticationResponse> {
    return this.authService.registerCustomer(input);
  }

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  login(@Body() input: EmailPasswordDto): Promise<AuthenticationResponse> {
    return this.authService.login(input);
  }

  /**
   * Starts a password reset.
   *
   * Always answers 202 with the same body, whether or not the address has an
   * account. Returning a different status for an unknown address would turn
   * this into a user-enumeration oracle, which is the whole reason the
   * per-account lockout is needed in the first place.
   *
   * Tightly throttled because it sends mail: without this, a caller could use
   * the endpoint to spam a third party's inbox.
   */
  @Public()
  @Post('password-reset/request')
  @HttpCode(HttpStatus.ACCEPTED)
  @Throttle({ default: { limit: 3, ttl: 60_000 } })
  async requestPasswordReset(
    @Body() input: PasswordResetRequestDto,
  ): Promise<{ status: 'accepted' }> {
    await this.authService.requestPasswordReset(input.email);
    return { status: 'accepted' };
  }

  /**
   * Redeems a reset token.
   *
   * Throttled like login, since a wrong guess here is a guess at a 256-bit
   * token and the cost is the password hash.
   */
  @Public()
  @Post('password-reset/confirm')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  async confirmPasswordReset(
    @Body() input: PasswordResetConfirmDto,
  ): Promise<{ status: 'reset' }> {
    await this.authService.resetPassword(input.token, input.newPassword);
    return { status: 'reset' };
  }
}
