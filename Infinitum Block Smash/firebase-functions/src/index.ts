/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin first
admin.initializeApp();

// Import functions after initialization
import {
  dailyLeaderboardReset,
  weeklyLeaderboardReset,
  monthlyLeaderboardReset,
  cleanupLeaderboards
} from "./leaderboardCleanup";

export {
  dailyLeaderboardReset,
  weeklyLeaderboardReset,
  monthlyLeaderboardReset,
  cleanupLeaderboards // Legacy function for backward compatibility
};

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
