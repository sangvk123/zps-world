# Sprint 5: Events + Minigames Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add company events, announcements, and multiplayer minigames (ZPS Trivia + Reaction Quiz) to create a complete engagement layer for ZPS World.

**Architecture:** NestJS REST API (`backend/`) handles events and announcements (in-memory, JWT-gated by role). The existing Node.js WebSocket server (`server/`) gains a `TriviaManager` for real-time minigame state. Godot UI panels (`scripts/ui/`) connect to both via existing `HttpManager` and `NetworkManager` autoloads; `Campus.gd` polls the REST API for active events and decorates zones.

**Tech Stack:** NestJS 10 + `@nestjs/testing` + Jest (backend), Node.js + Jest (WS server), Godot 4.6 GDScript (UI), existing `HttpManager.gd` + `NetworkManager.gd` autoloads.

---

## File Map

### New — Backend (`backend/`)
| File | Responsibility |
|------|---------------|
| `backend/package.json` | NestJS dependencies, Jest config |
| `backend/tsconfig.json` | TypeScript compiler settings |
| `backend/src/main.ts` | Bootstrap NestJS app on port 3002 |
| `backend/src/app.module.ts` | Root module, imports Events + Announcements modules |
| `backend/src/auth/jwt.guard.ts` | JWT validation guard (reads `Authorization: Bearer <token>`) |
| `backend/src/auth/roles.guard.ts` | Role-based guard (checks `role` claim in JWT payload) |
| `backend/src/auth/roles.decorator.ts` | `@Roles(...)` decorator |
| `backend/src/events/event.types.ts` | `Event` interface + `EventStatus` enum |
| `backend/src/events/events.service.ts` | In-memory CRUD + attendance logic |
| `backend/src/events/events.controller.ts` | REST endpoints for events |
| `backend/src/events/events.module.ts` | Module wiring |
| `backend/src/announcements/announcement.types.ts` | `Announcement` interface |
| `backend/src/announcements/announcements.service.ts` | In-memory CRUD + 7-day expiry |
| `backend/src/announcements/announcements.controller.ts` | REST endpoints for announcements |
| `backend/src/announcements/announcements.module.ts` | Module wiring |
| `backend/test/events.service.spec.ts` | Unit tests for EventsService |
| `backend/test/announcements.service.spec.ts` | Unit tests for AnnouncementsService |

### New — WebSocket Server (`server/src/`)
| File | Responsibility |
|------|---------------|
| `server/src/trivia-manager.js` | Trivia game state machine (start, tick, score, end) |

### Modified — WebSocket Server
| File | Change |
|------|--------|
| `server/src/server.js` | Handle `trivia_start`, `trivia_answer`, `reaction_start`, `reaction_press` WS messages |

### New — Godot UI (`scripts/ui/`)
| File | Responsibility |
|------|---------------|
| `scripts/ui/EventBoard.gd` | Panel listing upcoming events with countdown + Attend button |
| `scripts/ui/EventCreatePanel.gd` | Form for Lead/Admin to create events (hidden for member role) |
| `scripts/ui/AnnouncementBoard.gd` | Panel showing 3 latest announcements |
| `scripts/ui/TriviaPanel.gd` | Auto-popup during trivia; renders question + A/B/C/D + score |
| `scripts/ui/ReactionQuizPanel.gd` | Auto-popup for Reaction Quiz; countdown + Space to win |

### Modified — Godot
| File | Change |
|------|--------|
| `scripts/autoloads/PlayerData.gd` | Add `player_role: String = "member"` field + save/load |
| `scripts/ui/HUD.gd` | Add `V` shortcut → EventBoard; add event toast; build EventBoard + AnnouncementBoard nodes |
| `scripts/world/Campus.gd` | Add zone decoration overlay system; poll `/events?status=active` every 30s |
| `scripts/autoloads/NetworkManager.gd` | Add signals + send helpers for trivia/reaction WS messages |

---

## Task 1: NestJS Backend Scaffold

**Files:**
- Create: `backend/package.json`
- Create: `backend/tsconfig.json`
- Create: `backend/src/main.ts`
- Create: `backend/src/app.module.ts`

- [ ] **Step 1: Create `backend/package.json`**

```json
{
  "name": "zps-world-backend",
  "version": "1.0.0",
  "scripts": {
    "start": "ts-node src/main.ts",
    "dev": "ts-node-dev --respawn src/main.ts",
    "build": "tsc",
    "test": "jest"
  },
  "dependencies": {
    "@nestjs/common": "^10.3.0",
    "@nestjs/core": "^10.3.0",
    "@nestjs/platform-express": "^10.3.0",
    "reflect-metadata": "^0.2.1",
    "rxjs": "^7.8.1"
  },
  "devDependencies": {
    "@nestjs/testing": "^10.3.0",
    "@types/jest": "^29.5.12",
    "@types/node": "^20.11.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.2",
    "ts-node": "^10.9.2",
    "ts-node-dev": "^2.0.0",
    "typescript": "^5.3.3"
  },
  "jest": {
    "preset": "ts-jest",
    "testEnvironment": "node",
    "rootDir": ".",
    "testMatch": ["**/test/**/*.spec.ts"]
  }
}
```

- [ ] **Step 2: Create `backend/tsconfig.json`**

```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "ES2021",
    "lib": ["ES2021"],
    "strict": true,
    "esModuleInterop": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "outDir": "dist",
    "rootDir": "src",
    "skipLibCheck": true
  },
  "include": ["src/**/*", "test/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

- [ ] **Step 3: Create `backend/src/main.ts`**

```typescript
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  await app.listen(3002);
  console.log('[ZPS Backend] Listening on http://localhost:3002');
}
bootstrap();
```

- [ ] **Step 4: Create `backend/src/app.module.ts`**

```typescript
import { Module } from '@nestjs/common';
import { EventsModule } from './events/events.module';
import { AnnouncementsModule } from './announcements/announcements.module';

@Module({
  imports: [EventsModule, AnnouncementsModule],
})
export class AppModule {}
```

- [ ] **Step 5: Install dependencies**

```bash
cd backend && npm install
```

Expected: `node_modules/` created, no errors.

- [ ] **Step 6: Commit**

```bash
git add backend/package.json backend/tsconfig.json backend/src/main.ts backend/src/app.module.ts
git commit -m "feat: scaffold NestJS backend for Sprint 5"
```

---

## Task 2: JWT + Roles Auth Guards

**Files:**
- Create: `backend/src/auth/jwt.guard.ts`
- Create: `backend/src/auth/roles.guard.ts`
- Create: `backend/src/auth/roles.decorator.ts`

> **Context:** The game uses local dev tokens. For Sprint 5, the JWT payload is a base64-encoded JSON object (no signature verification) with shape `{ id, role }`. This is prototype-safe: no crypto library needed. Role values: `"member"`, `"lead"`, `"admin"`.

- [ ] **Step 1: Create `backend/src/auth/roles.decorator.ts`**

```typescript
import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);
```

- [ ] **Step 2: Create `backend/src/auth/jwt.guard.ts`**

```typescript
import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';

export interface JwtPayload {
  id: string;
  role: 'member' | 'lead' | 'admin';
}

@Injectable()
export class JwtGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<Request>();
    const auth = req.headers['authorization'];
    if (!auth || !auth.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing token');
    }
    const token = auth.slice(7);
    try {
      // Prototype: token is base64(JSON). No signature.
      const payload: JwtPayload = JSON.parse(
        Buffer.from(token, 'base64').toString('utf8'),
      );
      if (!payload.id || !payload.role) throw new Error('Bad payload');
      (req as any).user = payload;
      return true;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
  }
}
```

- [ ] **Step 3: Create `backend/src/auth/roles.guard.ts`**

```typescript
import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from './roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required || required.length === 0) return true;
    const req = context.switchToHttp().getRequest();
    const user = req.user;
    if (!user || !required.includes(user.role)) {
      throw new ForbiddenException('Insufficient role');
    }
    return true;
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add backend/src/auth/
git commit -m "feat: add JWT + roles auth guards (prototype base64 tokens)"
```

---

## Task 3: Events Service + Types

**Files:**
- Create: `backend/src/events/event.types.ts`
- Create: `backend/src/events/events.service.ts`
- Create: `backend/test/events.service.spec.ts`

- [ ] **Step 1: Create `backend/src/events/event.types.ts`**

```typescript
export type EventType = 'official' | 'team_official' | 'non_official';
export type EventStatus = 'upcoming' | 'active' | 'ended';

export interface ZPSEvent {
  id: string;
  title: string;
  description: string;
  creator_id: string;
  creator_role: 'lead' | 'admin';
  type: EventType;
  location_zone: string;
  start_time: string; // ISO datetime
  end_time: string;   // ISO datetime
  max_attendees: number | null;
  attendee_ids: string[];
  status: EventStatus;
}

export interface CreateEventDto {
  title: string;
  description: string;
  type: EventType;
  location_zone: string;
  start_time: string;
  end_time: string;
  max_attendees?: number | null;
}
```

- [ ] **Step 2: Write the failing test first**

Create `backend/test/events.service.spec.ts`:

```typescript
import { Test } from '@nestjs/testing';
import { EventsService } from '../src/events/events.service';
import { CreateEventDto } from '../src/events/event.types';

