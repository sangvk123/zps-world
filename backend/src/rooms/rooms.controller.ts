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
