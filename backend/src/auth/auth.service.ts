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
