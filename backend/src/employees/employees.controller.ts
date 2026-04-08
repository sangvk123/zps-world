import { Controller, Get, NotFoundException, Param, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { EmployeeProfile } from '../auth/auth.service';
import { EmployeesService } from './employees.service';

@Controller('employees')
@UseGuards(AuthGuard('jwt'))
export class EmployeesController {
  constructor(private readonly employeesService: EmployeesService) {}

  @Get()
  findAll(): EmployeeProfile[] {
    return this.employeesService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string): EmployeeProfile {
    const emp = this.employeesService.findOne(id);
    if (!emp) throw new NotFoundException(`Employee ${id} not found`);
    return emp;
  }
}
