export class EmployeeDto {
  id: string;
  name: string;
  department: string;
  title: string;
  is_online: boolean;
  current_task: string;
  avatar: Record<string, unknown>;
}
