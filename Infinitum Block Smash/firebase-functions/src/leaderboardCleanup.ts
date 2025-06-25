import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Get the initialized Firestore instance
const db = admin.firestore();

// Daily reset - every 24 hours at midnight Eastern time
export const dailyLeaderboardReset = functions.pubsub
  .schedule("0 0 * * *") // Run at midnight every day
  .timeZone("America/New_York") // Use EST/EDT timezone
  .onRun(async () => {
    console.log("[Leaderboard] Starting daily leaderboard reset");
    await performPeriodReset("daily");
    return null;
  });

// Weekly reset - every Sunday at midnight Eastern time
export const weeklyLeaderboardReset = functions.pubsub
  .schedule("0 0 * * 0") // Run at midnight every Sunday
  .timeZone("America/New_York") // Use EST/EDT timezone
  .onRun(async () => {
    console.log("[Leaderboard] Starting weekly leaderboard reset");
    await performPeriodReset("weekly");
    return null;
  });

// Monthly reset - last day of the month at midnight Eastern time
export const monthlyLeaderboardReset = functions.pubsub
  .schedule("0 0 L * *") // Run at midnight on the last day of each month
  .timeZone("America/New_York") // Use EST/EDT timezone
  .onRun(async () => {
    console.log("[Leaderboard] Starting monthly leaderboard reset");
    await performPeriodReset("monthly");
    return null;
  });

/**
 * Performs a complete reset for a specific period
 * @param {string} period - The period to reset (daily/weekly/monthly)
 */
async function performPeriodReset(period: string) {
  console.log(`[Leaderboard] Performing ${period} reset at ${new Date().toISOString()}`);
  
  const leaderboardTypes = [
    "classic_leaderboard",
    "achievement_leaderboard", 
    "classic_timed_leaderboard"
  ];

  for (const type of leaderboardTypes) {
    try {
      console.log(`[Leaderboard] Processing ${type}/${period}`);
      
      // Get all scores for this period
      const snapshot = await db.collection(type)
        .doc(period)
        .collection("scores")
        .get();

      const batch = db.batch();
      let processedCount = 0;
      let resetCount = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const timestamp = data.timestamp?.toDate();
        
        if (timestamp && shouldResetScore(period, timestamp)) {
          console.log(`[Leaderboard] Resetting ${period} score for user ${doc.id}`);
          
          // Delete the old entry - NO REGENERATION
          batch.delete(doc.ref);
          resetCount++;
        }
        processedCount++;
      }

      // Commit the batch
      await batch.commit();
      console.log(`[Leaderboard] Processed ${processedCount} entries, reset ${resetCount} for ${type}/${period}`);
      
    } catch (error) {
      console.error(`[Leaderboard] Error processing ${type}/${period}:`, error);
    }
  }
  
  console.log(`[Leaderboard] ${period} reset completed successfully`);
}

/**
 * Determines if a score should be reset based on the period
 * @param {string} period - The period to check
 * @param {Date} timestamp - The score timestamp
 * @returns {boolean} Whether the score should be reset
 */
function shouldResetScore(period: string, timestamp: Date): boolean {
  // Get current time in EST/EDT
  const now = new Date();
  const estNow = new Date(now.toLocaleString("en-US", { timeZone: "America/New_York" }));
  const estTimestamp = new Date(timestamp.toLocaleString("en-US", { timeZone: "America/New_York" }));
  
  console.log(`[Leaderboard] Checking reset for ${period}: timestamp=${estTimestamp.toLocaleString()}, now=${estNow.toLocaleString()}`);
  
  switch (period) {
    case "daily":
      // Reset if timestamp is from a previous day
      const isDifferentDay = estTimestamp.getDate() !== estNow.getDate() || 
                            estTimestamp.getMonth() !== estNow.getMonth() || 
                            estTimestamp.getFullYear() !== estNow.getFullYear();
      console.log(`[Leaderboard] Daily reset check: ${isDifferentDay ? 'RESET' : 'KEEP'}`);
      return isDifferentDay;
             
    case "weekly":
      // Reset if timestamp is from a previous week (before Sunday)
      const weekStart = new Date(estNow);
      weekStart.setDate(estNow.getDate() - estNow.getDay()); // Start of week (Sunday)
      weekStart.setHours(0, 0, 0, 0);
      const isPreviousWeek = estTimestamp < weekStart;
      console.log(`[Leaderboard] Weekly reset check: weekStart=${weekStart.toLocaleString()}, ${isPreviousWeek ? 'RESET' : 'KEEP'}`);
      return isPreviousWeek;
      
    case "monthly":
      // Reset if timestamp is from a previous month
      const isDifferentMonth = estTimestamp.getMonth() !== estNow.getMonth() || 
                              estTimestamp.getFullYear() !== estNow.getFullYear();
      console.log(`[Leaderboard] Monthly reset check: ${isDifferentMonth ? 'RESET' : 'KEEP'}`);
      return isDifferentMonth;
             
    default:
      return false;
  }
}

// Legacy function for backward compatibility (deprecated)
export const cleanupLeaderboards = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    console.log("[Leaderboard] Legacy cleanup function called - this should be replaced with specific period functions");
    return null;
  });
