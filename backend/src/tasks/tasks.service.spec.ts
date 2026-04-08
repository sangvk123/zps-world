import { Test } from '@nestjs/testing';
import { TasksService, TaskStatus } from './tasks.service';

describe('TasksService', () => {
  let service: TasksService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [TasksService],
    }).compile();
    service = module.get<TasksService>(TasksService);
  });

  it('findByEmployee returns seeded tasks for hieupt', () => {
    const tasks = service.findByEmployee('hieupt');
    expect(tasks.length).toBeGreaterThan(0);
    tasks.forEach((t) => expect(t.assignee_id).toBe('hieupt'));
  });

  it('create adds a new task', () => {
    const before = service.findByEmployee('sangvk').length;
    service.create({ title: 'Test task', assignee_id: 'sangvk', due_date: '2026-05-01' });
    expect(service.findByEmployee('sangvk').length).toBe(before + 1);
  });

  it('create sets default status todo', () => {
    const task = service.create({ title: 'New', assignee_id: 'emp_001', due_date: '2026-05-01' });
    expect(task.status).toBe(TaskStatus.TODO);
  });

  it('updateStatus changes task status', () => {
    const task = service.create({ title: 'ToUpdate', assignee_id: 'sangvk', due_date: '2026-05-01' });
    const updated = service.updateStatus(task.id, TaskStatus.IN_PROGRESS);
    expect(updated).toBeDefined();
    expect(updated!.status).toBe(TaskStatus.IN_PROGRESS);
  });

  it('updateStatus returns null for unknown task', () => {
    expect(service.updateStatus('nonexistent-id', TaskStatus.DONE)).toBeNull();
  });
});
