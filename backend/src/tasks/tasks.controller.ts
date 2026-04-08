import {
  Body, Controller, Get, NotFoundException, Param,
  Patch, Post, Request, UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { EmployeeProfile } from '../auth/auth.service';
import { CreateTaskDto, UpdateTaskDto } from './dto/task.dto';
import { Task, TaskStatus, TasksService } from './tasks.service';

@Controller('tasks')
@UseGuards(AuthGuard('jwt'))
export class TasksController {
  constructor(private readonly tasksService: TasksService) {}

  @Get()
  findMine(@Request() req: { user: EmployeeProfile }): Task[] {
    return this.tasksService.findByEmployee(req.user.id);
  }

  @Post()
  create(@Body() dto: CreateTaskDto): Task {
    return this.tasksService.create(dto);
  }

  @Patch(':id')
  updateStatus(@Param('id') id: string, @Body() dto: UpdateTaskDto): Task {
    const updated = this.tasksService.updateStatus(id, dto.status as unknown as TaskStatus);
    if (!updated) throw new NotFoundException(`Task ${id} not found`);
    return updated;
  }
}