describe('EventsService', () => {
  let service: EventsService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [EventsService],
    }).compile();
    service = module.get(EventsService);
  });

  describe('create + findAll', () => {
    it('creates an event and returns it in list', () => {
      const dto: CreateEventDto = {
        title: 'Team Standup',
        description: 'Daily sync',
        type: 'team_official',
        location_zone: 'engineering',
        start_time: '2026-04-10T09:00:00.000Z',
        end_time: '2026-04-10T09:30:00.000Z',
        max_attendees: null,
      };
      const created = service.create(dto, 'user1', 'lead');
      expect(created.id).toMatch(/^evt-/);
      expect(created.title).toBe('Team Standup');
      expect(created.attendee_ids).toEqual([]);
      expect(created.status).toBe('upcoming');

      const all = service.findAll();
      expect(all).toHaveLength(1);
      expect(all[0].id).toBe(created.id);
    });
  });

  describe('findById', () => {
    it('returns undefined for unknown id', () => {
      expect(service.findById('nope')).toBeUndefined();
    });

    it('returns the event for known id', () => {
      const evt = service.create(
        { title: 'X', description: 'Y', type: 'official', location_zone: 'reception', start_time: '2026-04-10T10:00:00.000Z', end_time: '2026-04-10T11:00:00.000Z' },
        'admin1', 'admin',
      );
      expect(service.findById(evt.id)?.title).toBe('X');
    });
  });

  describe('attend', () => {
    it('adds attendee_id to event', () => {
      const evt = service.create(
        { title: 'Hackathon', description: 'Build!', type: 'official', location_zone: 'collab_hub', start_time: '2026-04-11T08:00:00.000Z', end_time: '2026-04-11T18:00:00.000Z', max_attendees: 50 },
        'lead1', 'lead',
      );
      service.attend(evt.id, 'player42');
      expect(service.findById(evt.id)?.attendee_ids).toContain('player42');
    });

    it('does not duplicate attendee', () => {
      const evt = service.create(
        { title: 'Quiz Night', description: 'Fun', type: 'non_official', location_zone: 'amenity', start_time: '2026-04-12T19:00:00.000Z', end_time: '2026-04-12T21:00:00.000Z' },
        'lead2', 'lead',
      );
      service.attend(evt.id, 'p1');
      service.attend(evt.id, 'p1');
      expect(service.findById(evt.id)?.attendee_ids).toHaveLength(1);
    });

    it('throws NotFoundException for unknown event', () => {
      expect(() => service.attend('bad-id', 'p1')).toThrow();
    });

    it('throws BadRequestException when max_attendees is reached', () => {
      const evt = service.create(
        { title: 'Small Meeting', description: '', type: 'team_official', location_zone: 'library', start_time: '2026-04-13T10:00:00.000Z', end_time: '2026-04-13T11:00:00.000Z', max_attendees: 1 },
        'lead1', 'lead',
      );
      service.attend(evt.id, 'p1');
      expect(() => service.attend(evt.id, 'p2')).toThrow();
    });
  });

  describe('findAll with status filter', () => {
    it('filters by status=active', () => {
      const now = new Date();
      const past = new Date(now.getTime() - 60000).toISOString();
      const future = new Date(now.getTime() + 60000).toISOString();
      const farFuture = new Date(now.getTime() + 7200000).toISOString();

      service.create({ title: 'Active', description: '', type: 'official', location_zone: 'reception', start_time: past, end_time: farFuture }, 'a', 'admin');
      service.create({ title: 'Upcoming', description: '', type: 'official', location_zone: 'reception', start_time: future, end_time: farFuture }, 'a', 'admin');

      const active = service.findAll('active');
      expect(active).toHaveLength(1);
      expect(active[0].title).toBe('Active');
    });
  });

  describe('getAttendance', () => {
    it('returns attendee ids list', () => {
      const evt = service.create(
        { title: 'T', description: '', type: 'non_official', location_zone: 'outdoor', start_time: '2026-04-14T12:00:00.000Z', end_time: '2026-04-14T13:00:00.000Z' },
        'lead1', 'lead',
      );
      service.attend(evt.id, 'alice');
      service.attend(evt.id, 'bob');
      expect(service.getAttendance(evt.id)).toEqual(['alice', 'bob']);
    });
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd backend && npx jest test/events.service.spec.ts --no-coverage
```

Expected: FAIL — `Cannot find module '../src/events/events.service'`

- [ ] **Step 4: Create `backend/src/events/events.service.ts`**

```typescript
import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CreateEventDto, EventStatus, ZPSEvent } from './event.types';

@Injectable()
export class EventsService {
  private readonly _events: Map<string, ZPSEvent> = new Map();
  private _counter = 0;

  create(
    dto: CreateEventDto,
    creatorId: string,
    creatorRole: 'lead' | 'admin',
  ): ZPSEvent {
    const id = `evt-${++this._counter}-${Date.now()}`;
    const event: ZPSEvent = {
      id,
      title: dto.title,
      description: dto.description,
      creator_id: creatorId,
      creator_role: creatorRole,
      type: dto.type,
      location_zone: dto.location_zone,
      start_time: dto.start_time,
      end_time: dto.end_time,
      max_attendees: dto.max_attendees ?? null,
      attendee_ids: [],
      status: 'upcoming',
    };
    this._events.set(id, event);
    return event;
  }

  findAll(statusFilter?: string): ZPSEvent[] {
    const now = new Date();
    const all = Array.from(this._events.values()).map((evt) => ({
      ...evt,
      status: this._computeStatus(evt, now),
    }));
    if (!statusFilter) return all;
    return all.filter((e) => e.status === statusFilter);
  }

  findById(id: string): ZPSEvent | undefined {
    const evt = this._events.get(id);
    if (!evt) return undefined;
    return { ...evt, status: this._computeStatus(evt, new Date()) };
  }

  attend(eventId: string, playerId: string): ZPSEvent {
    const evt = this._events.get(eventId);
    if (!evt) throw new NotFoundException(`Event ${eventId} not found`);
    if (
      evt.max_attendees !== null &&
      evt.attendee_ids.length >= evt.max_attendees &&
      !evt.attendee_ids.includes(playerId)
    ) {
      throw new BadRequestException('Event is full');
    }
    if (!evt.attendee_ids.includes(playerId)) {
      evt.attendee_ids.push(playerId);
    }
    return { ...evt, status: this._computeStatus(evt, new Date()) };
  }

  getAttendance(eventId: string): string[] {
    const evt = this._events.get(eventId);
    if (!evt) throw new NotFoundException(`Event ${eventId} not found`);
    return [...evt.attendee_ids];
  }

  private _computeStatus(evt: ZPSEvent, now: Date): EventStatus {
    const start = new Date(evt.start_time);
    const end = new Date(evt.end_time);
    if (now < start) return 'upcoming';
    if (now >= start && now <= end) return 'active';
    return 'ended';
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd backend && npx jest test/events.service.spec.ts --no-coverage
```

Expected: `Tests: 7 passed, 7 total`

- [ ] **Step 6: Commit**

```bash
git add backend/src/events/event.types.ts backend/src/events/events.service.ts backend/test/events.service.spec.ts
git commit -m "feat: EventsService with in-memory CRUD + attendance"
```

---

## Task 4: Events Controller + Module

**Files:**
- Create: `backend/src/events/events.controller.ts`
- Create: `backend/src/events/events.module.ts`

- [ ] **Step 1: Create `backend/src/events/events.controller.ts`**

```typescript
import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Reflector } from '@nestjs/core';
import { CreateEventDto } from './event.types';
import { EventsService } from './events.service';

@Controller('events')
@UseGuards(JwtGuard)
export class EventsController {
  constructor(private readonly eventsService: EventsService) {}

  @Get()
  findAll(@Query('status') status?: string) {
    return this.eventsService.findAll(status);
  }

  @Post()
  @UseGuards(new RolesGuard(new Reflector()))
  @Roles('lead', 'admin')
  create(@Body() dto: CreateEventDto, @Req() req: any) {
    return this.eventsService.create(dto, req.user.id, req.user.role);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    const evt = this.eventsService.findById(id);
    if (!evt) return { error: 'Not found' };
    return evt;
  }

  @Post(':id/attend')
  attend(@Param('id') id: string, @Req() req: any) {
    return this.eventsService.attend(id, req.user.id);
  }

  @Get(':id/attendance')
  @UseGuards(new RolesGuard(new Reflector()))
  @Roles('lead', 'admin')
  attendance(@Param('id') id: string) {
    return { attendee_ids: this.eventsService.getAttendance(id) };
  }
}
```

- [ ] **Step 2: Create `backend/src/events/events.module.ts`**

```typescript
import { Module } from '@nestjs/common';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';

@Module({
  controllers: [EventsController],
  providers: [EventsService],
})
export class EventsModule {}
```

- [ ] **Step 3: Verify compile**

```bash
cd backend && npx tsc --noEmit
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add backend/src/events/events.controller.ts backend/src/events/events.module.ts
git commit -m "feat: Events REST controller + module (5A complete)"
```

---

## Task 5: Announcements Service + Controller

**Files:**
- Create: `backend/src/announcements/announcement.types.ts`
- Create: `backend/src/announcements/announcements.service.ts`
- Create: `backend/src/announcements/announcements.controller.ts`
- Create: `backend/src/announcements/announcements.module.ts`
- Create: `backend/test/announcements.service.spec.ts`

- [ ] **Step 1: Create `backend/src/announcements/announcement.types.ts`**

```typescript
export interface Announcement {
  id: string;
  title: string;
  body: string;
  author_id: string;
  created_at: string; // ISO datetime
  expires_at: string; // ISO datetime (created_at + 7 days)
}

export interface CreateAnnouncementDto {
  title: string;
  body: string;
}
```

- [ ] **Step 2: Write failing tests**

Create `backend/test/announcements.service.spec.ts`:

```typescript
import { Test } from '@nestjs/testing';
import { AnnouncementsService } from '../src/announcements/announcements.service';

describe('AnnouncementsService', () => {
  let service: AnnouncementsService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [AnnouncementsService],
    }).compile();
    service = module.get(AnnouncementsService);
  });

  it('creates announcement with 7-day expiry', () => {
    const ann = service.create({ title: 'Hello', body: 'World' }, 'admin1');
    expect(ann.id).toMatch(/^ann-/);
    expect(ann.title).toBe('Hello');
    const createdMs = new Date(ann.created_at).getTime();
    const expiresMs = new Date(ann.expires_at).getTime();
    expect(expiresMs - createdMs).toBeCloseTo(7 * 24 * 60 * 60 * 1000, -3);
  });

  it('findLatest returns max 3 non-expired announcements', () => {
    service.create({ title: 'A1', body: '' }, 'admin1');
    service.create({ title: 'A2', body: '' }, 'admin1');
    service.create({ title: 'A3', body: '' }, 'admin1');
    service.create({ title: 'A4', body: '' }, 'admin1');
    const latest = service.findLatest();
    expect(latest).toHaveLength(3);
  });

  it('findLatest excludes expired announcements', () => {
    const ann = service.create({ title: 'Old', body: '' }, 'admin1');
    // Manually expire it
    const stored = (service as any)._announcements.get(ann.id);
    stored.expires_at = new Date(Date.now() - 1000).toISOString();

    service.create({ title: 'Fresh', body: '' }, 'admin1');
    const latest = service.findLatest();
    expect(latest.map((a) => a.title)).not.toContain('Old');
    expect(latest.map((a) => a.title)).toContain('Fresh');
  });

  it('remove deletes the announcement', () => {
    const ann = service.create({ title: 'Delete me', body: '' }, 'admin1');
    service.remove(ann.id);
    expect(service.findLatest().map((a) => a.id)).not.toContain(ann.id);
  });
});
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd backend && npx jest test/announcements.service.spec.ts --no-coverage
```

Expected: FAIL — `Cannot find module '../src/announcements/announcements.service'`

- [ ] **Step 4: Create `backend/src/announcements/announcements.service.ts`**

```typescript
import { Injectable, NotFoundException } from '@nestjs/common';
import {
  Announcement,
  CreateAnnouncementDto,
} from './announcement.types';

const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;

@Injectable()
export class AnnouncementsService {
  private readonly _announcements: Map<string, Announcement> = new Map();
  private _counter = 0;

