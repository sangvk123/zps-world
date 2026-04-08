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
