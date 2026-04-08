import { IsDateString, IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export enum TaskStatusDto {
  TODO = 'todo',
  IN_PROGRESS = 'in-progress',
  DONE = 'done',
}

export class CreateTaskDto {
  @IsString()
  @IsNotEmpty()
  title: string;

  @IsString()
  @IsNotEmpty()
  assignee_id: string;

  @IsDateString()
  due_date: string;
}

export class UpdateTaskDto {
  @IsEnum(TaskStatusDto)
  @IsOptional()
  status?: TaskStatusDto;
}
