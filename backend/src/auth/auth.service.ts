import * as fs from 'fs';
import * as path from 'path';
import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

export interface EmployeeProfile {
  id: string;
  name: string;
  department: string;
  title: string;
  nameplate_title: string;
  zps_class: string;
  char_id: number;
  is_online: boolean;
  avatar: Record<string, unknown>;
  current_task: string;
}

interface AccountEntry {
  id: string;
  domain: string;
  password: string;
  name: string;
  department: string;
  title: string;
  nameplate_title?: string;
  zps_class: string;
  char_id: number;
}

// ── Load accounts from JSON ──────────────────────────────────────────────────
// Priority: ACCOUNTS_JSON env var (for Railway) → data/accounts.json (local)
function loadAccounts(): AccountEntry[] {
  const envJson = process.env['ACCOUNTS_JSON'];
  if (envJson) {
    try {
      return JSON.parse(envJson) as AccountEntry[];
    } catch {
      console.error('[Auth] ACCOUNTS_JSON env var is not valid JSON');
    }
  }
  // __dirname in compiled output = backend/dist/auth → go up 2 levels to backend/
  const filePath = path.join(__dirname, '..', '..', 'data', 'accounts.json');
  if (!fs.existsSync(filePath)) {
    console.warn('[Auth] accounts.json not found — copy accounts.example.json to accounts.json');
    return [];
  }
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf-8')) as AccountEntry[];
  } catch {
    console.error('[Auth] Failed to parse accounts.json');
    return [];
  }
}

const ACCOUNTS: AccountEntry[] = loadAccounts();

function accountToProfile(acc: AccountEntry): EmployeeProfile {
  const deptOutfit: Record<string, string> = {
    Engineering: 'work_casual', Design: 'creative', Product: 'formal',
    HR: 'work_casual', Data: 'work_casual', Marketing: 'creative',
    'Game Design': 'creative', Multimedia: 'creative',
  };
  return {
    id: acc.id,
    name: acc.name,
    department: acc.department,
    title: acc.title,
    nameplate_title: acc.nameplate_title ?? acc.title,
    zps_class: acc.zps_class ?? 'artisan',
    char_id: acc.char_id ?? 0,
    is_online: true,
    avatar: {
      outfit_id: deptOutfit[acc.department] ?? 'work_casual',
      class_name: acc.zps_class ?? 'artisan',
    },
    current_task: '',
  };
}

// ── Mock NPC employees (not in accounts.json — AI-controlled) ────────────────
function buildNpcEmployees(): Record<string, EmployeeProfile> {
  function seededRandom(seed: number): () => number {
    let s = seed;
    return () => {
      s = (s * 1664525 + 1013904223) & 0xffffffff;
      return (s >>> 0) / 0xffffffff;
    };
  }
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
  const tasks = ['Building Quest Engine','Designing UI','Planning Q2 roadmap','Conducting interviews','Analyzing dashboard','Creating campaign'];
  const pick = <T>(arr: T[], r: number) => arr[Math.floor(r * arr.length)];

  const npcs: Record<string, EmployeeProfile> = {};
  for (let i = 1; i <= 100; i++) {
    const id = `emp_${String(i).padStart(3, '0')}`;
    const isMale = rand() < 0.4;
    const first = isMale ? pick(maleFirst, rand()) : pick(femaleFirst, rand());
    const dept = pick(depts, rand());
    const npcTitle = pick(deptTitles[dept], rand());
    npcs[id] = {
      id,
      name: `${pick(lastNames, rand())} ${first}`,
      department: dept,
      title: npcTitle,
      nameplate_title: npcTitle,
      zps_class: deptClass[dept],
      char_id: Math.floor(rand() * 60) + 1,
      is_online: rand() < 0.7,
      avatar: { outfit_id: deptOutfit[dept], class_name: deptClass[dept] },
      current_task: pick(tasks, rand()),
    };
  }
  return npcs;
}

const NPC_EMPLOYEES = buildNpcEmployees();

@Injectable()
export class AuthService {
  constructor(private readonly jwtService: JwtService) {}

  async login(
    domain: string,
    password: string,
  ): Promise<{ access_token: string; employee: EmployeeProfile } | null> {
    const account = ACCOUNTS.find(
      (a) => a.domain.toLowerCase() === domain.toLowerCase(),
    );
    if (!account || account.password !== password) return null;

    const profile = accountToProfile(account);
    const payload = { sub: profile.id, department: profile.department };
    const access_token = await this.jwtService.signAsync(payload);
    return { access_token, employee: profile };
  }

  async validateJwt(payload: { sub: string }): Promise<EmployeeProfile | null> {
    const account = ACCOUNTS.find((a) => a.id === payload.sub);
    if (account) return accountToProfile(account);
    return NPC_EMPLOYEES[payload.sub] ?? null;
  }

  getEmployees(): EmployeeProfile[] {
    const real = ACCOUNTS.map(accountToProfile);
    const npcs = Object.values(NPC_EMPLOYEES);
    return [...real, ...npcs];
  }

  getEmployee(id: string): EmployeeProfile | undefined {
    const account = ACCOUNTS.find((a) => a.id === id);
    if (account) return accountToProfile(account);
    return NPC_EMPLOYEES[id];
  }
}
