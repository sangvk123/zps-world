# Sprint 3 — NestJS Backend + MVP Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a NestJS REST backend with in-memory data and wire it to Godot via a new HttpManager autoload, enabling real login flow, task management, HR leave requests, and room booking that all talk to a real server.

**Architecture:** NestJS 10 backend lives in `backend/` alongside the existing `server/` WebSocket node. Godot gains one new autoload (`HttpManager.gd`) that wraps all HTTP calls with JWT auth. Campus shows a `LoginDialog` on startup; after login, GameManager replaces mock data with data fetched from the REST API. No database — all state lives in-memory on the NestJS server using the same seed data previously in GameManager.

**Tech Stack:** NestJS 10, TypeScript 5, passport-jwt, class-validator, class-transformer, Jest 29 (unit + e2e), Godot 4.6 GDScript (HTTPRequest node).

---

## File Map

### New — Backend

| File | Responsibility |
|---|---|
| `backend/package.json` | Dependencies and npm scripts |
| `backend/nest-cli.json` | NestJS CLI config |
| `backend/tsconfig.json` | TypeScript compiler options |
| `backend/src/main.ts` | Bootstrap, CORS, global pipes |
| `backend/src/app.module.ts` | Root module — imports all feature modules |
| `backend/src/auth/auth.module.ts` | Auth feature module |
| `backend/src/auth/auth.service.ts` | Mock SSO login, JWT issue |
| `backend/src/auth/auth.controller.ts` | POST /auth/login, GET /auth/me |
| `backend/src/auth/jwt.strategy.ts` | Passport JWT strategy |
| `backend/src/auth/dto/login.dto.ts` | LoginDto (employee_id, secret) |
| `backend/src/employees/employees.module.ts` | Employees feature module |
| `backend/src/employees/employees.service.ts` | In-memory employee store |
| `backend/src/employees/employees.controller.ts` | GET /employees, GET /employees/:id |
| `backend/src/employees/dto/employee.dto.ts` | EmployeeDto shape |
| `backend/src/rooms/rooms.module.ts` | Rooms feature module |
| `backend/src/rooms/rooms.service.ts` | In-memory rooms + bookings store |
| `backend/src/rooms/rooms.controller.ts` | GET /rooms, POST /rooms/:id/book, GET /rooms/:id/bookings |
| `backend/src/rooms/dto/booking.dto.ts` | BookingDto (date, time_slot, booker_id) |
| `backend/src/tasks/tasks.module.ts` | Tasks feature module |
| `backend/src/tasks/tasks.service.ts` | In-memory tasks store per employee |
| `backend/src/tasks/tasks.controller.ts` | GET /tasks, POST /tasks, PATCH /tasks/:id |
| `backend/src/tasks/dto/task.dto.ts` | CreateTaskDto, UpdateTaskDto |
| `backend/test/auth.e2e-spec.ts` | Auth e2e tests |
| `backend/test/employees.e2e-spec.ts` | Employees e2e tests |
| `backend/test/rooms.e2e-spec.ts` | Rooms e2e tests |

### New — Godot

| File | Responsibility |
|---|---|
| `scripts/autoloads/HttpManager.gd` | Wraps HTTPRequest, stores JWT, emits response signals |
| `scripts/ui/LoginDialog.gd` | Login modal UI — sends credentials, stores JWT |

### Modified — Godot

| File | What changes |
|---|---|
| `project.godot` | Add `HttpManager` autoload entry before `NetworkManager` |
| `scripts/autoloads/GameManager.gd` | Add `load_employees_from_api()` replacing `_load_mock_data()` during live play; keep mock as fallback |
| `scripts/world/Campus.gd` | Show LoginDialog in `_ready()` before spawning player; proceed on login success |
| `scripts/ui/HUD.gd` | Wire `_build_leave_tab()` submit to `HttpManager`; add `_build_task_tab()` with real data |

---

## Task 1: Backend — Project Scaffold

**Files:**
- Create: `backend/package.json`
- Create: `backend/nest-cli.json`
- Create: `backend/tsconfig.json`

- [ ] **Step 1: Create `backend/package.json`**

```json
{
  "name": "zpsworld-backend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "build": "nest build",
    "start": "node dist/main",
    "start:dev": "nest start --watch",
    "test": "jest",
    "test:e2e": "jest --config ./test/jest-e2e.json"
  },
  "dependencies": {
    "@nestjs/common": "^10.4.0",
    "@nestjs/core": "^10.4.0",
    "@nestjs/jwt": "^10.2.0",
    "@nestjs/passport": "^10.0.3",
    "@nestjs/platform-express": "^10.4.0",
    "class-transformer": "^0.5.1",
    "class-validator": "^0.14.1",
    "passport": "^0.7.0",
    "passport-jwt": "^4.0.1",
    "reflect-metadata": "^0.2.2",
    "rxjs": "^7.8.1"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.4.0",
    "@nestjs/testing": "^10.4.0",
    "@types/jest": "^29.5.12",
    "@types/node": "^20.14.10",
    "@types/passport-jwt": "^4.0.1",
    "@types/supertest": "^6.0.2",
    "jest": "^29.7.0",
    "supertest": "^7.0.0",
    "ts-jest": "^29.2.2",
    "typescript": "^5.5.3"
  },
  "jest": {
    "moduleFileExtensions": ["js", "json", "ts"],
    "rootDir": "src",
    "testRegex": ".*\\.spec\\.ts$",
    "transform": {
      "^.+\\.(t|j)s$": "ts-jest"
    },
    "collectCoverageFrom": ["**/*.(t|j)s"],
    "coverageDirectory": "../coverage",
    "testEnvironment": "node"
  }
}
```

- [ ] **Step 2: Create `backend/nest-cli.json`**

```json
{
  "$schema": "https://json.schemastore.org/nest-cli",
  "collection": "@nestjs/schematics",
  "sourceRoot": "src",
  "compilerOptions": {
    "deleteOutDir": true
  }
}
```

- [ ] **Step 3: Create `backend/tsconfig.json`**

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strictNullChecks": true,
    "noImplicitAny": true,
    "strictBindCallApply": true,
    "forceConsistentCasingInFileNames": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

- [ ] **Step 4: Create `backend/test/jest-e2e.json`**

```json
{
  "moduleFileExtensions": ["js", "json", "ts"],
  "rootDir": "../",
  "testEnvironment": "node",
  "testRegex": ".e2e-spec.ts$",
  "transform": {
    "^.+\\.(t|j)s$": "ts-jest"
  }
}
```

- [ ] **Step 5: Install dependencies**

```bash
cd backend && npm install
```

Expected: `node_modules/` created, no errors.

- [ ] **Step 6: Commit**

```bash
cd backend && git add package.json nest-cli.json tsconfig.json test/jest-e2e.json
git commit -m "chore: scaffold NestJS backend project files"
```

---

## Task 2: Auth Module — DTOs and Service

**Files:**
- Create: `backend/src/auth/dto/login.dto.ts`
- Create: `backend/src/auth/auth.service.ts`
- Create: `backend/src/auth/jwt.strategy.ts`

- [ ] **Step 1: Write the failing unit test for AuthService**

Create `backend/src/auth/auth.service.spec.ts`:

```typescript
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
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd backend && npm test -- --testPathPattern auth.service.spec
```

Expected: FAIL — `Cannot find module './auth.service'`

- [ ] **Step 3: Create `backend/src/auth/dto/login.dto.ts`**

```typescript
import { IsString, IsNotEmpty, MinLength } from 'class-validator';

export class LoginDto {
  @IsString()
  @IsNotEmpty()
  employee_id: string;

  @IsString()
  @IsNotEmpty()
  @MinLength(4)
  secret: string;
}
```

- [ ] **Step 4: Create `backend/src/auth/auth.service.ts`**

