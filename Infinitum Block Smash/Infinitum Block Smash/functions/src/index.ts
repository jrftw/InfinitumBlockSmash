import * as admin from "firebase-admin";

// Initialize Firebase Admin first
admin.initializeApp();

// Import functions after initialization
import {cleanupLeaderboards} from "./leaderboardCleanup";

export {
  cleanupLeaderboards,
}; 