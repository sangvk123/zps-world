import { Test } from '@nestjs/testing';
import { JwtModule } from '@nestjs/jwt';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let service: AuthService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      imports: [JwtModule.register({ secret: 'test-secret', signOptions: { expiresIn: '1h' } })],
      providers: [AuthService],
    }).compile();
    service = module.get<AuthService>(AuthService);
  });

  it('returns null for unknown employee_id', async () => {
    const result = await service.login('unknown_id', 'zps-dev-secret');
    expect(result).toBeNull();
  });

  it('returns null for wrong secret', async () => {
    const result = await service.login('hieupt', 'wrong-secret');
    expect(result).toBeNull();
  });

  it('returns access_token and employee for valid credentials', async () => {
    const result = await service.login('hieupt', 'zps-dev-secret');
    expect(result).not.toBeNull();
    expect(result!.access_token).toBeDefined();
    expect(result!.employee.id).toBe('hieupt');
    expect(result!.employee.name).toBe('Hiếu PT');
    expect(result!.employee.department).toBe('Product');
  });

  it('returns access_token for emp_001 with valid secret', async () => {
    const result = await service.login('emp_001', 'zps-dev-secret');
    expect(result).not.toBeNull();
    expect(result!.access_token).toBeDefined();
    expect(result!.employee.id).toBe('emp_001');
  });
});