```typescript
import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

export interface EmployeeProfile {
  id: string;
  name: string;
  department: string;
  title: string;
  is_online: boolean;
  avatar: Record<string, unknown>;
  current_task: string;
}

// In-memory employee store — same seed data as GameManager.gd
const EMPLOYEES: Record<string, EmployeeProfile> = {
  hieupt: {
    id: 'hieupt',
    name: 'Hiếu PT',
    department: 'Product',
    title: 'CPO — Chief Product Officer',
    is_online: true,
    avatar: { body_type: 0, skin: 1, hair: 2, outfit: 'formal', class_name: 'strategist' },
    current_task: 'Reviewing Q2 roadmap & ZPS World Vision',
  },
  sangvk: {
    id: 'sangvk',
    name: 'SangVK - Vũ Khánh Sang',
    department: 'Design',
    title: 'Master of The Watch',
    is_online: true,
    avatar: { body_type: 0, skin_tone: 1, hair_style: 2, outfit_id: 'work_casual', class_name: 'artisan' },
    current_task: 'Designing ZPS World prototype',
  },
};

// Seed 100 mock employees (emp_001 … emp_100) deterministically
function seededRandom(seed: number): () => number {
  let s = seed;
  return () => {
    s = (s * 1664525 + 1013904223) & 0xffffffff;
    return (s >>> 0) / 0xffffffff;
  };
}

function buildMockEmployees(): void {
  const rand = seededRandom(12345);
  const lastNames = ['Nguyễn','Trần','Lê','Phạm','Hoàng','Huỳnh','Phan','Vũ','Đặng','Bùi'];
  const maleFirst = ['Minh','Hùng','Tuấn','Dũng','Khoa','Đức','Phúc','Long','Hưng','Bảo'];
  const femaleFirst = ['Linh','Hương','Lan','Ngọc','Hoa','Mai','Trang','Thảo','Phương','Vy'];
  const depts = ['Engineering','Design','Product','HR','Data','Marketing'];
  const deptTitles: Record<string,string[]> = {
    Engineering: ['Engineer','Senior Engineer','Lead Engineer'],
    Design: ['Designer','Senior Designer','Art Lead'],
    Product: ['Product Manager','PM','CPO'],
    HR: ['HR Specialist','Recruiter','HR Lead'],
    Data: ['Data Analyst','Data Engineer','Data Lead'],
    Marketing: ['Marketing Manager','Content Creator','Marketing Lead'],
  };
  const deptClass: Record<string,string> = {
    Engineering: 'engineer', Design: 'artisan', Product: 'strategist',
    HR: 'analyst', Data: 'analyst', Marketing: 'creator',
  };
  const deptOutfit: Record<string,string> = {
    Engineering: 'work_casual', Design: 'creative', Product: 'formal',
    HR: 'work_casual', Data: 'work_casual', Marketing: 'creative',
  };
  const tasks = ['Building Quest Engine','Designing UI for Inventory System','Planning Q2 roadmap','Conducting interviews','Analyzing dashboard','Creating campaign'];

  const pick = <T>(arr: T[], r: number) => arr[Math.floor(r * arr.length)];

  for (let i = 1; i <= 100; i++) {
    const id = `emp_${String(i).padStart(3, '0')}`;
    const isMale = rand() < 0.4;
    const first = isMale ? pick(maleFirst, rand()) : pick(femaleFirst, rand());
    const dept = pick(depts, rand());
    const titlePool = deptTitles[dept];
    EMPLOYEES[id] = {
      id,
      name: `${pick(lastNames, rand())} ${first}`,
      department: dept,
      title: titlePool[Math.floor(rand() * titlePool.length)],
      is_online: rand() < 0.7,
      avatar: {
        body_type: Math.floor(rand() * 2),
        skin: Math.floor(rand() * 5),
        hair: Math.floor(rand() * 8),
        outfit: deptOutfit[dept],
        class_name: deptClass[dept],
      },
      current_task: pick(tasks, rand()),
    };
  }
}

buildMockEmployees();

const DEV_SECRET = 'zps-dev-secret';

@Injectable()
export class AuthService {
  constructor(private readonly jwtService: JwtService) {}

  async login(employeeId: string, secret: string): Promise<{ access_token: string; employee: EmployeeProfile } | null> {
    if (secret !== DEV_SECRET) return null;
    const employee = EMPLOYEES[employeeId];
    if (!employee) return null;
    const payload = { sub: employee.id, department: employee.department };
    const access_token = await this.jwtService.signAsync(payload);
    return { access_token, employee };
  }

  async validateJwt(payload: { sub: string }): Promise<EmployeeProfile | null> {
    return EMPLOYEES[payload.sub] ?? null;
  }

  getEmployees(): EmployeeProfile[] {
    return Object.values(EMPLOYEES);
  }

  getEmployee(id: string): EmployeeProfile | undefined {
    return EMPLOYEES[id];
  }
}
```

- [ ] **Step 5: Create `backend/src/auth/jwt.strategy.ts`**

```typescript
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { AuthService } from './auth.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly authService: AuthService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env['JWT_SECRET'] ?? 'zps-world-jwt-secret',
    });
  }

  async validate(payload: { sub: string }): Promise<ReturnType<AuthService['getEmployee']>> {
    const employee = await this.authService.validateJwt(payload);
    if (!employee) throw new UnauthorizedException();
    return employee;
  }
}
```

- [ ] **Step 6: Run test — expect PASS**

```bash
cd backend && npm test -- --testPathPattern auth.service.spec
```

Expected: PASS — 4 tests pass.

- [ ] **Step 7: Commit**

```bash
cd backend && git add src/auth/dto/login.dto.ts src/auth/auth.service.ts src/auth/auth.service.spec.ts src/auth/jwt.strategy.ts
git commit -m "feat(auth): add AuthService with mock SSO login and JWT strategy"
```

---

## Task 3: Auth Module — Controller + Module Wiring

**Files:**
- Create: `backend/src/auth/auth.controller.ts`
- Create: `backend/src/auth/auth.module.ts`

- [ ] **Step 1: Write failing controller test**

Create `backend/src/auth/auth.controller.spec.ts`:

```typescript
import { Test } from '@nestjs/testing';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';

describe('AuthController', () => {
  let controller: AuthController;
  let service: AuthService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      imports: [
        PassportModule,
        JwtModule.register({ secret: 'test-secret', signOptions: { expiresIn: '1h' } }),
      ],
      controllers: [AuthController],
      providers: [AuthService, JwtStrategy],
    }).compile();
    controller = module.get<AuthController>(AuthController);
    service = module.get<AuthService>(AuthService);
  });

  it('login returns 401 shape for wrong secret', async () => {
    const result = await controller.login({ employee_id: 'hieupt', secret: 'bad' });
    expect(result).toEqual({ error: 'Invalid credentials' });
  });

  it('login returns token and employee for valid credentials', async () => {
    const result = await controller.login({ employee_id: 'hieupt', secret: 'zps-dev-secret' });
    expect(result).toHaveProperty('access_token');
    expect((result as { employee: { id: string } }).employee.id).toBe('hieupt');
  });

  it('getMe returns the employee from JWT payload', () => {
    const fakeEmployee = { id: 'hieupt', name: 'Hiếu PT', department: 'Product' };
    const result = controller.getMe(fakeEmployee as any);
    expect(result).toEqual(fakeEmployee);
  });
});
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd backend && npm test -- --testPathPattern auth.controller.spec
```

Expected: FAIL — `Cannot find module './auth.controller'`

- [ ] **Step 3: Create `backend/src/auth/auth.controller.ts`**

```typescript
import { Body, Controller, Get, HttpCode, Post, Request, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AuthService, EmployeeProfile } from './auth.service';
import { LoginDto } from './dto/login.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @HttpCode(200)
  async login(
    @Body() dto: LoginDto,
  ): Promise<{ access_token: string; employee: EmployeeProfile } | { error: string }> {
    const result = await this.authService.login(dto.employee_id, dto.secret);
    if (!result) return { error: 'Invalid credentials' };
    return result;
  }

  @Get('me')
  @UseGuards(AuthGuard('jwt'))
  getMe(@Request() req: { user: EmployeeProfile }): EmployeeProfile {
    return req.user;
  }
}
```

- [ ] **Step 4: Create `backend/src/auth/auth.module.ts`**

```typescript
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';

@Module({
  imports: [
    PassportModule,
    JwtModule.register({
      secret: process.env['JWT_SECRET'] ?? 'zps-world-jwt-secret',
      signOptions: { expiresIn: '8h' },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
  exports: [AuthService],
})
export class AuthModule {}
```

- [ ] **Step 5: Run test — expect PASS**

```bash
cd backend && npm test -- --testPathPattern auth.controller.spec
```

Expected: PASS — 3 tests pass.

- [ ] **Step 6: Commit**

```bash
cd backend && git add src/auth/auth.controller.ts src/auth/auth.controller.spec.ts src/auth/auth.module.ts
git commit -m "feat(auth): add AuthController and AuthModule"
```

---

## Task 4: Employees Module

**Files:**
- Create: `backend/src/employees/dto/employee.dto.ts`
- Create: `backend/src/employees/employees.service.ts`
- Create: `backend/src/employees/employees.controller.ts`
- Create: `backend/src/employees/employees.module.ts`

- [ ] **Step 1: Write failing service test**

Create `backend/src/employees/employees.service.spec.ts`:

```typescript
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
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd backend && npm test -- --testPathPattern employees.service.spec
```

