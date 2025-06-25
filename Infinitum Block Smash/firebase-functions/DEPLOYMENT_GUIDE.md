# Firebase Functions Deployment Guide

## Overview
This guide explains how to deploy the updated leaderboard cleanup functions for Infinitum Block Smash.

## What Was Fixed

### ❌ Previous Issues
- Functions ran every 24 hours instead of at specific times
- Incorrect logic for period-based clearing
- Single function trying to handle all periods
- No proper timezone handling

### ✅ New Implementation
- **Daily Reset**: Runs at midnight EST every day
- **Weekly Reset**: Runs at midnight EST every Sunday
- **Monthly Reset**: Runs at midnight EST on the last day of each month
- **All-Time**: Never cleared (permanent records)

## Deployment Steps

### 1. Prerequisites
Make sure you have:
- Node.js 18+ installed
- Firebase CLI installed (`npm install -g firebase-tools`)
- Access to the Firebase project (`infinitum-stack-smash`)

### 2. Build and Deploy

#### Option A: Using the Deployment Script (Recommended)
```bash
# Make sure you're in the firebase-functions directory
cd /path/to/firebase-functions

# Run the deployment script
./deploy.sh
```

#### Option B: Manual Deployment
```bash
# Install dependencies
npm install

# Build the TypeScript functions
npm run build

# Deploy to Firebase
firebase deploy --only functions
```

### 3. Verify Deployment

After deployment, check the Firebase Console:
1. Go to https://console.firebase.google.com/project/infinitum-stack-smash/functions
2. Verify these functions are deployed:
   - `dailyLeaderboardReset`
   - `weeklyLeaderboardReset` 
   - `monthlyLeaderboardReset`
   - `cleanupLeaderboards` (legacy - deprecated)

### 4. Monitor Function Execution

You can monitor function execution in the Firebase Console:
- **Logs**: View execution logs and any errors
- **Metrics**: Monitor execution times and success rates
- **Triggers**: Verify scheduled triggers are active

## Function Details

### Daily Reset (`dailyLeaderboardReset`)
- **Schedule**: `0 0 * * *` (midnight every day)
- **Timezone**: America/New_York (EST/EDT)
- **Action**: Clears all daily leaderboard entries from previous days

### Weekly Reset (`weeklyLeaderboardReset`)
- **Schedule**: `0 0 * * 0` (midnight every Sunday)
- **Timezone**: America/New_York (EST/EDT)
- **Action**: Clears all weekly leaderboard entries from previous weeks

### Monthly Reset (`monthlyLeaderboardReset`)
- **Schedule**: `0 0 L * *` (midnight on last day of each month)
- **Timezone**: America/New_York (EST/EDT)
- **Action**: Clears all monthly leaderboard entries from previous months

### Legacy Function (`cleanupLeaderboards`)
- **Status**: Deprecated
- **Action**: Logs warning message only
- **Purpose**: Backward compatibility

## Leaderboard Structure

The functions work with this Firestore structure:
```
classic_leaderboard/
├── daily/scores/{userId}
├── weekly/scores/{userId}
├── monthly/scores/{userId}
└── alltime/scores/{userId}

achievement_leaderboard/
├── daily/scores/{userId}
├── weekly/scores/{userId}
├── monthly/scores/{userId}
└── alltime/scores/{userId}

classic_timed_leaderboard/
├── daily/scores/{userId}
├── weekly/scores/{userId}
├── monthly/scores/{userId}
└── alltime/scores/{userId}
```

## Testing

### Manual Testing
You can manually trigger functions for testing:
```bash
# Test daily reset
firebase functions:shell
> dailyLeaderboardReset()

# Test weekly reset
> weeklyLeaderboardReset()

# Test monthly reset
> monthlyLeaderboardReset()
```

### Verification
After a reset, verify:
1. Old entries are removed from the specified period
2. All-time entries remain untouched
3. New entries can still be added
4. Top 10 display still works correctly

## Troubleshooting

### Common Issues

1. **Function not deploying**
   - Check Firebase CLI is installed and logged in
   - Verify you have access to the project
   - Check for TypeScript compilation errors

2. **Functions not running on schedule**
   - Verify timezone is set correctly (America/New_York)
   - Check Firebase Console for function status
   - Review function logs for errors

3. **Leaderboard entries not clearing**
   - Check function execution logs
   - Verify timestamp format in Firestore
   - Ensure function has proper permissions

### Logs and Monitoring
- **Function Logs**: Firebase Console > Functions > Logs
- **Real-time Monitoring**: Firebase Console > Functions > Metrics
- **Error Tracking**: Check for failed executions and error messages

## Rollback Plan

If issues occur, you can rollback:
```bash
# Deploy previous version
firebase deploy --only functions --force

# Or disable functions temporarily
firebase functions:config:set leaderboard.enabled=false
```

## Support

For issues with the functions:
1. Check the Firebase Console logs
2. Review the function execution metrics
3. Test manually using Firebase Functions shell
4. Contact the development team with specific error messages

## Security Notes

- Functions run with admin privileges
- Only authenticated users can write to leaderboards
- All-time leaderboard is protected from clearing
- Score validation prevents invalid entries 