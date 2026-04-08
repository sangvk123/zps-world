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