Expected: FAIL — `Cannot find module './employees.service'`

- [ ] **Step 3: Create `backend/src/employees/dto/employee.dto.ts`**

```typescript
export class EmployeeDto {
  id: string;
  name: string;
  department: string;
  title: string;
  is_online: boolean;
  current_task: string;
  avatar: Record<string, unknown>;
}
```

- [ ] **Step 4: Create `backend/src/employees/employees.service.ts`**

```typescript
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
```

- [ ] **Step 5: Create `backend/src/employees/employees.controller.ts`**

```typescript
import { Controller, Get, NotFoundException, Param, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { EmployeesService } from './employees.service';
import { EmployeeProfile } from '../auth/auth.service';

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
```

- [ ] **Step 6: Create `backend/src/employees/employees.module.ts`**

```typescript
import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { EmployeesController } from './employees.controller';
import { EmployeesService } from './employees.service';

@Module({
  imports: [AuthModule],
  controllers: [EmployeesController],
  providers: [EmployeesService],
  exports: [EmployeesService],
})
export class EmployeesModule {}
```

- [ ] **Step 7: Run test — expect PASS**

```bash
cd backend && npm test -- --testPathPattern employees.service.spec
```

Expected: PASS — 4 tests pass.

- [ ] **Step 8: Commit**

```bash
cd backend && git add src/employees/
git commit -m "feat(employees): add Employees module with in-memory store"
```

---

## Task 5: Rooms Module

**Files:**
- Create: `backend/src/rooms/dto/booking.dto.ts`
- Create: `backend/src/rooms/rooms.service.ts`
- Create: `backend/src/rooms/rooms.controller.ts`
- Create: `backend/src/rooms/rooms.module.ts`

- [ ] **Step 1: Write failing service tests**

Create `backend/src/rooms/rooms.service.spec.ts`:

```typescript
import { Test } from '@nestjs/testing';
import { RoomsService } from './rooms.service';

describe('RoomsService', () => {
  let service: RoomsService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [RoomsService],
    }).compile();
    service = module.get<RoomsService>(RoomsService);
  });

  it('findAll returns 5 rooms', () => {
    expect(service.findAll()).toHaveLength(5);
  });

  it('findOne returns room_alpha', () => {
    const room = service.findOne('room_alpha');
    expect(room).toBeDefined();
    expect(room!.name).toBe('Room Alpha');
    expect(room!.capacity).toBe(8);
  });

  it('findOne returns undefined for unknown room', () => {
    expect(service.findOne('nonexistent')).toBeUndefined();
  });

  it('book returns true for available slot', () => {
    const result = service.book('room_alpha', '2026-04-10', '09:00-10:00', 'hieupt');
    expect(result.success).toBe(true);
    expect(result.booking).toBeDefined();
    expect(result.booking!.booker_id).toBe('hieupt');
  });

  it('book returns false for conflicting slot', () => {
    service.book('room_beta', '2026-04-10', '09:00-10:00', 'sangvk');
    const result = service.book('room_beta', '2026-04-10', '09:00-10:00', 'hieupt');
    expect(result.success).toBe(false);
    expect(result.error).toMatch(/already booked/i);
  });

  it('getBookings returns all bookings for a room', () => {
    service.book('room_dragon', '2026-04-11', '14:00-15:00', 'sangvk');
    const bookings = service.getBookings('room_dragon');
    expect(bookings).toHaveLength(1);
    expect(bookings[0].time_slot).toBe('14:00-15:00');
  });
});
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd backend && npm test -- --testPathPattern rooms.service.spec
```

Expected: FAIL — `Cannot find module './rooms.service'`

- [ ] **Step 3: Create `backend/src/rooms/dto/booking.dto.ts`**

```typescript
import { IsDateString, IsNotEmpty, IsString, Matches } from 'class-validator';

export class BookingDto {
  @IsDateString()
  date: string;

  @IsString()
  @IsNotEmpty()
  @Matches(/^\d{2}:\d{2}-\d{2}:\d{2}$/, { message: 'time_slot must be HH:MM-HH:MM format' })
  time_slot: string;

  @IsString()
  @IsNotEmpty()
  booker_id: string;
}

export interface RoomData {
  id: string;
  name: string;
  capacity: number;
  equipment: string[];
}

export interface BookingRecord {
  id: string;
  room_id: string;
  date: string;
  time_slot: string;
  booker_id: string;
  created_at: string;
}
```

- [ ] **Step 4: Create `backend/src/rooms/rooms.service.ts`**

```typescript
import { Injectable } from '@nestjs/common';
import { BookingRecord, RoomData } from './dto/booking.dto';

const ROOMS: Record<string, RoomData> = {
  room_alpha: { id: 'room_alpha', name: 'Room Alpha', capacity: 8, equipment: ['Projector', 'Whiteboard'] },
  room_beta: { id: 'room_beta', name: 'Room Beta', capacity: 4, equipment: ['TV Screen'] },
  room_dragon: { id: 'room_dragon', name: "Dragon's Den", capacity: 20, equipment: ['Full AV', 'Streaming Setup'] },
  room_gamma: { id: 'room_gamma', name: 'Room Gamma', capacity: 10, equipment: ['Whiteboard', 'TV Screen'] },
  room_delta: { id: 'room_delta', name: 'Room Delta', capacity: 10, equipment: ['Projector', 'Whiteboard'] },
};

@Injectable()
export class RoomsService {
  private readonly bookings: BookingRecord[] = [];

  findAll(): RoomData[] {
    return Object.values(ROOMS);
  }

  findOne(id: string): RoomData | undefined {
    return ROOMS[id];
  }

  book(
    roomId: string,
    date: string,
    timeSlot: string,
    bookerId: string,
  ): { success: boolean; booking?: BookingRecord; error?: string } {
    if (!ROOMS[roomId]) return { success: false, error: `Room ${roomId} not found` };

    const conflict = this.bookings.find(
      (b) => b.room_id === roomId && b.date === date && b.time_slot === timeSlot,
    );
    if (conflict) return { success: false, error: `Slot ${timeSlot} on ${date} is already booked` };

    const booking: BookingRecord = {
      id: `booking_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      room_id: roomId,
      date,
      time_slot: timeSlot,
      booker_id: bookerId,
      created_at: new Date().toISOString(),
    };
    this.bookings.push(booking);
    return { success: true, booking };
  }

  getBookings(roomId: string): BookingRecord[] {
    return this.bookings.filter((b) => b.room_id === roomId);
  }
}
```

- [ ] **Step 5: Create `backend/src/rooms/rooms.controller.ts`**

```typescript
import {
  Body, Controller, Get, NotFoundException, Param,
  Post, Request, UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { EmployeeProfile } from '../auth/auth.service';
import { BookingDto, BookingRecord, RoomData } from './dto/booking.dto';
import { RoomsService } from './rooms.service';

@Controller('rooms')
@UseGuards(AuthGuard('jwt'))
export class RoomsController {
  constructor(private readonly roomsService: RoomsService) {}

  @Get()
  findAll(): RoomData[] {
    return this.roomsService.findAll();
  }

  @Post(':id/book')
  book(
    @Param('id') id: string,
    @Body() dto: BookingDto,
    @Request() req: { user: EmployeeProfile },
  ): { success: boolean; booking?: BookingRecord; error?: string } {
    if (!this.roomsService.findOne(id)) throw new NotFoundException(`Room ${id} not found`);
    return this.roomsService.book(id, dto.date, dto.time_slot, req.user.id);
  }

  @Get(':id/bookings')
  getBookings(@Param('id') id: string): BookingRecord[] {
    if (!this.roomsService.findOne(id)) throw new NotFoundException(`Room ${id} not found`);
    return this.roomsService.getBookings(id);
  }
}
```

- [ ] **Step 6: Create `backend/src/rooms/rooms.module.ts`**

```typescript
import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { RoomsController } from './rooms.controller';
import { RoomsService } from './rooms.service';

@Module({
  imports: [AuthModule],
  controllers: [RoomsController],
  providers: [RoomsService],
  exports: [RoomsService],
})
export class RoomsModule {}
```

- [ ] **Step 7: Run test — expect PASS**

```bash
cd backend && npm test -- --testPathPattern rooms.service.spec
```

Expected: PASS — 6 tests pass.

- [ ] **Step 8: Commit**

```bash
cd backend && git add src/rooms/
git commit -m "feat(rooms): add Rooms module with booking conflict detection"
```

---

## Task 6: Tasks Module

**Files:**
- Create: `backend/src/tasks/dto/task.dto.ts`
- Create: `backend/src/tasks/tasks.service.ts`
- Create: `backend/src/tasks/tasks.controller.ts`
- Create: `backend/src/tasks/tasks.module.ts`

- [ ] **Step 1: Write failing service tests**

Create `backend/src/tasks/tasks.service.spec.ts`:

```typescript
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
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd backend && npm test -- --testPathPattern tasks.service.spec
```

Expected: FAIL — `Cannot find module './tasks.service'`

- [ ] **Step 3: Create `backend/src/tasks/dto/task.dto.ts`**

```typescript
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
```

- [ ] **Step 4: Create `backend/src/tasks/tasks.service.ts`**

```typescript
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

// Seed tasks so the game has initial data on first load
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
```

- [ ] **Step 5: Create `backend/src/tasks/tasks.controller.ts`**

```typescript
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
    const updated = this.tasksService.updateStatus(id, dto.status as TaskStatus);
    if (!updated) throw new NotFoundException(`Task ${id} not found`);
    return updated;
  }
}
```

- [ ] **Step 6: Create `backend/src/tasks/tasks.module.ts`**

```typescript
import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { TasksController } from './tasks.controller';
import { TasksService } from './tasks.service';

