import { Body, Controller, Get, HttpCode, Post, Request, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthService, EmployeeProfile } from './auth.service';
import { LoginDto } from './dto/login.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @HttpCode(200)
  async login(
    @Body() dto: LoginDto,
  ): Promise<{ access_token: string; employee: EmployeeProfile } | { error: string }> {
    const result = await this.authService.login(dto.domain, dto.password);
    if (!result) return { error: 'Domain hoặc mật khẩu không đúng' };
    return result;
  }

  @Get('me')
  @UseGuards(AuthGuard('jwt'))
  getMe(@Request() req: { user: EmployeeProfile }): EmployeeProfile {
    return req.user;
  }
}
