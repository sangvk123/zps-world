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