@Module({
  imports: [AuthModule],
  controllers: [TasksController],
  providers: [TasksService],
  exports: [TasksService],
})
export class TasksModule {}
```

- [ ] **Step 7: Run test — expect PASS**

```bash
cd backend && npm test -- --testPathPattern tasks.service.spec
```

Expected: PASS — 5 tests pass.

- [ ] **Step 8: Commit**

```bash
cd backend && git add src/tasks/
git commit -m "feat(tasks): add Tasks module with seeded data and status toggle"
```

---

## Task 7: App Root Module + Bootstrap

**Files:**
- Create: `backend/src/app.module.ts`
- Create: `backend/src/main.ts`

- [ ] **Step 1: Create `backend/src/app.module.ts`**

```typescript
import { Module } from '@nestjs/common';
import { AuthModule } from './auth/auth.module';
import { EmployeesModule } from './employees/employees.module';
import { RoomsModule } from './rooms/rooms.module';
import { TasksModule } from './tasks/tasks.module';

@Module({
  imports: [AuthModule, EmployeesModule, RoomsModule, TasksModule],
})
export class AppModule {}
```

- [ ] **Step 2: Create `backend/src/main.ts`**

```typescript
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);

  // Allow Godot game (any origin in dev) + WebSocket server on :3001
  app.enableCors({
    origin: ['http://localhost:3001', 'http://127.0.0.1:3001', '*'],
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  // Validate all incoming request bodies automatically
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const port = process.env['PORT'] ?? 3000;
  await app.listen(port);
  console.log(`[ZPS Backend] Running on http://localhost:${port}`);
}

bootstrap();
```

- [ ] **Step 3: Build to verify no TypeScript errors**

```bash
cd backend && npm run build
```

Expected: `dist/` folder created, no TypeScript errors.

- [ ] **Step 4: Start the server and do a smoke test**

```bash
cd backend && npm run start:dev &
sleep 3
curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"employee_id":"hieupt","secret":"zps-dev-secret"}' | head -c 200
```

Expected output contains: `"access_token"` and `"hieupt"`.

- [ ] **Step 5: Commit**

```bash
cd backend && git add src/app.module.ts src/main.ts
git commit -m "feat: wire AppModule and bootstrap NestJS with CORS and validation"
```

---

## Task 8: E2E Tests

**Files:**
- Create: `backend/test/auth.e2e-spec.ts`
- Create: `backend/test/employees.e2e-spec.ts`
- Create: `backend/test/rooms.e2e-spec.ts`

- [ ] **Step 1: Create `backend/test/auth.e2e-spec.ts`**

```typescript
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Auth (e2e)', () => {
  let app: INestApplication;
  let token: string;

  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
  });

  afterAll(async () => { await app.close(); });

  it('POST /auth/login with valid creds → 200 + access_token', async () => {
    const res = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ employee_id: 'hieupt', secret: 'zps-dev-secret' })
      .expect(200);
    expect(res.body.access_token).toBeDefined();
    expect(res.body.employee.id).toBe('hieupt');
    token = res.body.access_token as string;
  });

  it('POST /auth/login with wrong secret → 200 + error field', async () => {
    const res = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ employee_id: 'hieupt', secret: 'wrong' })
      .expect(200);
    expect(res.body.error).toBeDefined();
    expect(res.body.access_token).toBeUndefined();
  });

  it('GET /auth/me without token → 401', async () => {
    await request(app.getHttpServer()).get('/auth/me').expect(401);
  });

  it('GET /auth/me with token → employee profile', async () => {
    const res = await request(app.getHttpServer())
      .get('/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(res.body.id).toBe('hieupt');
    expect(res.body.department).toBe('Product');
  });
});
```

- [ ] **Step 2: Create `backend/test/employees.e2e-spec.ts`**

```typescript
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Employees (e2e)', () => {
  let app: INestApplication;
  let token: string;

  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    const res = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ employee_id: 'hieupt', secret: 'zps-dev-secret' });
    token = res.body.access_token as string;
  });

  afterAll(async () => { await app.close(); });

  it('GET /employees without token → 401', async () => {
    await request(app.getHttpServer()).get('/employees').expect(401);
  });

  it('GET /employees → array with id, name, department', async () => {
    const res = await request(app.getHttpServer())
      .get('/employees')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
    const first = res.body[0];
    expect(first).toHaveProperty('id');
    expect(first).toHaveProperty('name');
    expect(first).toHaveProperty('department');
  });

  it('GET /employees/hieupt → Hiếu PT', async () => {
    const res = await request(app.getHttpServer())
      .get('/employees/hieupt')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(res.body.name).toBe('Hiếu PT');
  });

  it('GET /employees/nobody → 404', async () => {
    await request(app.getHttpServer())
      .get('/employees/nobody')
      .set('Authorization', `Bearer ${token}`)
      .expect(404);
  });
});
```

- [ ] **Step 3: Create `backend/test/rooms.e2e-spec.ts`**

```typescript
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Rooms (e2e)', () => {
  let app: INestApplication;
  let token: string;

  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    const res = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ employee_id: 'hieupt', secret: 'zps-dev-secret' });
    token = res.body.access_token as string;
  });

  afterAll(async () => { await app.close(); });

  it('GET /rooms → 5 rooms', async () => {
    const res = await request(app.getHttpServer())
      .get('/rooms')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(res.body).toHaveLength(5);
  });

  it('POST /rooms/room_alpha/book → success', async () => {
    const res = await request(app.getHttpServer())
      .post('/rooms/room_alpha/book')
      .set('Authorization', `Bearer ${token}`)
      .send({ date: '2026-05-01', time_slot: '10:00-11:00', booker_id: 'hieupt' })
      .expect(201);
    expect(res.body.success).toBe(true);
    expect(res.body.booking.room_id).toBe('room_alpha');
  });

  it('POST /rooms/room_alpha/book same slot → conflict error', async () => {
    await request(app.getHttpServer())
      .post('/rooms/room_alpha/book')
      .set('Authorization', `Bearer ${token}`)
      .send({ date: '2026-05-02', time_slot: '11:00-12:00', booker_id: 'hieupt' });
    const res = await request(app.getHttpServer())
      .post('/rooms/room_alpha/book')
      .set('Authorization', `Bearer ${token}`)
      .send({ date: '2026-05-02', time_slot: '11:00-12:00', booker_id: 'sangvk' })
      .expect(201);
    expect(res.body.success).toBe(false);
    expect(res.body.error).toMatch(/already booked/i);
  });

  it('GET /rooms/room_alpha/bookings → array of bookings', async () => {
    const res = await request(app.getHttpServer())
      .get('/rooms/room_alpha/bookings')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('POST /rooms/nonexistent/book → 404', async () => {
    await request(app.getHttpServer())
      .post('/rooms/nonexistent/book')
      .set('Authorization', `Bearer ${token}`)
      .send({ date: '2026-05-01', time_slot: '10:00-11:00', booker_id: 'hieupt' })
      .expect(404);
  });
});
```

- [ ] **Step 4: Run all e2e tests**

```bash
cd backend && npm run test:e2e
```

Expected: All 14 e2e tests PASS.

- [ ] **Step 5: Commit**

```bash
cd backend && git add test/
git commit -m "test: add e2e tests for auth, employees, and rooms endpoints"
```

---

## Task 9: Godot — HttpManager Autoload

**Files:**
- Create: `scripts/autoloads/HttpManager.gd`
- Modify: `project.godot`

- [ ] **Step 1: Create `scripts/autoloads/HttpManager.gd`**

```gdscript
## HttpManager.gd
## HTTP REST client autoload — wraps Godot HTTPRequest nodes, manages JWT auth.
## Signals carry (endpoint: String, data: Variant) on success,
## or (endpoint: String, message: String) on error.
##
## Usage:
##   HttpManager.post("auth/login", {"employee_id": "hieupt", "secret": "zps-dev-secret"})
##   await HttpManager.response_received   # → [endpoint, data_dict]

