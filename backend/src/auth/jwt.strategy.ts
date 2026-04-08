import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { AuthService } from './auth.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly authService: AuthService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env['JWT_SECRET'] ?? 'zps-world-jwt-secret',
    });
  }

  async validate(payload: { sub: string }): Promise<ReturnType<AuthService['getEmployee']>> {
    const employee = await this.authService.validateJwt(payload);
    if (!employee) throw new UnauthorizedException();
    return employee;
  }
}
