import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  NotFoundException,
  BadRequestException,
  UseGuards,
  Request,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { AchievementsService } from './achievements.service';
import { SaveDeskDto } from './dto/desk.dto';

@Controller()
export class AchievementsController {
  constructor(private readonly achievementsService: AchievementsService) {}

  @Get('achievements/my')
  @UseGuards(AuthGuard('jwt'))
  getMyAchievements(@Request() req: { user: { id: string } }) {
    return this.achievementsService.getMyAchievements(req.user.id);
  }

  @Get('achievements/sync')
  @UseGuards(AuthGuard('jwt'))
  syncAchievements(
    @Request() req: { user: { id: string } },
    @Query('last_synced') lastSynced: string,
  ) {
    return this.achievementsService.syncAchievements(req.user.id, lastSynced || '1970-01-01T00:00:00Z');
  }

  @Get('players/:id/desk')
  @UseGuards(AuthGuard('jwt'))
  getPlayerDesk(@Param('id') id: string) {
    const result = this.achievementsService.getPlayerDesk(id);
    if (!result) throw new NotFoundException('Player not found');
    return result;
  }

  @Post('players/me/desk')
  @UseGuards(AuthGuard('jwt'))
  saveDesk(@Request() req: { user: { id: string } }, @Body() dto: SaveDeskDto) {
    if (!dto.desk_layout || dto.desk_layout.length !== 12) {
      throw new BadRequestException('desk_layout must be an array of 12 items');
    }
    return this.achievementsService.saveDesk(req.user.id, dto.desk_layout);
  }
}