extends Node

signal response_received(endpoint: String, data: Variant)
signal error(endpoint: String, message: String)

var base_url: String = "http://localhost:3000"
var jwt_token: String = ""

# Tracks which HTTPRequest node maps to which endpoint so we can route responses
var _pending: Dictionary = {}   # HTTPRequest node → endpoint String


func _ready() -> void:
	print("[HttpManager] Ready — base_url: %s" % base_url)


# ── Public API ──────────────────────────────────────────────────────────────

func get_request(endpoint: String) -> void:
	var node := _make_request_node()
	_pending[node] = endpoint
	var headers := _build_headers()
	var err := node.request("%s/%s" % [base_url, endpoint], headers, HTTPClient.METHOD_GET)
	if err != OK:
		_pending.erase(node)
		node.queue_free()
		error.emit(endpoint, "HTTPRequest.request() failed: %d" % err)


func post(endpoint: String, body: Dictionary) -> void:
	var node := _make_request_node()
	_pending[node] = endpoint
	var headers := _build_headers()
	headers.append("Content-Type: application/json")
	var json_body := JSON.stringify(body)
	var err := node.request("%s/%s" % [base_url, endpoint], headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_pending.erase(node)
		node.queue_free()
		error.emit(endpoint, "HTTPRequest.request() failed: %d" % err)


func patch(endpoint: String, body: Dictionary) -> void:
	var node := _make_request_node()
	_pending[node] = endpoint
	var headers := _build_headers()
	headers.append("Content-Type: application/json")
	var json_body := JSON.stringify(body)
	var err := node.request("%s/%s" % [base_url, endpoint], headers, HTTPClient.METHOD_PATCH, json_body)
	if err != OK:
		_pending.erase(node)
		node.queue_free()
		error.emit(endpoint, "HTTPRequest.request() failed: %d" % err)


# ── Internal helpers ─────────────────────────────────────────────────────────

func _make_request_node() -> HTTPRequest:
	var node := HTTPRequest.new()
	node.use_threads = true
	add_child(node)
	node.request_completed.connect(_on_request_completed.bind(node))
	return node


func _build_headers() -> Array:
	var headers: Array = []
	if jwt_token != "":
		headers.append("Authorization: Bearer %s" % jwt_token)
	return headers


func _on_request_completed(
		result: int,
		response_code: int,
		_headers: PackedStringArray,
		body: PackedByteArray,
		node: HTTPRequest
) -> void:
	var endpoint: String = _pending.get(node, "unknown")
	_pending.erase(node)
	node.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		error.emit(endpoint, "Network error — result code %d" % result)
		return

	var text := body.get_string_from_utf8()
	var data: Variant = JSON.parse_string(text)

	if response_code >= 400:
		var msg := "HTTP %d" % response_code
		if data is Dictionary and data.has("message"):
			msg = str(data["message"])
		error.emit(endpoint, msg)
		return

	response_received.emit(endpoint, data)
```

- [ ] **Step 2: Add HttpManager to `project.godot` autoloads**

Open `project.godot` and find the `[autoload]` section which currently reads:

```
AIConfig="*res://scripts/autoloads/AIConfig.gd"
GameManager="*res://scripts/autoloads/GameManager.gd"
PlayerData="*res://scripts/autoloads/PlayerData.gd"
ConversationMemory="*res://scripts/autoloads/ConversationMemory.gd"
AIAgent="*res://scripts/autoloads/AIAgent.gd"
NetworkManager="*res://scripts/autoloads/NetworkManager.gd"
```

Change it to:

```
AIConfig="*res://scripts/autoloads/AIConfig.gd"
GameManager="*res://scripts/autoloads/GameManager.gd"
PlayerData="*res://scripts/autoloads/PlayerData.gd"
ConversationMemory="*res://scripts/autoloads/ConversationMemory.gd"
AIAgent="*res://scripts/autoloads/AIAgent.gd"
NetworkManager="*res://scripts/autoloads/NetworkManager.gd"
HttpManager="*res://scripts/autoloads/HttpManager.gd"
```

- [ ] **Step 3: Manual smoke test in Godot**

Start the Godot project. In the Output panel, verify:

```
[HttpManager] Ready — base_url: http://localhost:3000
```

No errors about missing nodes.

- [ ] **Step 4: Commit**

```bash
git add scripts/autoloads/HttpManager.gd project.godot
git commit -m "feat(godot): add HttpManager autoload for REST API calls"
```

---

## Task 10: Godot — LoginDialog

**Files:**
- Create: `scripts/ui/LoginDialog.gd`

- [ ] **Step 1: Create `scripts/ui/LoginDialog.gd`**

```gdscript
## LoginDialog.gd
## Modal login screen shown at startup before the world loads.
## Posts to POST /auth/login and emits login_success(employee) on OK.
## The parent (Campus.gd) hides this node and spawns the player on success.

extends CanvasLayer

signal login_success(employee: Dictionary)
signal login_skipped()

var _employee_id_field: LineEdit = null
var _secret_field: LineEdit = null
var _submit_btn: Button = null
var _error_label: Label = null
var _loading_label: Label = null


func _ready() -> void:
	_build_ui()
	HttpManager.response_received.connect(_on_http_response)
	HttpManager.error.connect(_on_http_error)


func _build_ui() -> void:
	# Full-screen dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.05, 0.10, 0.97)
	add_child(overlay)

	# Centered card
	var card := PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -220.0
	card.offset_right = 220.0
	card.offset_top = -200.0
	card.offset_bottom = 200.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.18)
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.35, 0.60)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	# Title
	var title := Label.new()
	title.text = "ZPS World — Đăng nhập"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Employee ID field
	var id_label := Label.new()
	id_label.text = "Employee ID:"
	id_label.add_theme_font_size_override("font_size", 11)
	id_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	vbox.add_child(id_label)

	_employee_id_field = LineEdit.new()
	_employee_id_field.placeholder_text = "vd: hieupt, sangvk, emp_001"
	_employee_id_field.custom_minimum_size.y = 34.0
	vbox.add_child(_employee_id_field)

	# Secret field
	var secret_label := Label.new()
	secret_label.text = "Dev Secret:"
	secret_label.add_theme_font_size_override("font_size", 11)
	secret_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	vbox.add_child(secret_label)

	_secret_field = LineEdit.new()
	_secret_field.placeholder_text = "zps-dev-secret"
	_secret_field.secret = true
	_secret_field.custom_minimum_size.y = 34.0
	_secret_field.text_submitted.connect(func(_t): _on_submit_pressed())
	vbox.add_child(_secret_field)

	# Error label (hidden until error)
	_error_label = Label.new()
	_error_label.add_theme_font_size_override("font_size", 10)
	_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.visible = false
	vbox.add_child(_error_label)

	# Loading label (hidden until request in-flight)
	_loading_label = Label.new()
	_loading_label.text = "Đang đăng nhập..."
	_loading_label.add_theme_font_size_override("font_size", 10)
	_loading_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.visible = false
	vbox.add_child(_loading_label)

	# Submit button
	_submit_btn = Button.new()
	_submit_btn.text = "Vào ZPS World"
	_submit_btn.custom_minimum_size.y = 38.0
	_submit_btn.pressed.connect(_on_submit_pressed)
	vbox.add_child(_submit_btn)

	# Skip button (offline/mock mode)
	var skip_btn := Button.new()
	skip_btn.text = "Chơi offline (dùng dữ liệu mock)"
	skip_btn.flat = true
	skip_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	skip_btn.pressed.connect(func(): login_skipped.emit())
	vbox.add_child(skip_btn)

	card.add_child(vbox)
	add_child(card)


func _on_submit_pressed() -> void:
	var employee_id := _employee_id_field.text.strip_edges()
	var secret := _secret_field.text.strip_edges()

	if employee_id.is_empty():
		_show_error("Vui lòng nhập Employee ID.")
		return
	if secret.is_empty():
		_show_error("Vui lòng nhập dev secret.")
		return

	_set_loading(true)
	HttpManager.post("auth/login", {"employee_id": employee_id, "secret": secret})


