import { Test } from '@nestjs/testing';
import { AchievementsService } from './achievements.service';

describe('AchievementsService', () => {
  let service: AchievementsService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [AchievementsService],
    }).compile();
    service = module.get<AchievementsService>(AchievementsService);
  });

  it('returns seeded achievements for hieupt', () => {
    const result = service.getMyAchievements('hieupt');
    expect(Array.isArray(result)).toBe(true);
    expect(result).toHaveLength(3);
  });

  it('returns empty array for unknown player', () => {
    const result = service.getMyAchievements('unknown_xyz');
    expect(result).toEqual([]);
  });

  it('each achievement has required fields', () => {
    const result = service.getMyAchievements('hieupt');
    expect(result[0]).toHaveProperty('id');
    expect(result[0]).toHaveProperty('title');
    expect(result[0]).toHaveProperty('unlocks');
  });

  it('sync returns new achievements since past date', () => {
    const result = service.syncAchievements('hieupt', '2020-01-01T00:00:00Z');
    expect(result.new_achievements).toHaveLength(3);
  });

  it('sync returns empty when already up to date', () => {
    const future = new Date(Date.now() + 999999999).toISOString();
    const result = service.syncAchievements('hieupt', future);
    expect(result.new_achievements).toHaveLength(0);
  });

  it('getPlayerDesk returns layout for known player', () => {
    const result = service.getPlayerDesk('hieupt');
    expect(result).not.toBeNull();
    expect(result!.desk_layout).toHaveLength(12);
  });

  it('getPlayerDesk returns null for unknown player', () => {
    const result = service.getPlayerDesk('unknown_xyz');
    expect(result).toBeNull();
  });

  it('saveDesk stores and returns the layout', () => {
    const layout = Array(12).fill('');
    layout[0] = 'plant';
    const result = service.saveDesk('hieupt', layout);
    expect(result.saved).toBe(true);
    expect(result.desk_layout[0]).toBe('plant');
  });
});
