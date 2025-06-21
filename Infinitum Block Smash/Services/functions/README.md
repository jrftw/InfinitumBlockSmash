# Firebase Functions - Leaderboard Resets

This directory contains Firebase Cloud Functions that handle automatic leaderboard resets for the Infinitum Block Smash game.

## Functions

### 1. Daily Leaderboard Reset
- **Function**: `dailyLeaderboardReset`
- **Schedule**: Every day at midnight Eastern time (00:00 EST/EDT)
- **Purpose**: Resets daily leaderboards for all game modes
- **Cron Expression**: `0 0 * * *`

### 2. Weekly Leaderboard Reset
- **Function**: `weeklyLeaderboardReset`
- **Schedule**: Every Sunday at midnight Eastern time (00:00 EST/EDT)
- **Purpose**: Resets weekly leaderboards for all game modes
- **Cron Expression**: `0 0 * * 0`

### 3. Monthly Leaderboard Reset
- **Function**: `monthlyLeaderboardReset`
- **Schedule**: Last day of each month at midnight Eastern time (00:00 EST/EDT)
- **Purpose**: Resets monthly leaderboards for all game modes
- **Cron Expression**: `0 0 L * *`

## Timezone Handling

All functions use the `America/New_York` timezone, which automatically handles:
- Eastern Standard Time (EST) during winter months
- Eastern Daylight Time (EDT) during summer months (Daylight Saving Time)

## Leaderboard Types

The functions process the following leaderboard collections:
- `classic_leaderboard` - Classic game mode scores
- `achievement_leaderboard` - Achievement points
- `classic_timed_leaderboard` - Timed game mode scores

## Reset Logic

1. **Score Validation**: Each function checks if scores should be reset based on their timestamp
2. **Data Preservation**: Old scores are deleted and regenerated from the `alltime` leaderboard data
3. **Batch Operations**: All operations are performed in batches for efficiency
4. **Error Handling**: Individual errors are logged but don't stop the entire process

## Development

### Building
```bash
npm run build
```

### Local Testing
```bash
npm run serve
```

### Deployment
```bash
npm run deploy
```

## Notes

- The client-side `resetPeriodScores` function has been removed and is now handled entirely by these Firebase functions
- All resets happen at midnight Eastern time to ensure consistency across time zones
- The functions automatically handle daylight saving time transitions 