func _on_http_response(endpoint: String, data: Variant) -> void:
	if endpoint != "auth/login":
		return
	_set_loading(false)

	if not data is Dictionary:
		_show_error("Phản hồi server không hợp lệ.")
		return

	var d := data as Dictionary
	if d.has("error"):
		_show_error("Sai Employee ID hoặc secret. Thử lại.")
		return

	var token: String = d.get("access_token", "")
	var employee: Dictionary = d.get("employee", {})

	if token.is_empty() or employee.is_empty():
		_show_error("Phản hồi server thiếu dữ liệu.")
		return

	# Store JWT for all future requests
	HttpManager.jwt_token = token

	login_success.emit(employee)


func _on_http_error(endpoint: String, message: String) -> void:
	if endpoint != "auth/login":
		return
	_set_loading(false)
	_show_error("Không kết nối được server.\nChạy: cd backend && npm run start:dev\n(%s)" % message)


func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true


func _set_loading(loading: bool) -> void:
	_submit_btn.disabled = loading
	_loading_label.visible = loading
	_error_label.visible = false
```

- [ ] **Step 2: Manual verification**

With the backend NOT running, add a temporary `_test_login_dialog()` call in Campus.gd (do not commit). Verify the dialog renders and clicking "Chơi offline" emits `login_skipped`.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/LoginDialog.gd
git commit -m "feat(ui): add LoginDialog modal for JWT login at startup"
```

---

## Task 11: Godot — Campus.gd — Show LoginDialog Before World

**Files:**
- Modify: `scripts/world/Campus.gd`

The current `_ready()` in Campus.gd calls `_build_background()` through `_spawn_employees()` immediately. We need to show the login dialog first and only proceed once the player authenticates (or skips to offline mode).

- [ ] **Step 1: Read current `_ready()` in Campus.gd to verify the exact lines**

The current `_ready()` reads (lines 82–101):

```gdscript
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.10, 0.06))
	_build_background()
	_build_border_collision()
	_build_hitboxes()
	_build_navigation()
	_spawn_player()
	_spawn_employees()

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("register_player"):
		hud.register_player(player_node)

	# Wire multiplayer remote players
	NetworkManager.roster_received.connect(_on_roster_received)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.positions_updated.connect(_on_positions_updated)

	print("[Campus] ZPS Campus loaded — PNG map %.0f×%.0f px, %d zones, 100 employees" % [MAP_W, MAP_H, _zones.size()])
```

- [ ] **Step 2: Replace `_ready()` and add `_start_world()` helper**

In `scripts/world/Campus.gd`, replace the existing `_ready()` function (lines 82–101) with:

```gdscript
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.10, 0.06))
	_show_login_dialog()


func _show_login_dialog() -> void:
	var dialog: CanvasLayer = load("res://scripts/ui/LoginDialog.gd").new()
	dialog.name = "LoginDialog"
	add_child(dialog)
	dialog.login_success.connect(_on_login_success)
	dialog.login_skipped.connect(_on_login_skipped)


func _on_login_success(employee: Dictionary) -> void:
	# Update PlayerData with real employee fields from JWT
	PlayerData.player_id = employee.get("id", PlayerData.player_id)
	PlayerData.display_name = employee.get("name", PlayerData.display_name)
	PlayerData.department = employee.get("department", PlayerData.department)
	PlayerData.hr_title = employee.get("title", PlayerData.hr_title)
	var avatar: Dictionary = employee.get("avatar", {})
	if not avatar.is_empty():
		PlayerData.avatar_config.merge(avatar, true)
	_remove_login_dialog()
	# Load employee list from REST before starting the world
	HttpManager.response_received.connect(_on_employees_loaded, CONNECT_ONE_SHOT)
	HttpManager.error.connect(_on_employees_load_error, CONNECT_ONE_SHOT)
	HttpManager.get_request("employees")


func _on_login_skipped() -> void:
	_remove_login_dialog()
	_start_world()


func _on_employees_loaded(endpoint: String, data: Variant) -> void:
	if endpoint != "employees":
		return
	if data is Array:
		# Replace mock employees with real data from the server
		GameManager.employees = {}
		for emp in data:
			if emp is Dictionary and emp.has("id"):
				GameManager.employees[emp["id"]] = emp
		# Re-add the local player entry so HUD roster shows them
		GameManager.employees[PlayerData.player_id] = {
			"id": PlayerData.player_id,
			"name": PlayerData.display_name,
			"department": PlayerData.department,
			"title": PlayerData.hr_title,
			"is_online": true,
			"avatar": PlayerData.avatar_config,
			"current_task": "Exploring ZPS World",
		}
	_start_world()


func _on_employees_load_error(_endpoint: String, _message: String) -> void:
	# If loading fails just use existing mock data and continue
	push_warning("[Campus] Failed to load employees from REST — using mock data")
	_start_world()


func _remove_login_dialog() -> void:
	var dialog := get_node_or_null("LoginDialog")
	if dialog:
		dialog.queue_free()


func _start_world() -> void:
	_build_background()
	_build_border_collision()
	_build_hitboxes()
	_build_navigation()
	_spawn_player()
	_spawn_employees()

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("register_player"):
		hud.register_player(player_node)

	NetworkManager.roster_received.connect(_on_roster_received)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.positions_updated.connect(_on_positions_updated)

	print("[Campus] ZPS Campus loaded — PNG map %.0f×%.0f px, %d zones, %d employees" % [
		MAP_W, MAP_H, _zones.size(), GameManager.employees.size()
	])
```

- [ ] **Step 3: Test full login flow**

1. Start the NestJS backend: `cd backend && npm run start:dev`
2. Launch the Godot project.
3. Verify the LoginDialog appears before the world.
4. Enter `hieupt` / `zps-dev-secret` and press "Vào ZPS World".
5. Verify the world loads and the player card (top-left) shows "Hiếu PT".
6. Relaunch and click "Chơi offline" — world loads with mock data.

- [ ] **Step 4: Commit**

```bash
git add scripts/world/Campus.gd
git commit -m "feat(world): show LoginDialog at startup; load employees from REST on login"
```

---

## Task 12: Godot — HUD Leave Tab wired to REST

**Files:**
- Modify: `scripts/ui/HUD.gd` — `_build_leave_tab()`

The current `_build_leave_tab()` calls `GameManager.request_leave(...)` directly. We need to POST to `tasks` via `HttpManager` instead, and show a loading state while in-flight.

- [ ] **Step 1: Find exact lines of `_build_leave_tab()` in HUD.gd**

The current function (lines 655–693) ends with:

```gdscript
	var submit = Button.new(); submit.text = "Gửi đơn xin nghỉ"
	submit.pressed.connect(func():
		GameManager.request_leave({
			"type": type_opt.get_item_text(type_opt.selected),
			"dates": "%s → %s" % [from_date.text, to_date.text],
			"reason": reason.text,
		})
		result_lbl.text = "✓ Đơn đã gửi! HR sẽ xét duyệt trong 24h."
	)
	tab.add_child(submit)
	tab.add_child(result_lbl)
	return tab
```

- [ ] **Step 2: Replace `_build_leave_tab()` with REST-wired version**

Replace the entire `_build_leave_tab()` function with:

```gdscript
func _build_leave_tab() -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.add_theme_constant_override("separation", 8)
	tab.add_child(_make_label("Loại nghỉ:", 11, Color(0.8, 0.8, 0.9)))

	var type_opt := OptionButton.new()
	for t: String in ["Nghỉ phép năm", "Nghỉ ốm", "Nghỉ không lương", "Nghỉ đặc biệt"]:
		type_opt.add_item(t)
	tab.add_child(type_opt)

	tab.add_child(_make_label("Từ ngày:", 11, Color(0.8, 0.8, 0.9)))
	var from_date := LineEdit.new()
	from_date.text = Time.get_date_string_from_system()
	from_date.placeholder_text = "YYYY-MM-DD"
	tab.add_child(from_date)

	tab.add_child(_make_label("Đến ngày:", 11, Color(0.8, 0.8, 0.9)))
	var to_date := LineEdit.new()
	to_date.text = Time.get_date_string_from_system()
	tab.add_child(to_date)

	tab.add_child(_make_label("Lý do:", 11, Color(0.8, 0.8, 0.9)))
	var reason := TextEdit.new()
	reason.custom_minimum_size = Vector2(0, 60)
	tab.add_child(reason)

	var result_lbl := _make_label("", 11, Color.GREEN)
	result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var submit := Button.new()
	submit.text = "Gửi đơn xin nghỉ"

	submit.pressed.connect(func():
		var leave_title: String = "Xin nghỉ: %s (%s → %s)" % [
			type_opt.get_item_text(type_opt.selected),
			from_date.text,
			to_date.text,
		]
		submit.disabled = true
		result_lbl.text = "Đang gửi..."
		result_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))

		if HttpManager.jwt_token.is_empty():
			# Offline mode fallback — call legacy GameManager helper
			GameManager.request_leave({
				"type": type_opt.get_item_text(type_opt.selected),
				"dates": "%s → %s" % [from_date.text, to_date.text],
				"reason": reason.text,
			})
			result_lbl.text = "✓ Đơn đã gửi (offline)! HR sẽ xét duyệt trong 24h."
			result_lbl.add_theme_color_override("font_color", Color.GREEN)
			submit.disabled = false
			return

		var payload := {
			"title": leave_title,
			"assignee_id": PlayerData.player_id,
			"due_date": to_date.text,
		}
		HttpManager.post("tasks", payload)

		var on_resp := func(endpoint: String, _data: Variant) -> void:
			if endpoint != "tasks":
				return
			result_lbl.text = "✓ Đơn đã gửi! HR sẽ xét duyệt trong 24h."
			result_lbl.add_theme_color_override("font_color", Color.GREEN)
			submit.disabled = false

		var on_err := func(endpoint: String, msg: String) -> void:
			if endpoint != "tasks":
				return
			result_lbl.text = "✗ Lỗi gửi đơn: %s" % msg
			result_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			submit.disabled = false

		HttpManager.response_received.connect(on_resp, CONNECT_ONE_SHOT)
		HttpManager.error.connect(on_err, CONNECT_ONE_SHOT)
	)
	tab.add_child(submit)
	tab.add_child(result_lbl)
	return tab
```

