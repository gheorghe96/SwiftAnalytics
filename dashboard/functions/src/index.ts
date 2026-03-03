import { initializeApp } from "firebase-admin/app";

// Initialize Firebase Admin SDK
initializeApp();

// Export Cloud Functions
export { ingest } from "./ingest";
export { dailyAggregation } from "./aggregate";
export { dailyCleanup } from "./cleanup";
export { createApp, claimProject, deleteApp } from "./app-management";
