import { Injectable } from '@nestjs/common';
import { CreateTaskDto } from './dto/task.dto';

export enum TaskStatus {
  TODO = 'todo',
  IN_PROGRESS = 'in-progress',
  DONE = 'done',
}

export interface Task {
  id: string;
  title: string;
  assignee_id: string;
  due_date: string;
  status: TaskStatus;
  created_at: string;
}

const SEED_TASKS: Task[] = [
  { id: 'task_001', title: 'Reviewing Q2 roadmap', assignee_id: 'hieupt', due_date: '2026-04-15', status: TaskStatus.IN_PROGRESS, created_at: '2026-04-01T08:00:00Z' },
  { id: 'task_002', title: 'Write PRD for Quest Engine', assignee_id: 'hieupt', due_date: '2026-04-20', status: TaskStatus.TODO, created_at: '2026-04-02T09:00:00Z' },
  { id: 'task_003', title: 'Designing ZPS World prototype', assignee_id: 'sangvk', due_date: '2026-04-08', status: TaskStatus.IN_PROGRESS, created_at: '2026-03-28T10:00:00Z' },
  { id: 'task_004', title: 'Create avatar asset pack', assignee_id: 'sangvk', due_date: '2026-04-22', status: TaskStatus.TODO, created_at: '2026-04-03T11:00:00Z' },
  { id: 'task_005', title: 'Analyzing Q1 Data Audit', assignee_id: 'emp_001', due_date: '2026-04-05', status: TaskStatus.DONE, created_at: '2026-03-20T08:00:00Z' },
];

@Injectable()
export class TasksService {
  private readonly tasks: Task[] = [...SEED_TASKS];

  findByEmployee(employeeId: string): Task[] {
    return this.tasks.filter((t) => t.assignee_id === employeeId);
  }

  create(dto: CreateTaskDto): Task {
    const task: Task = {
      id: `task_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      title: dto.title,
      assignee_id: dto.assignee_id,
      due_date: dto.due_date,
      status: TaskStatus.TODO,
      created_at: new Date().toISOString(),
    };
    this.tasks.push(task);
    return task;
  }

  updateStatus(id: string, status: TaskStatus): Task | null {
    const task = this.tasks.find((t) => t.id === id);
    if (!task) return null;
    task.status = status;
    return task;
  }
}
