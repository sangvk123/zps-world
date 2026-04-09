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

  it('login returns error shape for wrong password', async () => {
    const result = await controller.login({ domain: 'sangvk', password: 'wrong' });
    expect(result).toHaveProperty('error');
  });

  it('login returns token for valid credentials', async () => {
    const result = await controller.login({ domain: 'sangvk', password: 'zps2024' });
    expect(result).toHaveProperty('access_token');
  });

  it('getMe returns the employee from request.user', () => {
    const fakeEmployee = { id: 'sangvk', name: 'SangVK', department: 'Design' };
    const result = controller.getMe({ user: fakeEmployee } as any);
    expect(result).toEqual(fakeEmployee);
  });
});
