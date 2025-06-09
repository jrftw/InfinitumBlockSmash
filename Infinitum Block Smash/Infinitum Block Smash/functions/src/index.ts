import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

// Helper function to get the start of the day
function getStartOfDay(date: Date): Date {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

// Helper function to get the start of the week (Sunday)
function getStartOfWeek(date: Date): Date {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day;
    return new Date(d.setDate(diff));
}

// Helper function to get the start of the month
function getStartOfMonth(date: Date): Date {
    return new Date(date.getFullYear(), date.getMonth(), 1);
}

// Function to reset leaderboards
export const resetLeaderboards = functions.pubsub
    .schedule('0 0 * * *') // Run at midnight every day
    .timeZone('UTC')
    .onRun(async (context) => {
        const now = new Date();
        const startOfDay = getStartOfDay(now);
        const startOfWeek = getStartOfWeek(now);
        const startOfMonth = getStartOfMonth(now);

        // Reset daily leaderboards at midnight
        console.log('Resetting daily leaderboards...');
        await resetTimeframeLeaderboard('daily', startOfDay);

        // Check if it's the start of a new week (Sunday)
        if (now.getDay() === 0 && now.getHours() === 0) {
            console.log('Resetting weekly leaderboards...');
            await resetTimeframeLeaderboard('weekly', startOfWeek);
        }

        // Check if it's the start of a new month
        if (now.getDate() === 1 && now.getHours() === 0) {
            console.log('Resetting monthly leaderboards...');
            await resetTimeframeLeaderboard('monthly', startOfMonth);
        }

        return null;
    });

async function resetTimeframeLeaderboard(timeframe: string, startDate: Date) {
    const db = admin.firestore();
    const batch = db.batch();

    // Reset classic leaderboard
    const classicRef = db.collection('classic_leaderboard').doc(timeframe);
    batch.set(classicRef, {
        lastReset: admin.firestore.Timestamp.fromDate(startDate),
        scores: {}
    });

    // Reset achievement leaderboard
    const achievementRef = db.collection('achievement_leaderboard').doc(timeframe);
    batch.set(achievementRef, {
        lastReset: admin.firestore.Timestamp.fromDate(startDate),
        scores: {}
    });

    // Commit the batch
    await batch.commit();
    console.log(`Successfully reset ${timeframe} leaderboards`);
}

// Function to get current leaderboard timeframe
export const getCurrentLeaderboardTimeframe = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const now = new Date();
    const startOfDay = getStartOfDay(now);
    const startOfWeek = getStartOfWeek(now);
    const startOfMonth = getStartOfMonth(now);

    return {
        daily: {
            start: startOfDay,
            end: new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000)
        },
        weekly: {
            start: startOfWeek,
            end: new Date(startOfWeek.getTime() + 7 * 24 * 60 * 60 * 1000)
        },
        monthly: {
            start: startOfMonth,
            end: new Date(startOfMonth.getFullYear(), startOfMonth.getMonth() + 1, 1)
        }
    };
}); 