  create(dto: CreateAnnouncementDto, authorId: string): Announcement {
    const now = new Date();
    const id = `ann-${++this._counter}-${now.getTime()}`;
    const ann: Announcement = {
      id,
      title: dto.title,
      body: dto.body,
      author_id: authorId,
      created_at: now.toISOString(),
      expires_at: new Date(now.getTime() + SEVEN_DAYS_MS).toISOString(),
    };
    this._announcements.set(id, ann);
    return ann;
  }

  findLatest(limit = 3): Announcement[] {
    const now = new Date();
    return Array.from(this._announcements.values())
      .filter((a) => new Date(a.expires_at) > now)
      .sort(
        (a, b) =>
          new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
      )
      .slice(0, limit);
  }

  remove(id: string): void {
    if (!this._announcements.has(id)) {
      throw new NotFoundException(`Announcement ${id} not found`);
    }
    this._announcements.delete(id);
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd backend && npx jest test/announcements.service.spec.ts --no-coverage
```

Expected: `Tests: 4 passed, 4 total`

- [ ] **Step 6: Create `backend/src/announcements/announcements.controller.ts`**

```typescript
import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtGuard } from '../auth/jwt.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CreateAnnouncementDto } from './announcement.types';
import { AnnouncementsService } from './announcements.service';

@Controller('announcements')
@UseGuards(JwtGuard)
export class AnnouncementsController {
  constructor(private readonly announcementsService: AnnouncementsService) {}

  @Get()
  findLatest() {
    return this.announcementsService.findLatest();
  }

  @Post()
  @UseGuards(new RolesGuard(new Reflector()))
  @Roles('admin')
  create(@Body() dto: CreateAnnouncementDto, @Req() req: any) {
    return this.announcementsService.create(dto, req.user.id);
  }

