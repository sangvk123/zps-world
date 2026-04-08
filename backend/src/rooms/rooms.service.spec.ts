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
