import { IsDateString, IsNotEmpty, IsString, Matches } from 'class-validator';

export class BookingDto {
  @IsDateString()
  date: string;

  @IsString()
  @IsNotEmpty()
  @Matches(/^\d{2}:\d{2}-\d{2}:\d{2}$/, { message: 'time_slot must be HH:MM-HH:MM format' })
  time_slot: string;
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
