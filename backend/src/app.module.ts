import { Module } from '@nestjs/common';
import { AuthModule } from './auth/auth.module';
import { EmployeesModule } from './employees/employees.module';
import { RoomsModule } from './rooms/rooms.module';
import { TasksModule } from './tasks/tasks.module';
import { AchievementsModule } from './achievements/achievements.module';

@Module({
  imports: [AuthModule, EmployeesModule, RoomsModule, TasksModule, AchievementsModule],
})
export class AppModule {}