  @Delete(':id')
  @UseGuards(new RolesGuard(new Reflector()))
  @Roles('admin')
  remove(@Param('id') id: string) {
    this.announcementsService.remove(id);
    return { ok: true };
  }
}
```

- [ ] **Step 7: Create `backend/src/announcements/announcements.module.ts`**

```typescript
import { Module } from '@nestjs/common';
import { AnnouncementsController } from './announcements.controller';
import { AnnouncementsService } from './announcements.service';

@Module({
  controllers: [AnnouncementsController],
  providers: [AnnouncementsService],
})
export class AnnouncementsModule {}
```

- [ ] **Step 8: Verify compile**

```bash
cd backend && npx tsc --noEmit
```

Expected: No errors.

- [ ] **Step 9: Commit**

```bash
git add backend/src/announcements/ backend/test/announcements.service.spec.ts
git commit -m "feat: AnnouncementsService + controller (5F complete)"
```

---

## Task 6: TriviaManager (Node.js WS Server)

**Files:**
- Create: `server/src/trivia-manager.js`
- Modify: `server/tests/server.test.js`

> **Context:** `TriviaManager` is instantiated once in `server.js`. It runs a game loop per zone. Questions are hardcoded. The WS server calls `triviaManager.start(zone, rooms)` when it gets a `trivia_start` message. The manager broadcasts to the zone using the existing `rooms` object (which has `broadcastToZone(zone, msg)`).

- [ ] **Step 1: Write failing tests for TriviaManager**

Add to `server/tests/server.test.js` (append at end):

```javascript
const TriviaManager = require('../src/trivia-manager');

describe('TriviaManager', () => {
  let manager;
  const mockBroadcast = jest.fn();
  const mockRooms = { broadcastToZone: mockBroadcast };

  beforeEach(() => {
    manager = new TriviaManager();
    mockBroadcast.mockClear();
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  test('TRIVIA_QUESTIONS has 10 items with correct structure', () => {
    const qs = TriviaManager.TRIVIA_QUESTIONS;
    expect(qs).toHaveLength(10);
    qs.forEach((q) => {
      expect(q).toHaveProperty('q');
      expect(q.options).toHaveLength(4);
      expect(typeof q.answer).toBe('number');
      expect(q.answer).toBeGreaterThanOrEqual(0);
      expect(q.answer).toBeLessThanOrEqual(3);
    });
  });

  test('start broadcasts trivia_start with first question to zone', () => {
    manager.start('engineering', mockRooms);
    expect(mockBroadcast).toHaveBeenCalledWith(
      'engineering',
      expect.objectContaining({ type: 'trivia_start' }),
    );
    const call = mockBroadcast.mock.calls[0][1];
    expect(call).toHaveProperty('question_index', 0);
    expect(call.options).toHaveLength(4);
  });

  test('submitAnswer records answer for player', () => {
    manager.start('engineering', mockRooms);
    manager.submitAnswer('engineering', 'player1', 0);
    const state = manager.getState('engineering');
    expect(state.answers.has('player1')).toBe(true);
  });

  test('submitAnswer ignores duplicate answer from same player', () => {
    manager.start('engineering', mockRooms);
    manager.submitAnswer('engineering', 'p1', 0);
    manager.submitAnswer('engineering', 'p1', 1);
    const state = manager.getState('engineering');
    expect(state.answers.get('p1')).toBe(0); // first answer kept
  });

  test('isActive returns true after start, false when no game', () => {
    expect(manager.isActive('engineering')).toBe(false);
    manager.start('engineering', mockRooms);
    expect(manager.isActive('engineering')).toBe(true);
  });

  test('timeout after 10s broadcasts trivia_answer with correct + scores', () => {
    manager.start('engineering', mockRooms);
    mockBroadcast.mockClear();
    manager.submitAnswer('engineering', 'p1', TriviaManager.TRIVIA_QUESTIONS[0].answer);
    jest.advanceTimersByTime(10000);
    const broadcastedMessages = mockBroadcast.mock.calls.map((c) => c[1]);
    const answerMsg = broadcastedMessages.find((m) => m.type === 'trivia_answer');
    expect(answerMsg).toBeDefined();
    expect(answerMsg.correct_index).toBe(TriviaManager.TRIVIA_QUESTIONS[0].answer);
    expect(answerMsg.scores).toHaveProperty('p1');
  });

  test('end broadcasts trivia_end with winner after all questions', () => {
    manager.start('engineering', mockRooms);
    // Fast-forward through all 10 questions (10s each + 3s reveal)
    for (let i = 0; i < 10; i++) {
      jest.advanceTimersByTime(10000); // question timeout
      jest.advanceTimersByTime(3000);  // reveal delay
    }
    const allMessages = mockBroadcast.mock.calls.map((c) => c[1]);
    const endMsg = allMessages.find((m) => m.type === 'trivia_end');
    expect(endMsg).toBeDefined();
    expect(endMsg).toHaveProperty('winner');
    expect(endMsg).toHaveProperty('scores');
  });
});
```

- [ ] **Step 2: Run to verify tests fail**

```bash
cd server && npx jest tests/server.test.js --no-coverage 2>&1 | tail -20
```

Expected: Failures in `TriviaManager` describe block — `Cannot find module '../src/trivia-manager'`

- [ ] **Step 3: Create `server/src/trivia-manager.js`**

```javascript
'use strict';

const TRIVIA_QUESTIONS = [
  {
    q: 'ZPS Game Studio là một phần của công ty nào?',
    options: ['VNG', 'VTC', 'FPT', 'Gameloft'],
    answer: 0,
  },
  {
    q: 'Godot Engine được viết bằng ngôn ngữ gì?',
    options: ['C++', 'Rust', 'Python', 'Java'],
    answer: 0,
  },
  {
    q: 'GDScript trong Godot 4 chạy trên runtime nào?',
    options: ['GDNative VM', 'Mono/.NET', 'GDScript VM (built-in)', 'V8'],
    answer: 2,
  },
  {
    q: 'Protocol nào ZPS World dùng để đồng bộ vị trí người chơi realtime?',
    options: ['HTTP polling', 'WebSocket', 'WebRTC', 'gRPC'],
    answer: 1,
  },
  {
    q: 'NestJS dựa trên framework nào phía dưới?',
    options: ['Fastify', 'Koa', 'Express (hoặc Fastify)', 'Hapi'],
    answer: 2,
  },
  {
    q: 'Trong Git, lệnh nào dùng để tạo nhánh mới và chuyển sang nhánh đó?',
    options: ['git branch new', 'git checkout -b new', 'git switch --create new', 'Cả B và C đều đúng'],
    answer: 3,
  },
  {
    q: 'Trong Godot 4, autoload singleton được khai báo ở đâu?',
    options: ['Project > Project Settings > Autoload', 'scripts/autoloads/autoload.cfg', 'Thêm vào scene Main', 'export var singleton'],
    answer: 0,
  },
  {
    q: 'Độ phân giải canvas mặc định ZPS World (theo Campus.gd) là?',
    options: ['1920×1080', '1280×720', '1193×896', '2048×2048'],
    answer: 2,
  },
  {
    q: 'ZPS World sử dụng bao nhiêu zone trong Campus.gd?',
    options: ['7', '8', '10', '12'],
    answer: 2,
  },
  {
    q: 'Trong NestJS, decorator nào dùng để đánh dấu một class là injectable service?',
    options: ['@Module()', '@Controller()', '@Injectable()', '@Service()'],
    answer: 2,
  },
];

const QUESTION_TIME_MS = 10000; // 10s per question
const REVEAL_DELAY_MS = 3000;   // 3s to show correct answer

class TriviaManager {
  constructor() {
    // zone -> game state
    this._games = new Map();
  }

  static get TRIVIA_QUESTIONS() {
    return TRIVIA_QUESTIONS;
  }

  /** Start a trivia game in a zone. No-op if already active. */
  start(zone, rooms) {
    if (this._games.has(zone)) return;

    const state = {
      zone,
      rooms,
      question_index: 0,
      scores: {}, // playerId -> points
      answers: new Map(), // playerId -> answerIndex (current question)
      timer: null,
    };
    this._games.set(zone, state);

    this._broadcastQuestion(state);
    state.timer = setTimeout(() => this._onQuestionTimeout(state), QUESTION_TIME_MS);
  }

  submitAnswer(zone, playerId, answerIndex) {
    const state = this._games.get(zone);
    if (!state) return;
    if (state.answers.has(playerId)) return; // already answered
    state.answers.set(playerId, answerIndex);
  }

  isActive(zone) {
    return this._games.has(zone);
  }

  getState(zone) {
    return this._games.get(zone) ?? null;
  }

  _broadcastQuestion(state) {
    const q = TRIVIA_QUESTIONS[state.question_index];
    state.rooms.broadcastToZone(state.zone, {
      type: 'trivia_start',
      question_index: state.question_index,
      total: TRIVIA_QUESTIONS.length,
      question: q.q,
      options: q.options,
      time_ms: QUESTION_TIME_MS,
    });
  }

  _onQuestionTimeout(state) {
    const q = TRIVIA_QUESTIONS[state.question_index];

    // Score players who answered correctly
    for (const [playerId, answerIndex] of state.answers) {
      if (answerIndex === q.answer) {
        state.scores[playerId] = (state.scores[playerId] ?? 0) + 1;
      }
    }

    // Broadcast correct answer + current scores
    state.rooms.broadcastToZone(state.zone, {
      type: 'trivia_answer',
      question_index: state.question_index,
      correct_index: q.answer,
      scores: { ...state.scores },
    });

    state.answers.clear();
    state.question_index += 1;

    if (state.question_index >= TRIVIA_QUESTIONS.length) {
      // Schedule end after reveal delay
      state.timer = setTimeout(() => this._endGame(state), REVEAL_DELAY_MS);
    } else {
      // Next question after reveal delay
      state.timer = setTimeout(() => {
        this._broadcastQuestion(state);
        state.timer = setTimeout(() => this._onQuestionTimeout(state), QUESTION_TIME_MS);
      }, REVEAL_DELAY_MS);
    }
  }

  _endGame(state) {
    // Determine winner (highest score; empty string if no one scored)
    let winner = '';
    let topScore = -1;
    for (const [pid, score] of Object.entries(state.scores)) {
      if (score > topScore) { topScore = score; winner = pid; }
    }

    state.rooms.broadcastToZone(state.zone, {
      type: 'trivia_end',
      winner,
      scores: { ...state.scores },
    });

    this._games.delete(state.zone);
  }
}

module.exports = TriviaManager;
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd server && npx jest tests/server.test.js --no-coverage
```

Expected: All TriviaManager tests pass. Existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add server/src/trivia-manager.js server/tests/server.test.js
git commit -m "feat: TriviaManager with 10 ZPS questions, zone-scoped game loop"
```

---

## Task 7: Extend server.js — Trivia + Reaction Quiz WS Messages

**Files:**
- Modify: `server/src/server.js`

> **Context:** Add `TriviaManager` + a simple in-memory `ReactionManager` to `server.js`. Both are keyed by zone. Reaction Quiz: Lead sends `reaction_start` → server broadcasts countdown → first `reaction_press` wins.

- [ ] **Step 1: Read current `server.js` and add trivia + reaction handling**

Replace the full content of `server/src/server.js` with:

```javascript
const { WebSocketServer } = require('ws');
const PlayerRegistry = require('./player-registry');
const RoomManager = require('./room-manager');
const TriviaManager = require('./trivia-manager');

const PORT = process.env.PORT || 3001;
const TICK_MS = 50; // 20Hz position broadcast

const registry = new PlayerRegistry();
const rooms = new RoomManager(registry);
const trivia = new TriviaManager();

// Reaction Quiz state: zone -> { active, winner, countdownTimer }
const reactionGames = new Map();

const wss = new WebSocketServer({ port: PORT });

wss.on('connection', (ws) => {
  let playerId = null;

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }

    // ── Presence ──────────────────────────────────────────────────────────
    if (msg.type === 'player_join') {
      playerId = msg.id;
      registry.add(playerId, { ws, x: msg.x, y: msg.y, avatar: msg.avatar, zone: msg.zone || 'main' });
      rooms.join(playerId, msg.zone || 'main');
      rooms.broadcast(msg.zone || 'main', { type: 'player_joined', id: playerId, x: msg.x, y: msg.y, avatar: msg.avatar }, playerId);
      ws.send(JSON.stringify({ type: 'roster', players: registry.getRoster(playerId) }));
    }

    if (msg.type === 'move' && playerId) {
      registry.updatePosition(playerId, msg.x, msg.y);
    }

    if (msg.type === 'chat' && playerId) {
      const player = registry.get(playerId);
      rooms.broadcast(player.zone, { type: 'chat', from: playerId, text: msg.text, ts: Date.now() });
    }

    if (msg.type === 'emote' && playerId) {
      const player = registry.get(playerId);
      rooms.broadcast(player.zone, { type: 'emote', from: playerId, emote: msg.emote });
    }

    if (msg.type === 'status' && playerId) {
      registry.updateStatus(playerId, msg.status, msg.message || '');
      const player = registry.get(playerId);
      rooms.broadcast(player.zone, { type: 'status_changed', id: playerId, status: msg.status, message: msg.message || '' });
    }

    // ── Trivia ────────────────────────────────────────────────────────────
    if (msg.type === 'trivia_start' && playerId) {
      const player = registry.get(playerId);
      if (!player) return;
      if (!trivia.isActive(player.zone)) {
        trivia.start(player.zone, rooms);
      }
    }

    if (msg.type === 'trivia_answer' && playerId) {
      const player = registry.get(playerId);
      if (!player) return;
      trivia.submitAnswer(player.zone, playerId, msg.answer_index);
    }

    // ── Reaction Quiz ─────────────────────────────────────────────────────
    if (msg.type === 'reaction_start' && playerId) {
      const player = registry.get(playerId);
      if (!player) return;
      const zone = player.zone;
      if (reactionGames.get(zone)?.active) return; // already running

      const game = { active: false, winner: null, countdownTimer: null };
      reactionGames.set(zone, game);

      // Broadcast countdown sequence: 3, 2, 1, GO
      let count = 3;
      rooms.broadcastToZone(zone, { type: 'reaction_countdown', count });
      game.countdownTimer = setInterval(() => {
        count -= 1;
        if (count > 0) {
          rooms.broadcastToZone(zone, { type: 'reaction_countdown', count });
        } else {
          clearInterval(game.countdownTimer);
          game.active = true;
          rooms.broadcastToZone(zone, { type: 'reaction_go' });
          // Auto-end after 5s if nobody presses
          game.countdownTimer = setTimeout(() => {
            if (!game.winner) {
              rooms.broadcastToZone(zone, { type: 'reaction_end', winner: '', message: 'Nobody pressed in time!' });
              reactionGames.delete(zone);
            }
          }, 5000);
        }
      }, 1000);
    }

    if (msg.type === 'reaction_press' && playerId) {
      const player = registry.get(playerId);
      if (!player) return;
      const zone = player.zone;
      const game = reactionGames.get(zone);
      if (!game?.active || game.winner) return; // not active or already won

      game.winner = playerId;
      clearTimeout(game.countdownTimer);
      rooms.broadcastToZone(zone, {
        type: 'reaction_end',
        winner: playerId,
        message: `${playerId} wins!`,
      });
      reactionGames.delete(zone);
    }
  });

  ws.on('close', () => {
    if (!playerId) return;
    const player = registry.get(playerId);
    if (player) {
      rooms.broadcast(player.zone, { type: 'player_left', id: playerId });
      rooms.leave(playerId, player.zone);
    }
    registry.remove(playerId);
  });

  ws.on('error', () => {
    if (playerId) registry.remove(playerId);
  });
});

// Position broadcast tick
setInterval(() => {
  for (const [zone, playerIds] of rooms.getAllZones()) {
    if (playerIds.size === 0) continue;
    const positions = [];
    for (const pid of playerIds) {
      const p = registry.get(pid);
      if (p) positions.push({ id: pid, x: p.x, y: p.y });
    }
    if (positions.length === 0) continue;
    rooms.broadcastToZone(zone, { type: 'positions', data: positions });
  }
}, TICK_MS);

console.log(`[ZPS World Server] Listening on ws://localhost:${PORT}`);
module.exports = { wss, registry, rooms, trivia, reactionGames };
```

- [ ] **Step 2: Run all server tests**

```bash
cd server && npx jest --no-coverage
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add server/src/server.js
git commit -m "feat: add trivia_start/answer + reaction_start/press WS handlers"
```

---

## Task 8: PlayerData — Add `player_role` Field

**Files:**
- Modify: `scripts/autoloads/PlayerData.gd`

> **Context:** The backend token encodes role. In-game, `PlayerData.player_role` determines whether the EventBoard shows the "Create Event" button and whether the player can trigger trivia. The default is `"member"`.

- [ ] **Step 1: Add `player_role` after `zps_class` declaration**

In `scripts/autoloads/PlayerData.gd`, after line:
```gdscript
var zps_class: String = "artisan"
```

Add:
```gdscript
# ── Role (determines access to event/trivia creation) ──
# Values: "member" | "lead" | "admin"
var player_role: String = "member"
```

- [ ] **Step 2: Add save/load for `player_role` in `save_data()` and `load_data()`**

In `save_data()`, after `config.set_value("identity", "zps_class", zps_class)`:
```gdscript
	config.set_value("identity", "player_role", player_role)
```

In `load_data()`, after `zps_class = config.get_value("identity", "zps_class", zps_class)`:
```gdscript
	player_role = config.get_value("identity", "player_role", player_role)
```

- [ ] **Step 3: Add `make_auth_token()` helper (bottom of file, before `_first_run_setup`)**

```gdscript
## Returns a base64-encoded JWT-style token for REST API calls.
## Format matches backend JwtGuard: base64({"id":"...","role":"..."})
func make_auth_token() -> String:
	var payload := JSON.stringify({ "id": player_id, "role": player_role })
	return Marshalls.utf8_to_base64(payload)
```

- [ ] **Step 4: Verify no GDScript errors**

Open Godot editor → check Output panel for parse errors on `PlayerData.gd`. Alternatively run:
```bash
cd /path/to/ZPSWorld && godot --headless --quit 2>&1 | grep "PlayerData"
```

Expected: No errors mentioning PlayerData.

- [ ] **Step 5: Commit**

```bash
git add scripts/autoloads/PlayerData.gd
git commit -m "feat: add player_role field + make_auth_token() to PlayerData"
```

---

## Task 9: NetworkManager — Trivia + Reaction Signals

**Files:**
- Modify: `scripts/autoloads/NetworkManager.gd`

- [ ] **Step 1: Add signals at the top of `NetworkManager.gd` (after existing signals)**

```gdscript
# ── Trivia signals ──
signal trivia_started(question_index: int, total: int, question: String, options: Array, time_ms: int)
signal trivia_answer_revealed(question_index: int, correct_index: int, scores: Dictionary)
signal trivia_ended(winner: String, scores: Dictionary)

# ── Reaction Quiz signals ──
signal reaction_countdown(count: int)
signal reaction_go()
signal reaction_ended(winner: String, message: String)
```

- [ ] **Step 2: Add send helpers (after `send_status` function)**

```gdscript
func send_trivia_start() -> void:
	_send({ "type": "trivia_start" })

func send_trivia_answer(answer_index: int) -> void:
	_send({ "type": "trivia_answer", "answer_index": answer_index })

func send_reaction_start() -> void:
	_send({ "type": "reaction_start" })

func send_reaction_press() -> void:
	_send({ "type": "reaction_press" })
```

- [ ] **Step 3: Add match cases in `_handle_message()` (inside the `match` block)**

```gdscript
		"trivia_start":
			trivia_started.emit(
				msg.get("question_index", 0),
				msg.get("total", 10),
				msg.get("question", ""),
				msg.get("options", []),
				msg.get("time_ms", 10000)
			)
		"trivia_answer":
			trivia_answer_revealed.emit(
				msg.get("question_index", 0),
				msg.get("correct_index", 0),
				msg.get("scores", {})
			)
		"trivia_end":
			trivia_ended.emit(msg.get("winner", ""), msg.get("scores", {}))
		"reaction_countdown":
			reaction_countdown.emit(msg.get("count", 3))
		"reaction_go":
			reaction_go.emit()
		"reaction_end":
			reaction_ended.emit(msg.get("winner", ""), msg.get("message", ""))
```

- [ ] **Step 4: Commit**

```bash
git add scripts/autoloads/NetworkManager.gd
git commit -m "feat: add trivia + reaction signals and send helpers to NetworkManager"
```

---

## Task 10: EventBoard UI (Godot)

**Files:**
- Create: `scripts/ui/EventBoard.gd`

> **Context:** `EventBoard` is a `CanvasLayer`-child `Control` panel. It is created programmatically in `HUD.gd` (Task 12). It polls `GET /events` on open and shows a list of events with countdown timers. `HttpManager` is an existing autoload; its `get_json(url, headers, callback)` method is used for REST calls.

- [ ] **Step 1: Create `scripts/ui/EventBoard.gd`**

```gdscript
## EventBoard.gd
## Panel showing upcoming/active events. Toggled by V key from HUD.
## Fetches from GET /events via HttpManager autoload.

extends Control

const BACKEND_URL := "http://localhost:3002"

var _list_container: VBoxContainer = null
var _title_label: Label = null
var _status_label: Label = null
var _events_cache: Array = []
var _countdown_timer: float = 0.0

signal attend_pressed(event_id: String)

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	custom_minimum_size = Vector2(420, 520)

	var bg = PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.14, 0.96)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	bg.add_theme_stylebox_override("panel", style)

	var col = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)

