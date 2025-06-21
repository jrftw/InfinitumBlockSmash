import * as admin from "firebase-admin";

// Initialize Firebase Admin first
admin.initializeApp();

// Import functions after initialization
import {
  dailyLeaderboardReset,
  weeklyLeaderboardReset,
  monthlyLeaderboardReset
} from "./leaderboardCleanup";

export {
  dailyLeaderboardReset,
  weeklyLeaderboardReset,
  monthlyLeaderboardReset,
}; 