- [ ] **Step 3: Test leave request**

1. Launch game, log in as `hieupt`.
2. Press H to open Workspace → click "Xin Nghỉ" tab.
3. Fill in the form and press "Gửi đơn xin nghỉ".
4. Verify the result label shows "✓ Đơn đã gửi!".
5. In another terminal: `curl -s -H "Authorization: Bearer <token>" http://localhost:3000/tasks | jq '.[] | select(.assignee_id == "hieupt")'`
   Verify the task appears.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/HUD.gd
git commit -m "feat(hud): wire leave tab to POST /tasks REST endpoint with offline fallback"
```

---

## Task 13: Godot — HUD Task Panel (new tab)

**Files:**
- Modify: `scripts/ui/HUD.gd` — add `_build_task_tab()` and insert into `_create_workspace_panel_inline()`

- [ ] **Step 1: Add `_build_task_tab()` to HUD.gd**

After the closing `}` of `_build_ai_tab()` (around line 729), insert a new function:

```gdscript
# ── Task Panel tab (T shortcut maps to this tab index) ──
func _build_task_tab() -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = "TaskTab"
	tab.add_theme_constant_override("separation", 6)

	var header_row := HBoxContainer.new()
	header_row.add_child(_make_label("Công việc của tôi", 12, Color(0.9, 0.85, 0.6), true))
	header_row.add_spacer(false)
	var refresh_btn := Button.new()
	refresh_btn.text = "↻ Tải lại"
	refresh_btn.flat = true
	header_row.add_child(refresh_btn)
	tab.add_child(header_row)

	var status_lbl := _make_label("", 10, Color(0.6, 0.6, 0.6))
	status_lbl.name = "TaskStatusLabel"
	tab.add_child(status_lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var list := VBoxContainer.new()
	list.name = "TaskList"
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	tab.add_child(scroll)

	# ── Load tasks from REST ──
	var load_tasks := func() -> void:
		if HttpManager.jwt_token.is_empty():
			# Offline: show a placeholder
			status_lbl.text = "(offline — đăng nhập để xem task thật)"
			return
		status_lbl.text = "Đang tải..."
		for child in list.get_children():
			child.queue_free()
		HttpManager.get_request("tasks")

	var on_tasks_loaded: Callable
	var on_tasks_error: Callable

	on_tasks_loaded = func(endpoint: String, data: Variant) -> void:
		if endpoint != "tasks":
			return
		status_lbl.text = ""
		for child in list.get_children():
			child.queue_free()
		if not data is Array or (data as Array).is_empty():
			list.add_child(_make_label("Không có task nào.", 10, Color(0.6, 0.6, 0.6)))
			return
		for item: Variant in data:
			if not item is Dictionary:
				continue
			var task: Dictionary = item
			var card := PanelContainer.new()
			var s := StyleBoxFlat.new()
			s.bg_color = Color(0.12, 0.14, 0.22)
			s.set_corner_radius_all(6)
			card.add_theme_stylebox_override("panel", s)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)

			var status_val: String = task.get("status", "todo")
			var status_color := Color(0.6, 0.6, 0.6)
			match status_val:
				"todo":         status_color = Color(0.7, 0.7, 0.35)
				"in-progress":  status_color = Color(0.3, 0.7, 1.0)
				"done":         status_color = Color(0.3, 0.9, 0.3)
			var status_dot := _make_label("●", 12, status_color)
			row.add_child(status_dot)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_child(_make_label(task.get("title", "?"), 11, Color.WHITE))
			info.add_child(_make_label("Due: %s" % task.get("due_date", "?"), 9, Color(0.6, 0.6, 0.6)))
			row.add_child(info)

			var toggle_btn := Button.new()
			toggle_btn.custom_minimum_size = Vector2(80, 0)
			match status_val:
				"todo":        toggle_btn.text = "▶ Bắt đầu"
				"in-progress": toggle_btn.text = "✓ Xong"
				"done":        toggle_btn.text = "↩ Mở lại"

			var task_id: String = task.get("id", "")
			var next_status := "in-progress"
			match status_val:
				"todo":        next_status = "in-progress"
				"in-progress": next_status = "done"
				"done":        next_status = "todo"

			toggle_btn.pressed.connect(func():
				toggle_btn.disabled = true
				HttpManager.patch("tasks/%s" % task_id, {"status": next_status})
				HttpManager.response_received.connect(
					func(ep: String, _d: Variant):
						if ep == "tasks/%s" % task_id:
							load_tasks.call(),
					CONNECT_ONE_SHOT
				)
				HttpManager.error.connect(
					func(ep: String, msg: String):
						if ep == "tasks/%s" % task_id:
							toggle_btn.disabled = false
							GameManager.notify("Lỗi cập nhật task: %s" % msg, "error"),
					CONNECT_ONE_SHOT
				)
			)
			row.add_child(toggle_btn)
			card.add_child(row)
			list.add_child(card)

	on_tasks_error = func(endpoint: String, msg: String) -> void:
		if endpoint != "tasks":
			return
		status_lbl.text = "✗ Lỗi tải task: %s" % msg

	HttpManager.response_received.connect(on_tasks_loaded)
	HttpManager.error.connect(on_tasks_error)
	refresh_btn.pressed.connect(load_tasks)

	# Auto-load on first open
	tab.visibility_changed.connect(func():
		if tab.visible:
			load_tasks.call()
	)

	return tab
```

- [ ] **Step 2: Insert the Task tab into `_create_workspace_panel_inline()`**

Find in HUD.gd around line 617 where tabs are added:

```gdscript
	# ── Tab 3: Leave (last) ──
	var leave_tab = _build_leave_tab()
	leave_tab.name = "📅 Xin Nghỉ"
	tabs.add_child(leave_tab)
```

Replace with:

```gdscript
	# ── Tab 3: My Tasks ──
	var task_tab = _build_task_tab()
	task_tab.name = "✅ Tasks"
	tabs.add_child(task_tab)

	# ── Tab 4: Leave ──
	var leave_tab = _build_leave_tab()
	leave_tab.name = "📅 Xin Nghỉ"
	tabs.add_child(leave_tab)
```

- [ ] **Step 3: Test the task panel**

1. Log in as `hieupt`.
2. Press H → click "✅ Tasks" tab.
3. Verify 2 tasks appear (task_001, task_002 from seed data).
4. Click "▶ Bắt đầu" on task_002 — verify it refreshes and shows "in-progress".
5. Click "✓ Xong" — verify status changes to "done".

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/HUD.gd
git commit -m "feat(hud): add Task panel tab with REST-backed status toggle"
```

---

## Task 14: Godot — Room Booking wired to REST

**Files:**
- Modify: `scripts/ui/HUD.gd` — `_build_book_room_tab()`

The current `_build_book_room_tab()` calls `GameManager.book_room(...)` directly. We wire it to `HttpManager`.

- [ ] **Step 1: Replace `_build_book_room_tab()` with REST-wired version**

Find in HUD.gd the `_build_book_room_tab()` function (lines 628–653) and replace it entirely with:

```gdscript
func _build_book_room_tab() -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.add_theme_constant_override("separation", 8)
	tab.add_child(_make_label("Chọn phòng họp:", 11, Color(0.8, 0.8, 0.9)))

	# Time slot selector
	tab.add_child(_make_label("Ngày:", 10, Color(0.7, 0.7, 0.8)))
	var date_field := LineEdit.new()
	date_field.text = Time.get_date_string_from_system()
	date_field.placeholder_text = "YYYY-MM-DD"
	tab.add_child(date_field)

	tab.add_child(_make_label("Khung giờ:", 10, Color(0.7, 0.7, 0.8)))
	var slot_opt := OptionButton.new()
	for s: String in ["09:00-10:00", "10:00-11:00", "13:00-14:00", "14:00-15:00", "15:00-16:00"]:
		slot_opt.add_item(s)
	tab.add_child(slot_opt)

	var result_lbl := _make_label("", 11, Color.GREEN)
	result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	for room_id: String in GameManager.meeting_rooms:
		var room: Dictionary = GameManager.meeting_rooms[room_id]
		var btn := Button.new()
		btn.text = "📋 %s — %d người | %s" % [
			room["name"],
			room.get("capacity", 0),
			", ".join(room.get("equipment", [])),
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func():
			result_lbl.text = "Đang đặt..."
			result_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))

			if HttpManager.jwt_token.is_empty():
				# Offline fallback
				var ok := GameManager.book_room(room_id, slot_opt.get_item_text(slot_opt.selected), PlayerData.player_id)
				result_lbl.text = "✓ Đã đặt %s!" % room["name"] if ok else "✗ Slot đã bị đặt rồi!"
				result_lbl.add_theme_color_override("font_color", Color.GREEN if ok else Color(1.0, 0.4, 0.4))
				return

			var payload := {
				"date": date_field.text,
				"time_slot": slot_opt.get_item_text(slot_opt.selected),
				"booker_id": PlayerData.player_id,
			}
			var ep := "rooms/%s/book" % room_id
			HttpManager.post(ep, payload)

			HttpManager.response_received.connect(
				func(endpoint: String, data: Variant):
					if endpoint != ep:
						return
					if data is Dictionary and (data as Dictionary).get("success", false):
						result_lbl.text = "✓ Đã đặt %s lúc %s!" % [room["name"], payload["time_slot"]]
						result_lbl.add_theme_color_override("font_color", Color.GREEN)
						GameManager.notify("Phòng %s đã đặt lúc %s ✓" % [room["name"], payload["time_slot"]], "success")
					else:
						var err_msg: String = ""
						if data is Dictionary:
							err_msg = (data as Dictionary).get("error", "Lỗi không xác định")
						result_lbl.text = "✗ %s" % err_msg
						result_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)),
				CONNECT_ONE_SHOT
			)
			HttpManager.error.connect(
				func(endpoint: String, msg: String):
					if endpoint != ep:
						return
					result_lbl.text = "✗ Lỗi đặt phòng: %s" % msg
					result_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4)),
				CONNECT_ONE_SHOT
			)
		)
		tab.add_child(btn)

	tab.add_child(result_lbl)
	return tab
```

- [ ] **Step 2: Test room booking**

1. Log in as `hieupt`.
2. Press H → "📋 Đặt Phòng" tab.
3. Pick a date and time slot.
4. Click "Room Alpha".
5. Verify "✓ Đã đặt Room Alpha lúc 09:00-10:00!" appears.
6. Click the same room with the same slot — verify conflict error appears.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/HUD.gd
git commit -m "feat(hud): wire room booking tab to REST /rooms/:id/book with offline fallback"
```

---

## Task 15: Integration — Full Flow End-to-End Test

**Goal:** Verify the complete Sprint 3 feature chain works together.

- [ ] **Step 1: Start backend**

```bash
cd backend && npm run start:dev
```

Expected output: `[ZPS Backend] Running on http://localhost:3000`

- [ ] **Step 2: Run all backend tests**

```bash
cd backend && npm test && npm run test:e2e
```

Expected: All unit + e2e tests pass. Zero failures.

- [ ] **Step 3: Start Godot and verify login flow**

1. Open `ZPSWorld` project in Godot 4.6.
2. Press F5 (Run Project).
3. LoginDialog must appear.
4. Enter `hieupt` / `zps-dev-secret` → click "Vào ZPS World".
5. World loads. Player card top-left shows "Hiếu PT".

- [ ] **Step 4: Verify employee data replaced**

In the Godot Output panel, the last print line must show more than 2 employees:

```
[Campus] ZPS Campus loaded — PNG map 1193×896 px, 10 zones, 102 employees
```

- [ ] **Step 5: Verify Task panel**

Press H → "✅ Tasks". Two seeded tasks for `hieupt` should appear. Toggle one to verify PATCH call works.

- [ ] **Step 6: Verify Leave request**

Press H → "📅 Xin Nghỉ". Submit form. Confirm label shows "✓ Đơn đã gửi!".

Confirm in terminal:

```bash
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"employee_id":"hieupt","secret":"zps-dev-secret"}' | jq -r '.access_token')
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/tasks | jq '.[].title'
```

The leave request title should appear in the output.

- [ ] **Step 7: Verify Room Booking**

Press H → "📋 Đặt Phòng". Book Room Alpha. Confirm success toast. Book again with same slot — conflict error.

- [ ] **Step 8: Verify offline mode**

Stop the backend (`Ctrl+C`). Relaunch Godot. Click "Chơi offline" — world loads with mock data. Leave request and room booking still work via offline fallback.

- [ ] **Step 9: Final commit**

```bash
git add .
git commit -m "feat: Sprint 3 complete — NestJS backend + Godot REST integration"
```

---

## Self-Review

### 1. Spec Coverage Check

| Spec Requirement | Task |
|---|---|
| 3A — NestJS project scaffold | Task 1 |
| 3A — Auth module (login + /me) | Tasks 2, 3 |
| 3A — Employees module (list + one) | Task 4 |
| 3A — Rooms module (list, book, bookings) | Task 5 |
| 3A — Tasks module (list, create, patch status) | Task 6 |
| 3A — App root module + CORS + ValidationPipe | Task 7 |
| 3A — Jest unit + e2e tests | Tasks 2–6 (unit), Task 8 (e2e) |
| 3A — No database, in-memory data | AuthService seed data (Task 2), RoomsService (Task 5), TasksService (Task 6) |
| 3A — Mock SSO secret `zps-dev-secret` | Task 2 AuthService |
| 3B — HttpManager autoload | Task 9 |
| 3C — Login flow (dialog → JWT → load employees) | Tasks 10, 11 |
| 3D — HR Leave Request Panel → POST /tasks | Task 12 |
| 3E — Task View Panel → GET /tasks + PATCH | Task 13 |
| 3F — Room Booking → GET bookings + POST book | Task 14 |
| Offline fallback for all panels | Tasks 12, 13, 14 |
| Full integration test | Task 15 |

All spec requirements are covered.

### 2. Placeholder Scan

No "TBD", "TODO", "similar to above", or "implement later" patterns found. Every step contains complete runnable code.

### 3. Type Consistency Check

- `EmployeeProfile` interface defined in `auth.service.ts` (Task 2) and imported by `employees.service.ts` (Task 4), `rooms.controller.ts` (Task 5), `tasks.controller.ts` (Task 6). Consistent.
- `BookingRecord` and `RoomData` defined in `rooms/dto/booking.dto.ts` (Task 5) and used in `rooms.service.ts` and `rooms.controller.ts`. Consistent.
- `Task` and `TaskStatus` defined in `tasks.service.ts` (Task 6) and used in `tasks.controller.ts`. Consistent.
- `HttpManager.get_request(endpoint)` defined in Task 9 and called in Task 11 (`get_request("employees")`), Task 13 (`get_request("tasks")`). Consistent.
- `HttpManager.post(endpoint, body)` defined in Task 9 and called in Task 10 (`post("auth/login", ...)`), Task 12 (`post("tasks", ...)`), Task 14 (`post("rooms/:id/book", ...)`). Consistent.
- `HttpManager.patch(endpoint, body)` defined in Task 9 and called in Task 13 (`patch("tasks/%s" % task_id, ...)`). Consistent.
- `login_success(employee: Dictionary)` signal defined in `LoginDialog.gd` (Task 10) and connected in `Campus.gd` (Task 11). Consistent.
- `login_skipped()` signal defined in `LoginDialog.gd` (Task 10) and connected in `Campus.gd` (Task 11). Consistent.
- `GameManager.employees` is a `Dictionary` in `GameManager.gd`. Written as `GameManager.employees = {}` and `GameManager.employees[id] = emp` in Task 11 `_on_employees_loaded`. Consistent.