	# Title row
	var title_row = HBoxContainer.new()
	_title_label = _make_label("📅  Events", 16, Color(0.85, 0.90, 1.0), true)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	close_btn.pressed.connect(func(): visible = false)
	title_row.add_child(close_btn)
	col.add_child(title_row)
	col.add_child(HSeparator.new())

	# Status
	_status_label = _make_label("Loading...", 10, Color(0.5, 0.6, 0.7))
	col.add_child(_status_label)

	# Scrollable event list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", 6)
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_container)
	col.add_child(scroll)

	bg.add_child(col)
	add_child(bg)

func open() -> void:
	visible = true
	_fetch_events()

func _fetch_events() -> void:
	_status_label.text = "Loading..."
	var token = PlayerData.make_auth_token()
	var headers = ["Authorization: Bearer " + token]
	HttpManager.get_json(BACKEND_URL + "/events", headers, _on_events_loaded)

func _on_events_loaded(result: Dictionary) -> void:
	if result.get("error", false):
		_status_label.text = "Failed to load events."
		return
	_events_cache = result.get("data", [])
	_status_label.text = "%d event(s) found." % _events_cache.size()
	_rebuild_list()

func _rebuild_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()
	if _events_cache.is_empty():
		_list_container.add_child(_make_label("No upcoming events.", 11, Color(0.6, 0.6, 0.7)))
		return
	for evt in _events_cache:
		_list_container.add_child(_build_event_card(evt))

func _build_event_card(evt: Dictionary) -> Control:
	var card = PanelContainer.new()
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.10, 0.10, 0.20, 0.90)
	cs.set_corner_radius_all(6)
	cs.set_border_width_all(1)
	var status: String = evt.get("status", "upcoming")
	cs.border_color = Color(0.2, 0.7, 0.4) if status == "active" else Color(0.25, 0.25, 0.50)
	cs.content_margin_left = 10
	cs.content_margin_right = 10
	cs.content_margin_top = 8
	cs.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", cs)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	# Title + type badge row
	var title_row = HBoxContainer.new()
	var evt_title = _make_label(evt.get("title", "Untitled"), 12, Color.WHITE, true)
	evt_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(evt_title)
	var type_badge = _make_label(evt.get("type", "").replace("_", " "), 9, Color(0.7, 0.85, 0.7))
	title_row.add_child(type_badge)
	vbox.add_child(title_row)

	# Location
	vbox.add_child(_make_label("📍 " + evt.get("location_zone", "").replace("_", " "), 9, Color(0.65, 0.75, 0.90)))

	# Time
	var start_str: String = _format_time(evt.get("start_time", ""))
	var end_str: String = _format_time(evt.get("end_time", ""))
	vbox.add_child(_make_label("🕐 %s – %s" % [start_str, end_str], 9, Color(0.75, 0.75, 0.85)))

	# Description
	if evt.get("description", "") != "":
		var desc = _make_label(evt.get("description", ""), 9, Color(0.70, 0.70, 0.80))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

	# Attendee count
	var attendees: Array = evt.get("attendee_ids", [])
	var max_att = evt.get("max_attendees", null)
	var count_txt := "%d attendees" % attendees.size()
	if max_att != null:
		count_txt += " / %d max" % max_att
	vbox.add_child(_make_label("👥 " + count_txt, 9, Color(0.65, 0.80, 0.65)))

	# Status badge + Attend button row
	var action_row = HBoxContainer.new()
	var status_lbl = _make_label(status.to_upper(), 9, _status_color(status), true)
	status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(status_lbl)

	if status != "ended":
		var attend_btn = Button.new()
		attend_btn.text = "Attend"
		attend_btn.custom_minimum_size = Vector2(70, 24)
		var bs = StyleBoxFlat.new()
		bs.bg_color = Color(0.15, 0.40, 0.70, 0.90)
		bs.set_corner_radius_all(4)
		attend_btn.add_theme_stylebox_override("normal", bs)
		attend_btn.add_theme_color_override("font_color", Color.WHITE)
		attend_btn.add_theme_font_size_override("font_size", 10)
		var event_id: String = evt.get("id", "")
		attend_btn.pressed.connect(func(): _on_attend(event_id))
		action_row.add_child(attend_btn)
	vbox.add_child(action_row)

	card.add_child(vbox)
	return card

func _on_attend(event_id: String) -> void:
	var token = PlayerData.make_auth_token()
	var headers = ["Authorization: Bearer " + token, "Content-Type: application/json"]
	HttpManager.post_json(BACKEND_URL + "/events/" + event_id + "/attend", {}, headers,
		func(result: Dictionary):
			if result.get("error", false):
				GameManager.notify("Failed to register: " + str(result.get("message", "")), "error")
			else:
				GameManager.notify("Registered for event!", "success")
				_fetch_events()
	)
	attend_pressed.emit(event_id)

func _format_time(iso: String) -> String:
	if iso == "": return "?"
	# e.g. "2026-04-10T09:00:00.000Z" → "09:00 10/04"
	var parts = iso.split("T")
	if parts.size() < 2: return iso
	var date_parts = parts[0].split("-")
	var time_part = parts[1].substr(0, 5)
	if date_parts.size() < 3: return time_part
	return "%s %s/%s" % [time_part, date_parts[2], date_parts[1]]

func _status_color(status: String) -> Color:
	match status:
		"active":   return Color(0.3, 0.9, 0.4)
		"ended":    return Color(0.5, 0.5, 0.5)
		_:          return Color(0.7, 0.7, 1.0)

func _make_label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if bold:
		lbl.add_theme_font_size_override("font_size", size + 1)
	return lbl
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/EventBoard.gd
git commit -m "feat: EventBoard panel with event list, countdown display, attend button"
```

---

## Task 11: EventCreatePanel UI (Godot)

**Files:**
- Create: `scripts/ui/EventCreatePanel.gd`

> **Context:** Shown only when `PlayerData.player_role` is `"lead"` or `"admin"`. Opened from HUD EventBoard panel (a "Create Event" button visible only to leads/admins).

- [ ] **Step 1: Create `scripts/ui/EventCreatePanel.gd`**

```gdscript
## EventCreatePanel.gd
## Form for Lead/Admin to create a new event. Hidden for members.
## Opened from EventBoard. POSTs to /events via HttpManager.

extends Control

const BACKEND_URL := "http://localhost:3002"

# Zone IDs must match Campus.gd _zones keys
const ZONE_OPTIONS: Array = [
	"engineering", "design_studio", "amenity", "library",
	"collab_hub", "facilities", "data_lab", "reception",
	"innovation_corner", "marketing_hub",
]

var _title_edit: LineEdit = null
var _desc_edit: TextEdit = null
var _type_option: OptionButton = null
var _zone_option: OptionButton = null
var _start_edit: LineEdit = null
var _end_edit: LineEdit = null
var _max_edit: LineEdit = null
var _submit_btn: Button = null
var _error_label: Label = null

signal event_created()

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	custom_minimum_size = Vector2(400, 500)

	var bg = PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.16, 0.97)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.35, 0.65)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	bg.add_theme_stylebox_override("panel", style)

	var col = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)

	# Header
	var header_row = HBoxContainer.new()
	var hdr = Label.new()
	hdr.text = "✏️  Create Event"
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(hdr)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	close_btn.pressed.connect(func(): visible = false)
	header_row.add_child(close_btn)
	col.add_child(header_row)
	col.add_child(HSeparator.new())

	# Title
	col.add_child(_field_label("Title *"))
	_title_edit = LineEdit.new()
	_title_edit.placeholder_text = "Event title"
	col.add_child(_title_edit)

	# Description
	col.add_child(_field_label("Description"))
	_desc_edit = TextEdit.new()
	_desc_edit.custom_minimum_size = Vector2(0, 60)
	_desc_edit.placeholder_text = "Optional description"
	col.add_child(_desc_edit)

	# Type
	col.add_child(_field_label("Type *"))
	_type_option = OptionButton.new()
	_type_option.add_item("Official", 0)
	_type_option.add_item("Team Official", 1)
	_type_option.add_item("Non-Official", 2)
	col.add_child(_type_option)

	# Location zone
	col.add_child(_field_label("Location Zone *"))
	_zone_option = OptionButton.new()
	for z in ZONE_OPTIONS:
		_zone_option.add_item(z.replace("_", " ").capitalize())
	col.add_child(_zone_option)

	# Start time
	col.add_child(_field_label("Start Time (ISO) *"))
	_start_edit = LineEdit.new()
	_start_edit.placeholder_text = "2026-04-10T09:00:00.000Z"
	col.add_child(_start_edit)

	# End time
	col.add_child(_field_label("End Time (ISO) *"))
	_end_edit = LineEdit.new()
	_end_edit.placeholder_text = "2026-04-10T10:00:00.000Z"
	col.add_child(_end_edit)

	# Max attendees
	col.add_child(_field_label("Max Attendees (blank = unlimited)"))
	_max_edit = LineEdit.new()
	_max_edit.placeholder_text = "50"
	col.add_child(_max_edit)

	# Error label
	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_error_label.add_theme_font_size_override("font_size", 10)
	_error_label.text = ""
	col.add_child(_error_label)

	# Submit
	_submit_btn = Button.new()
	_submit_btn.text = "Create Event"
	var ss = StyleBoxFlat.new()
	ss.bg_color = Color(0.15, 0.45, 0.75, 0.90)
	ss.set_corner_radius_all(5)
	_submit_btn.add_theme_stylebox_override("normal", ss)
	_submit_btn.add_theme_color_override("font_color", Color.WHITE)
	_submit_btn.pressed.connect(_on_submit)
	col.add_child(_submit_btn)

	bg.add_child(col)
	add_child(bg)

