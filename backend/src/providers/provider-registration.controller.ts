import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthenticationResponse, EmailPasswordDto } from '../auth/auth.dto';
import { AuthService } from '../auth/auth.service';
import { Public } from '../common/authorization/authorization.decorators';

@Controller('auth/provider')
export class ProviderRegistrationController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('register')
  @Throttle({ default: { limit: 3, ttl: 60_000 } })
  register(@Body() input: EmailPasswordDto): Promise<AuthenticationResponse> {
    return this.authService.registerProvider(input);
  }

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  login(@Body() input: EmailPasswordDto): Promise<AuthenticationResponse> {
    return this.authService.login(input);
  }
}
