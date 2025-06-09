import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Get the initialized Firestore instance
const db = admin.firestore();

export const cleanupLeaderboards = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const now = new Date();
    const batch = db.batch();
    const deleteCount = 0;

    try {
      // Clean up daily leaderboard
      const dailyCutoff = new Date(now);
      dailyCutoff.setDate(dailyCutoff.getDate() - 1);
      await cleanupTimeframe("daily", dailyCutoff, batch);

      // Clean up weekly leaderboard
      const weeklyCutoff = new Date(now);
      weeklyCutoff.setDate(weeklyCutoff.getDate() - 7);
      await cleanupTimeframe("weekly", weeklyCutoff, batch);

      // Clean up monthly leaderboard
      const monthlyCutoff = new Date(now);
      monthlyCutoff.setMonth(monthlyCutoff.getMonth() - 1);
      await cleanupTimeframe("monthly", monthlyCutoff, batch);

      // Commit all deletions
      await batch.commit();
      console.log(
        `Successfully cleaned up ${deleteCount} outdated leaderboard entries`
      );
      return null;
    } catch (error) {
      console.error("Error cleaning up leaderboards:", error);
      throw error;
    }
  });

/**
 * Cleans up outdated entries from a specific timeframe in all leaderboard types
 * @param {string} timeframe - The timeframe to clean up (daily/weekly/monthly)
 * @param {Date} cutoffDate - The date before which entries should be deleted
 * @param {admin.firestore.WriteBatch} batch - The batch to add deletions to
 */
async function cleanupTimeframe(
  timeframe: string,
  cutoffDate: Date,
  batch: admin.firestore.WriteBatch
) {
  const leaderboardTypes = [
    "classic_leaderboard",
    "achievement_leaderboard",
    "classic_timed_leaderboard",
  ];
  for (const type of leaderboardTypes) {
    const snapshot = await db.collection(type)
      .doc(timeframe)
      .collection("scores")
      .where("timestamp", "<", cutoffDate)
      .get();

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
  }
} 