func _on_submit() -> void:
	_error_label.text = ""
	var title := _title_edit.text.strip_edges()
	if title == "":
		_error_label.text = "Title is required."
		return
	if _start_edit.text.strip_edges() == "" or _end_edit.text.strip_edges() == "":
		_error_label.text = "Start and End times are required (ISO format)."
		return

	var type_map := ["official", "team_official", "non_official"]
	var max_attendees = null
	var max_text := _max_edit.text.strip_edges()
	if max_text != "" and max_text.is_valid_int():
		max_attendees = max_text.to_int()

	var payload := {
		"title": title,
		"description": _desc_edit.text.strip_edges(),
		"type": type_map[_type_option.selected],
		"location_zone": ZONE_OPTIONS[_zone_option.selected],
		"start_time": _start_edit.text.strip_edges(),
		"end_time": _end_edit.text.strip_edges(),
		"max_attendees": max_attendees,
	}

	_submit_btn.disabled = true
	var token = PlayerData.make_auth_token()
	var headers = ["Authorization: Bearer " + token, "Content-Type: application/json"]
	HttpManager.post_json(BACKEND_URL + "/events", payload, headers,
		func(result: Dictionary):
			_submit_btn.disabled = false
			if result.get("error", false):
				_error_label.text = "Error: " + str(result.get("message", "Unknown error"))
			else:
				GameManager.notify("Event created!", "success")
				event_created.emit()
				visible = false
				_clear_form()
	)

func _clear_form() -> void:
	_title_edit.text = ""
	_desc_edit.text = ""
	_start_edit.text = ""
	_end_edit.text = ""
	_max_edit.text = ""
	_error_label.text = ""

func _field_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.90))
	return lbl
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/EventCreatePanel.gd
git commit -m "feat: EventCreatePanel form for lead/admin role"
```

---

## Task 12: AnnouncementBoard UI (Godot)

**Files:**
- Create: `scripts/ui/AnnouncementBoard.gd`

- [ ] **Step 1: Create `scripts/ui/AnnouncementBoard.gd`**

```gdscript
## AnnouncementBoard.gd
## Shows 3 latest announcements from GET /announcements.
## Displayed at Reception zone or opened from HUD.

extends Control

const BACKEND_URL := "http://localhost:3002"

var _list_container: VBoxContainer = null
var _status_label: Label = null

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	custom_minimum_size = Vector2(380, 340)

	var bg = PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.14, 0.96)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.35, 0.20)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	bg.add_theme_stylebox_override("panel", style)

	var col = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)

	# Header row
	var header_row = HBoxContainer.new()
	var hdr = Label.new()
	hdr.text = "📢  Announcements"
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.60))
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(hdr)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	close_btn.pressed.connect(func(): visible = false)
	header_row.add_child(close_btn)
	col.add_child(header_row)
	col.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	_status_label.text = "Loading..."
	col.add_child(_status_label)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", 8)
	_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_list_container)

	bg.add_child(col)
	add_child(bg)

func open() -> void:
	visible = true
	_fetch()

func _fetch() -> void:
	_status_label.text = "Loading..."
	var token = PlayerData.make_auth_token()
	var headers = ["Authorization: Bearer " + token]
	HttpManager.get_json(BACKEND_URL + "/announcements", headers, _on_loaded)

func _on_loaded(result: Dictionary) -> void:
	if result.get("error", false):
		_status_label.text = "Could not load announcements."
		return
	var items: Array = result.get("data", [])
	_status_label.text = "%d announcement(s)." % items.size()
	_rebuild(items)

func _rebuild(items: Array) -> void:
	for child in _list_container.get_children():
		child.queue_free()
	if items.is_empty():
		var empty = Label.new()
		empty.text = "No announcements."
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_list_container.add_child(empty)
		return
	for item in items:
		_list_container.add_child(_build_card(item))

func _build_card(item: Dictionary) -> Control:
	var card = PanelContainer.new()
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.12, 0.10, 0.06, 0.90)
	cs.set_corner_radius_all(6)
	cs.set_border_width_all(1)
	cs.border_color = Color(0.50, 0.38, 0.18)
	cs.content_margin_left = 10
	cs.content_margin_right = 10
	cs.content_margin_top = 8
	cs.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", cs)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	var title = Label.new()
	title.text = item.get("title", "Announcement")
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.60))
	vbox.add_child(title)

	var body = Label.new()
	body.text = item.get("body", "")
	body.add_theme_font_size_override("font_size", 10)
	body.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var created = Label.new()
	created.text = _format_date(item.get("created_at", ""))
	created.add_theme_font_size_override("font_size", 9)
	created.add_theme_color_override("font_color", Color(0.5, 0.50, 0.45))
	vbox.add_child(created)

	card.add_child(vbox)
	return card

func _format_date(iso: String) -> String:
	if iso == "": return ""
	var parts = iso.split("T")
	if parts.size() < 2: return iso
	return parts[0]
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/AnnouncementBoard.gd
git commit -m "feat: AnnouncementBoard panel showing 3 latest announcements"
```

---

## Task 13: TriviaPanel UI (Godot)

**Files:**
- Create: `scripts/ui/TriviaPanel.gd`

> **Context:** Auto-pops up when `NetworkManager.trivia_started` fires. Displays question + A/B/C/D buttons. On answer reveal (`trivia_answer_revealed`) highlights correct answer and shows scores. On `trivia_ended` shows winner banner then auto-closes after 5s.

- [ ] **Step 1: Create `scripts/ui/TriviaPanel.gd`**

```gdscript
## TriviaPanel.gd
## Auto-popup during ZPS Trivia minigame.
## Connects to NetworkManager trivia signals.

extends Control

var _question_label: Label = null
var _option_buttons: Array[Button] = []
var _score_label: Label = null
var _timer_bar: ProgressBar = null
var _feedback_label: Label = null
var _winner_label: Label = null

var _answered: bool = false
var _time_ms: float = 10000.0
var _elapsed_ms: float = 0.0
var _timer_running: bool = false
var _auto_close_timer: float = 0.0
var _auto_closing: bool = false

func _ready() -> void:
	_build_ui()
	visible = false
	NetworkManager.trivia_started.connect(_on_trivia_started)
	NetworkManager.trivia_answer_revealed.connect(_on_answer_revealed)
	NetworkManager.trivia_ended.connect(_on_trivia_ended)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(500, 360)
	offset_left = -250
	offset_right = 250
	offset_top = -180
	offset_bottom = 180

	var bg = PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.18, 0.97)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.4, 0.9)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	bg.add_theme_stylebox_override("panel", style)

	var col = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)

	# Header
	var hdr = Label.new()
	hdr.text = "🎯  ZPS Trivia"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 17)
	hdr.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	col.add_child(hdr)

	# Timer bar
	_timer_bar = ProgressBar.new()
	_timer_bar.min_value = 0
	_timer_bar.max_value = 100
	_timer_bar.value = 100
	_timer_bar.custom_minimum_size = Vector2(0, 8)
	_timer_bar.show_percentage = false
	col.add_child(_timer_bar)

	# Question
	_question_label = Label.new()
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_label.add_theme_font_size_override("font_size", 14)
	_question_label.add_theme_color_override("font_color", Color.WHITE)
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question_label.text = "..."
	col.add_child(_question_label)

	# Option buttons grid (2×2)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var option_labels := ["A", "B", "C", "D"]
	for i in range(4):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 44)
		btn.text = "%s. ..." % option_labels[i]
		var bs = StyleBoxFlat.new()
		bs.bg_color = Color(0.12, 0.12, 0.28, 0.90)
		bs.set_corner_radius_all(6)
		bs.set_border_width_all(1)
		bs.border_color = Color(0.35, 0.35, 0.60)
		btn.add_theme_stylebox_override("normal", bs)
		btn.add_theme_color_override("font_color", Color(0.90, 0.90, 1.0))
		btn.add_theme_font_size_override("font_size", 11)
		var idx := i
		btn.pressed.connect(func(): _on_option_pressed(idx))
		grid.add_child(btn)
		_option_buttons.append(btn)
	col.add_child(grid)

	# Feedback label (shows "Correct!" / "Wrong!" after reveal)
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 13)
	_feedback_label.text = ""
	col.add_child(_feedback_label)

	# Score label
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 11)
	_score_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	_score_label.text = ""
	col.add_child(_score_label)

	# Winner label (shown at end)
	_winner_label = Label.new()
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_label.add_theme_font_size_override("font_size", 15)
	_winner_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_winner_label.text = ""
	_winner_label.visible = false
	col.add_child(_winner_label)

	bg.add_child(col)
	add_child(bg)

func _process(delta: float) -> void:
	if _timer_running:
		_elapsed_ms += delta * 1000.0
		var pct := clamp(1.0 - (_elapsed_ms / _time_ms), 0.0, 1.0)
		_timer_bar.value = pct * 100.0
		if _elapsed_ms >= _time_ms:
			_timer_running = false

	if _auto_closing:
		_auto_close_timer -= delta
		if _auto_close_timer <= 0.0:
			_auto_closing = false
			visible = false

func _on_trivia_started(question_index: int, total: int, question: String, options: Array, time_ms: int) -> void:
	visible = true
	_answered = false
	_feedback_label.text = ""
	_feedback_label.add_theme_color_override("font_color", Color.WHITE)
	_winner_label.visible = false
	_winner_label.text = ""
	_score_label.text = "Question %d / %d" % [question_index + 1, total]
	_question_label.text = question
	_time_ms = float(time_ms)
	_elapsed_ms = 0.0
	_timer_running = true
	_timer_bar.value = 100.0

	var option_labels := ["A", "B", "C", "D"]
	for i in range(min(options.size(), 4)):
		_option_buttons[i].text = "%s. %s" % [option_labels[i], options[i]]
		_option_buttons[i].disabled = false
		var bs = StyleBoxFlat.new()
		bs.bg_color = Color(0.12, 0.12, 0.28, 0.90)
		bs.set_corner_radius_all(6)
		bs.set_border_width_all(1)
		bs.border_color = Color(0.35, 0.35, 0.60)
		_option_buttons[i].add_theme_stylebox_override("normal", bs)

