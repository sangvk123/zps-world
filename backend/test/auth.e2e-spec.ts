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
