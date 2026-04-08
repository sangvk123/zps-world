import { Test } from '@nestjs/testing';
import { JwtModule } from '@nestjs/jwt';
import { EmployeesService } from './employees.service';
import { AuthModule } from '../auth/auth.module';

describe('EmployeesService', () => {
  let service: EmployeesService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      imports: [
        AuthModule,
        JwtModule.register({ secret: 'test-secret', signOptions: { expiresIn: '1h' } }),
      ],
      providers: [EmployeesService],
    }).compile();
    service = module.get<EmployeesService>(EmployeesService);
  });

  it('findAll returns more than 0 employees', () => {
    const all = service.findAll();
    expect(all.length).toBeGreaterThan(0);
  });

  it('findOne returns hieupt', () => {
    const emp = service.findOne('hieupt');
    expect(emp).toBeDefined();
    expect(emp!.name).toBe('Hiếu PT');
  });

  it('findOne returns undefined for unknown id', () => {
    expect(service.findOne('nobody')).toBeUndefined();
  });

  it('findAll results have required fields', () => {
    const all = service.findAll();
    const first = all[0];
    expect(first).toHaveProperty('id');
    expect(first).toHaveProperty('name');
    expect(first).toHaveProperty('department');
    expect(first).toHaveProperty('is_online');
  });
});
