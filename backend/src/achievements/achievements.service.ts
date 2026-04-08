import { Injectable } from '@nestjs/common';

export interface Achievement {
  id: string;
  title: string;
  description: string;
  earned_at: string;
  unlocks: Record<string, string>;
}

export interface DeskLayout {
  desk_layout: string[];
}

// Seeded timestamp for mock data
const SEED_DATE = '2025-01-01T00:00:00.000Z';

const ACHIEVEMENT_CATALOGUE: Achievement[] = [
  {
    id: 'onboarding_complete',
    title: 'Welcome to ZPS',
    description: 'Complete the onboarding checklist',
    earned_at: SEED_DATE,
    unlocks: { outfit_id: 'initiate_class' },
  },
  {
    id: 'first_year',
    title: '1 Year ZPS',
    description: 'Celebrate your first year at ZPS',
    earned_at: SEED_DATE,
    unlocks: { cape_id: 'anniversary_cape' },
  },
  {
    id: 'top_performer',
    title: 'Top Performer',
    description: 'Ranked in top 10% this quarter',
    earned_at: SEED_DATE,
    unlocks: { aura_body: 'gold_glow' },
  },
];

@Injectable()
export class AchievementsService {
  private readonly playerAchievements: Record<string, Achievement[]> = {};
  private readonly deskLayouts: Record<string, string[]> = {};

  private getPlayerAchievements(playerId: string): Achievement[] {
    if (!this.playerAchievements[playerId]) {
      if (playerId === 'hieupt' || playerId === 'sangvk' || playerId === 'player_001') {
        this.playerAchievements[playerId] = [...ACHIEVEMENT_CATALOGUE];
      } else if (playerId.startsWith('emp_')) {
        // Give emp_ players the first achievement
        this.playerAchievements[playerId] = [ACHIEVEMENT_CATALOGUE[0]];
      } else {
        this.playerAchievements[playerId] = [];
      }
    }
    return this.playerAchievements[playerId];
  }

  getMyAchievements(playerId: string): Achievement[] {
    return this.getPlayerAchievements(playerId);
  }

  syncAchievements(playerId: string, lastSynced: string): { new_achievements: Achievement[] } {
    const lastSyncedMs = new Date(lastSynced || '1970-01-01T00:00:00Z').getTime();
    const achievements = this.getPlayerAchievements(playerId);
    const newAchievements = achievements.filter((ach) => {
      return new Date(ach.earned_at).getTime() > lastSyncedMs;
    });
    return { new_achievements: newAchievements };
  }

  getPlayerDesk(playerId: string): DeskLayout | null {
    if (
      playerId !== 'hieupt' &&
      playerId !== 'sangvk' &&
      playerId !== 'player_001' &&
      !playerId.startsWith('emp_') &&
      !this.deskLayouts[playerId]
    ) {
      return null;
    }
    return { desk_layout: this.deskLayouts[playerId] || Array(12).fill('') };
  }

  saveDesk(playerId: string, layout: string[]): { saved: boolean; desk_layout: string[] } {
    this.deskLayouts[playerId] = layout.map((item) => (typeof item === 'string' ? item : ''));
    return { saved: true, desk_layout: this.deskLayouts[playerId] };
  }
}
