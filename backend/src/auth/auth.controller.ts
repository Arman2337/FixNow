import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthenticationResponse, EmailPasswordDto } from './auth.dto';
import { AuthService } from './auth.service';

@Controller('auth/customer')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @Throttle({ default: { limit: 3, ttl: 60_000 } })
  register(@Body() input: EmailPasswordDto): Promise<AuthenticationResponse> {
    return this.authService.register(input);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  login(@Body() input: EmailPasswordDto): Promise<AuthenticationResponse> {
    return this.authService.login(input);
  }
}
