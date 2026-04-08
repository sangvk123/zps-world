import { Test } from '@nestjs/testing';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';

describe('AuthController', () => {
  let controller: AuthController;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      imports: [
        PassportModule,
        JwtModule.register({ secret: 'test-secret', signOptions: { expiresIn: '1h' } }),
      ],
      controllers: [AuthController],
      providers: [AuthService, JwtStrategy],
    }).compile();
    controller = module.get<AuthController>(AuthController);
  });

  it('login returns error shape for wrong secret', async () => {
    const result = await controller.login({ employee_id: 'hieupt', secret: 'bad' });
    expect(result).toEqual({ error: 'Invalid credentials' });
  });

  it('login returns token and employee for valid credentials', async () => {
    const result = await controller.login({ employee_id: 'hieupt', secret: 'zps-dev-secret' });
    expect(result).toHaveProperty('access_token');
    expect((result as { employee: { id: string } }).employee.id).toBe('hieupt');
  });

  it('getMe returns the employee from request.user', () => {
    const fakeEmployee = { id: 'hieupt', name: 'Hiếu PT', department: 'Product' };
    const result = controller.getMe({ user: fakeEmployee } as any);
    expect(result).toEqual(fakeEmployee);
  });
});
