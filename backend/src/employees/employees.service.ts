import { Injectable } from '@nestjs/common';
import { AuthService, EmployeeProfile } from '../auth/auth.service';

@Injectable()
export class EmployeesService {
  constructor(private readonly authService: AuthService) {}

  findAll(): EmployeeProfile[] {
    return this.authService.getEmployees();
  }

  findOne(id: string): EmployeeProfile | undefined {
    return this.authService.getEmployee(id);
  }
}