func _on_option_pressed(index: int) -> void:
	if _answered: return
	_answered = true
	_timer_running = false
	for btn in _option_buttons:
		btn.disabled = true
	NetworkManager.send_trivia_answer(index)

func _on_answer_revealed(question_index: int, correct_index: int, scores: Dictionary) -> void:
	_timer_running = false
	for i in range(4):
		var btn = _option_buttons[i]
		btn.disabled = true
		if i == correct_index:
			var bs = StyleBoxFlat.new()
			bs.bg_color = Color(0.10, 0.55, 0.20, 0.95)
			bs.set_corner_radius_all(6)
			bs.set_border_width_all(2)
			bs.border_color = Color(0.3, 0.9, 0.4)
			btn.add_theme_stylebox_override("normal", bs)

	var my_id := PlayerData.player_id
	var my_score: int = scores.get(my_id, 0)
	_score_label.text = "Your score: %d pts" % my_score

	# If player chose the correct one
	if _answered:
		# Reconstruct which button was pressed — check which is highlighted correct and compare
		pass  # feedback is shown via button highlight

func _on_trivia_ended(winner: String, scores: Dictionary) -> void:
	_timer_running = false
	_winner_label.visible = true
	if winner == PlayerData.player_id:
		_winner_label.text = "🏆  You won! Congratulations!"
		_winner_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	elif winner == "":
		_winner_label.text = "Game over — no winner!"
	else:
		_winner_label.text = "🏆  Winner: %s" % winner

	# Build score list
	var score_lines := PackedStringArray()
	for pid in scores:
		score_lines.append("%s: %d" % [pid, scores[pid]])
	_score_label.text = " | ".join(score_lines)

	# Auto-close after 5s
	_auto_closing = true
	_auto_close_timer = 5.0
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/TriviaPanel.gd
git commit -m "feat: TriviaPanel auto-popup with Q&A, timer bar, score display"
```

---

## Task 14: ReactionQuizPanel UI (Godot)

**Files:**
- Create: `scripts/ui/ReactionQuizPanel.gd`

- [ ] **Step 1: Create `scripts/ui/ReactionQuizPanel.gd`**

```gdscript
## ReactionQuizPanel.gd
## Auto-popup for Reaction Quiz minigame.
## Waits for reaction_go signal then listens for Space key.

extends Control

var _status_label: Label = null
var _go_label: Label = null
var _result_label: Label = null

var _game_active: bool = false
var _pressed: bool = false
var _auto_close_timer: float = 0.0
var _auto_closing: bool = false

func _ready() -> void:
	_build_ui()
	visible = false
	NetworkManager.reaction_countdown.connect(_on_countdown)
	NetworkManager.reaction_go.connect(_on_go)
	NetworkManager.reaction_ended.connect(_on_ended)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(380, 260)
	offset_left = -190
	offset_right = 190
	offset_top = -130
	offset_bottom = 130

	var bg = PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.06, 0.97)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.8, 0.4)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	bg.add_theme_stylebox_override("panel", style)

	var col = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var hdr = Label.new()
	hdr.text = "⚡  Reaction Quiz"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 18)
	hdr.add_theme_color_override("font_color", Color(0.6, 1.0, 0.5))
	col.add_child(hdr)

	_status_label = Label.new()
	_status_label.text = "Get ready..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	col.add_child(_status_label)

	_go_label = Label.new()
	_go_label.text = ""
	_go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_label.add_theme_font_size_override("font_size", 52)
	_go_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	col.add_child(_go_label)

	_result_label = Label.new()
	_result_label.text = ""
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 14)
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	col.add_child(_result_label)

	bg.add_child(col)
	add_child(bg)

func _process(delta: float) -> void:
	if _auto_closing:
		_auto_close_timer -= delta
		if _auto_close_timer <= 0.0:
			_auto_closing = false
			visible = false
			_reset()

func _input(event: InputEvent) -> void:
	if not _game_active or _pressed: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_pressed = true
			_game_active = false
			NetworkManager.send_reaction_press()

func _on_countdown(count: int) -> void:
	visible = true
	_game_active = false
	_pressed = false
	_result_label.text = ""
	_go_label.text = str(count)
	_go_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	_status_label.text = "Get ready..."

func _on_go() -> void:
	_game_active = true
	_go_label.text = "GO!"
	_go_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_status_label.text = "Press SPACE to win!"

func _on_ended(winner: String, message: String) -> void:
	_game_active = false
	_go_label.text = ""
	if winner == PlayerData.player_id:
		_result_label.text = "🏆  You win!"
		_result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	else:
		_result_label.text = message
		_result_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_status_label.text = ""
	_auto_closing = true
	_auto_close_timer = 4.0

func _reset() -> void:
	_game_active = false
	_pressed = false
	_status_label.text = "Get ready..."
	_go_label.text = ""
	_result_label.text = ""
```

- [ ] **Step 2: Commit**

```bash
git add scripts/ui/ReactionQuizPanel.gd
git commit -m "feat: ReactionQuizPanel countdown + Space-to-win UI"
```

---

## Task 15: Campus.gd — Zone Decoration Overlay

**Files:**
- Modify: `scripts/world/Campus.gd`

> **Context:** `Campus.gd` currently has no HTTP polling. We add a `_zone_event_overlays` dictionary keyed by zone_id → `ColorRect` node drawn on the world layer. A `Timer` node polls `GET /events?status=active` every 30s. Uses `HttpManager.get_json`.

- [ ] **Step 1: Add overlay state variables at top of Campus.gd (after existing `var` declarations)**

```gdscript
# ── Zone event decorations (Sprint 5) ──
var _zone_event_overlays: Dictionary = {}   # zone_id -> ColorRect
var _event_poll_timer: float = 0.0
const _EVENT_POLL_INTERVAL: float = 30.0
const _BACKEND_URL: String = "http://localhost:3002"
```

- [ ] **Step 2: Add `_setup_event_polling()` call in `_ready()` (after `NetworkManager.positions_updated.connect`)**

```gdscript
	_setup_event_polling()
```

- [ ] **Step 3: Add the four new functions to Campus.gd (before the final `}`)**

```gdscript
# ── Zone event decoration system (Sprint 5) ──────────────────────────────────

func _setup_event_polling() -> void:
	# Initial fetch
	_fetch_active_events()

func _process(delta: float) -> void:
	_event_poll_timer += delta
	if _event_poll_timer >= _EVENT_POLL_INTERVAL:
		_event_poll_timer = 0.0
		_fetch_active_events()

func _fetch_active_events() -> void:
	var token := PlayerData.make_auth_token()
	var headers := ["Authorization: Bearer " + token]
	HttpManager.get_json(_BACKEND_URL + "/events?status=active", headers,
		func(result: Dictionary) -> void:
			if result.get("error", false):
				return
			var active_events: Array = result.get("data", [])
			# Clear all existing overlays
			for zone_id in _zone_event_overlays.keys():
				clear_zone_event(zone_id)
			# Draw overlays for active events
			for evt in active_events:
				var zone_id: String = evt.get("location_zone", "")
				var title: String = evt.get("title", "")
				if zone_id != "" and _zones.has(zone_id):
					show_zone_event(zone_id, title, Color(0.3, 0.9, 0.4, 0.18))
	)

func show_zone_event(zone_id: String, event_title: String, color: Color) -> void:
	if not _zones.has(zone_id):
		return
	# Remove existing overlay for this zone if any
	clear_zone_event(zone_id)

	var zone_rect: Rect2 = _zones[zone_id]["rect"]
	var overlay := ColorRect.new()
	overlay.color = color
	overlay.position = zone_rect.position
	overlay.size = zone_rect.size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_zone_event_overlays[zone_id] = overlay

	# Floating banner label above zone
	var banner := Label.new()
	banner.text = "🎉 " + event_title
	banner.add_theme_font_size_override("font_size", 11)
	banner.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	banner.position = zone_rect.position + Vector2(4.0, -18.0)
	banner.modulate = Color(1, 1, 1, 0.9)
	banner.name = "EventBanner_" + zone_id
	add_child(banner)

func clear_zone_event(zone_id: String) -> void:
	if _zone_event_overlays.has(zone_id):
		_zone_event_overlays[zone_id].queue_free()
		_zone_event_overlays.erase(zone_id)
	var banner := get_node_or_null("EventBanner_" + zone_id)
	if banner:
		banner.queue_free()
```

- [ ] **Step 4: Commit**

```bash
git add scripts/world/Campus.gd
git commit -m "feat: Campus zone event overlays + 30s polling of active events"
```

---

## Task 16: HUD.gd — V Key + Event Toast + Panels

**Files:**
- Modify: `scripts/ui/HUD.gd`

> **Context:** HUD already handles `H` (workspace), `C` (chat), `Shift+A` (avatar). We add `V` for EventBoard, `B` for AnnouncementBoard, a `TriviaPanel` + `ReactionQuizPanel` auto-popup, and an event toast for active events.

- [ ] **Step 1: Add panel references at top of HUD.gd (after `web_chat_panel` declaration)**

```gdscript
# ── Sprint 5: Events + Minigames ──
var _event_board: Control = null
var _event_create_panel: Control = null
var _announcement_board: Control = null
var _trivia_panel: Control = null
var _reaction_panel: Control = null
```

- [ ] **Step 2: Add `_build_sprint5_panels()` call in `_ready()` (after `_build_roster_panel()`)**

```gdscript
	_build_sprint5_panels()
	NetworkManager.trivia_started.connect(func(_qi, _t, _q, _o, _ms): _ensure_trivia_visible())
	NetworkManager.reaction_countdown.connect(func(_c): _ensure_reaction_visible())
```

- [ ] **Step 3: Add the build function (before the final closing of the file)**

```gdscript
# ── Sprint 5 panels ─────────────────────────────────────────────────────────

func _build_sprint5_panels() -> void:
	# EventBoard
	var eb_script = load("res://scripts/ui/EventBoard.gd")
	_event_board = eb_script.new()
	_event_board.set_anchors_preset(Control.PRESET_CENTER)
	_event_board.offset_left = -210
	_event_board.offset_right = 210
	_event_board.offset_top = -260
	_event_board.offset_bottom = 260
	_event_board.visible = false
	add_child(_event_board)

	# EventCreatePanel (lead/admin only)
	var ecp_script = load("res://scripts/ui/EventCreatePanel.gd")
	_event_create_panel = ecp_script.new()
	_event_create_panel.set_anchors_preset(Control.PRESET_CENTER)
	_event_create_panel.offset_left = -200
	_event_create_panel.offset_right = 200
	_event_create_panel.offset_top = -250
	_event_create_panel.offset_bottom = 250
	_event_create_panel.visible = false
	_event_create_panel.connect("event_created", func(): _event_board.open())
	add_child(_event_create_panel)

	# AnnouncementBoard
	var ab_script = load("res://scripts/ui/AnnouncementBoard.gd")
	_announcement_board = ab_script.new()
	_announcement_board.set_anchors_preset(Control.PRESET_CENTER)
	_announcement_board.offset_left = -190
	_announcement_board.offset_right = 190
	_announcement_board.offset_top = -170
	_announcement_board.offset_bottom = 170
	_announcement_board.visible = false
	add_child(_announcement_board)

	# TriviaPanel
	var tp_script = load("res://scripts/ui/TriviaPanel.gd")
	_trivia_panel = tp_script.new()
	add_child(_trivia_panel)

	# ReactionQuizPanel
	var rp_script = load("res://scripts/ui/ReactionQuizPanel.gd")
	_reaction_panel = rp_script.new()
	add_child(_reaction_panel)

func _ensure_trivia_visible() -> void:
	if _trivia_panel:
		_trivia_panel.visible = true

func _ensure_reaction_visible() -> void:
	if _reaction_panel:
		_reaction_panel.visible = true
```

- [ ] **Step 4: Add `V` and `B` key handling in `_unhandled_input()` (or wherever `H` / `C` are handled)**

Find the existing key input section — it typically contains `if event.keycode == KEY_H`. After the last key block:

```gdscript
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			if _event_board:
				if _event_board.visible:
					_event_board.visible = false
				else:
					_event_board.open()
			get_viewport().set_input_as_handled()
		if event.keycode == KEY_B:
			if _announcement_board:
				if _announcement_board.visible:
					_announcement_board.visible = false
				else:
					_announcement_board.open()
			get_viewport().set_input_as_handled()
```

- [ ] **Step 5: Update help popup controls list to include V and B keys**

In `_build_help_button()`, add to the `controls` array:
```gdscript
		["V", "Events Board"],
		["B", "Announcements"],
```

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/HUD.gd
git commit -m "feat: HUD V/B shortcuts for EventBoard/AnnouncementBoard + trivia/reaction auto-popup"
```

---

## Task 17: HttpManager — Ensure `get_json` + `post_json` API Exists

**Files:**
- Modify: `scripts/autoloads/HttpManager.gd` (if needed)

> **Context:** `EventBoard`, `EventCreatePanel`, `AnnouncementBoard`, and `Campus.gd` all call `HttpManager.get_json(url, headers, callback)` and `HttpManager.post_json(url, body, headers, callback)`. The callback receives `{ data: ..., error: bool, message: ... }`. Verify that these methods exist and have the right signature.

- [ ] **Step 1: Read the current HttpManager.gd**

```bash
cat scripts/autoloads/HttpManager.gd
```

- [ ] **Step 2: If `get_json` / `post_json` are missing or have a different signature, add/update them**

The required API is:

```gdscript
## HttpManager.gd (ensure these two methods exist with this exact signature)

## GET request. callback(result: Dictionary) where result = { data: Variant, error: bool, message: String }
func get_json(url: String, headers: Array, callback: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
			http.queue_free()
			if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
				callback.call({ "error": true, "message": "HTTP %d" % code, "data": null })
				return
			var parsed = JSON.parse_string(body.get_string_from_utf8())
			callback.call({ "error": false, "message": "", "data": parsed })
	)
	http.request(url, PackedStringArray(headers), HTTPClient.METHOD_GET)

## POST request with JSON body.
func post_json(url: String, body: Dictionary, headers: Array, callback: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	var full_headers := PackedStringArray(headers)
	if not full_headers.has("Content-Type: application/json"):
		full_headers.append("Content-Type: application/json")
	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, resp_body: PackedByteArray):
			http.queue_free()
			if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
				callback.call({ "error": true, "message": "HTTP %d" % code, "data": null })
				return
			var parsed = JSON.parse_string(resp_body.get_string_from_utf8())
			callback.call({ "error": false, "message": "", "data": parsed })
	)
	http.request(url, full_headers, HTTPClient.METHOD_POST, JSON.stringify(body))
```

> **Note:** If `HttpManager.gd` already has these methods with the same signature, skip this step. If the existing implementation has a different callback shape, update all call sites in `EventBoard.gd`, `EventCreatePanel.gd`, `AnnouncementBoard.gd`, and `Campus.gd` to match the existing shape instead.

- [ ] **Step 3: Commit (if changed)**

```bash
git add scripts/autoloads/HttpManager.gd
git commit -m "feat: ensure HttpManager has get_json/post_json with correct callback shape"
```

---

## Task 18: Integration Smoke Test

**Goal:** Verify all 6 subsystems work end-to-end.

- [ ] **Step 1: Start backend**

```bash
cd backend && npm run dev
```

Expected: `[ZPS Backend] Listening on http://localhost:3002`

- [ ] **Step 2: Start WS server**

```bash
cd server && npm run dev
```

Expected: `[ZPS World Server] Listening on ws://localhost:3001`

- [ ] **Step 3: Test Events API (5A)**

```bash
# Create a lead token: base64({"id":"u1","role":"lead"})
LEAD_TOKEN=$(echo -n '{"id":"u1","role":"lead"}' | base64)
MEMBER_TOKEN=$(echo -n '{"id":"u2","role":"member"}' | base64)

# Create event (lead can)
curl -s -X POST http://localhost:3002/events \
  -H "Authorization: Bearer $LEAD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Sprint Review","description":"Showcasing Sprint 5","type":"official","location_zone":"reception","start_time":"2026-04-10T09:00:00.000Z","end_time":"2026-04-10T10:00:00.000Z"}' | jq .
```

Expected: JSON with `id` starting with `evt-`, `status: "upcoming"`.

```bash
# Attend event
EVENT_ID=$(curl -s http://localhost:3002/events -H "Authorization: Bearer $MEMBER_TOKEN" | jq -r '.[0].id')
curl -s -X POST http://localhost:3002/events/$EVENT_ID/attend \
  -H "Authorization: Bearer $MEMBER_TOKEN" | jq .attendee_ids
```

Expected: `["u2"]`

- [ ] **Step 4: Test Announcements API (5F)**

```bash
ADMIN_TOKEN=$(echo -n '{"id":"admin1","role":"admin"}' | base64)

curl -s -X POST http://localhost:3002/announcements \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Office closed Friday","body":"Please work from home."}' | jq .

curl -s http://localhost:3002/announcements \
  -H "Authorization: Bearer $MEMBER_TOKEN" | jq 'length'
```

Expected: length = 1

- [ ] **Step 5: Run all backend tests**

```bash
cd backend && npx jest --no-coverage
```

Expected: All tests pass.

- [ ] **Step 6: Run all server tests**

```bash
cd server && npx jest --no-coverage
```

Expected: All tests pass.

- [ ] **Step 7: Open Godot → Run project → Press V**

Expected: EventBoard panel opens. Status shows "Loading..." then event count.

- [ ] **Step 8: Press B in game**

Expected: AnnouncementBoard opens with announcements from backend.

- [ ] **Step 9: Commit final integration commit**

```bash
git add .
git commit -m "feat: Sprint 5 complete — events, announcements, trivia, reaction quiz"
```

---

## Self-Review

### 1. Spec Coverage

| Section | Task(s) | Status |
|---------|---------|--------|
| 5A — Events REST API | Tasks 3, 4 | Covered: GET /events, POST /events, GET /events/:id, POST /events/:id/attend, GET /events/:id/attendance |
| 5B — Event Board UI | Tasks 10, 11, 16 | Covered: EventBoard, EventCreatePanel, V key, HUD toast wiring |
| 5C — Zone Decorations | Task 15 | Covered: show_zone_event, clear_zone_event, 30s poll |
| 5D — ZPS Trivia | Tasks 6, 7, 13 | Covered: TriviaManager (10 questions), trivia_start/answer WS, TriviaPanel |
| 5E — Reaction Quiz | Tasks 7, 14 | Covered: reaction_start/press WS, countdown, ReactionQuizPanel |
| 5F — Announcement Board | Tasks 5, 12, 16 | Covered: AnnouncementsService, AnnouncementsController, AnnouncementBoard, B key |

### 2. Placeholder Scan

No TBD, TODO, or "similar to above" patterns found. All code blocks are complete.

### 3. Type Consistency Check

| Symbol | Defined in | Used in | Match? |
|--------|-----------|---------|--------|
| `trivia_start` WS type | server.js (TriviaManager._broadcastQuestion) | NetworkManager `"trivia_start"` match case | ✓ |
| `trivia_answer` WS type | server.js TriviaManager._onQuestionTimeout | NetworkManager `"trivia_answer"` match case | ✓ |
| `trivia_end` WS type | server.js TriviaManager._endGame | NetworkManager `"trivia_end"` match case | ✓ |
| `trivia_answer` client→server | NetworkManager.send_trivia_answer | server.js `msg.type === 'trivia_answer'` handler | ✓ |
| `reaction_countdown` WS type | server.js reactionGames countdown | NetworkManager `"reaction_countdown"` match case | ✓ |
| `reaction_go` WS type | server.js | NetworkManager `"reaction_go"` match | ✓ |
| `reaction_end` WS type | server.js | NetworkManager `"reaction_end"` match | ✓ |
| `NetworkManager.trivia_started` signal | NetworkManager.gd | TriviaPanel._ready(), HUD._build_sprint5_panels() | ✓ |
| `NetworkManager.reaction_countdown` signal | NetworkManager.gd | ReactionQuizPanel._ready(), HUD | ✓ |
| `PlayerData.make_auth_token()` | PlayerData.gd Task 8 | EventBoard, EventCreatePanel, AnnouncementBoard, Campus.gd | ✓ |
| `HttpManager.get_json(url, headers, cb)` | HttpManager.gd Task 17 | EventBoard, AnnouncementBoard, Campus.gd | ✓ |
| `HttpManager.post_json(url, body, headers, cb)` | HttpManager.gd Task 17 | EventBoard._on_attend, EventCreatePanel._on_submit | ✓ |
| `show_zone_event(zone_id, event_title, color)` | Campus.gd Task 15 | Campus.gd _fetch_active_events lambda | ✓ |
| `clear_zone_event(zone_id)` | Campus.gd Task 15 | Campus.gd _fetch_active_events clear loop | ✓ |
| `event_created` signal | EventCreatePanel.gd | HUD._build_sprint5_panels connect | ✓ |
