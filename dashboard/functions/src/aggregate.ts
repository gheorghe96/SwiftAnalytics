import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

/**
 * Daily aggregation job — runs at 00:15 UTC every day.
 * Finalizes the previous day's aggregate with accurate DAU count.
 */
export const dailyAggregation = onSchedule(
  {
    schedule: "15 0 * * *", // 00:15 UTC daily
    timeZone: "UTC",
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async () => {
    const db = getFirestore();
    const yesterday = new Date();
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    const dateKey = formatDateKey(yesterday);

    console.log(`Running daily aggregation for ${dateKey}`);

    // Process all projects
    const projectsSnap = await db.collection("projects").get();

    for (const projectDoc of projectsSnap.docs) {
      const apiKey = projectDoc.id;
      const projectRef = db.collection("projects").doc(apiKey);

      try {
        // Get DAU from the daily_users document
        const dauRef = projectRef
          .collection("aggregates")
          .doc("daily_users")
          .collection("data")
          .doc(dateKey);
        const dauSnap = await dauRef.get();
        const dauData = dauSnap.data();
        const dau = dauData?.user_ids?.length || 0;

        // Update the daily aggregate with accurate DAU
        const aggregateRef = projectRef
          .collection("aggregates")
          .doc("daily")
          .collection("data")
          .doc(dateKey);
        await aggregateRef.set({ dau }, { merge: true });

        // Mark stale sessions as completed (no Session End received within 24h)
        const staleThreshold = Timestamp.fromMillis(
          Date.now() - 24 * 60 * 60 * 1000
        );
        const staleSessions = await projectRef
          .collection("sessions")
          .where("is_completed", "==", false)
          .where("start_time", "<", staleThreshold)
          .limit(500)
          .get();

        if (!staleSessions.empty) {
          const batch = db.batch();
          for (const session of staleSessions.docs) {
            const data = session.data();
            const startMs = data.start_time?.toMillis?.() || 0;
            const estimatedDuration = Date.now() - startMs;
            batch.update(session.ref, {
              is_completed: true,
              end_time: Timestamp.now(),
              duration_ms: Math.min(estimatedDuration, 30 * 60 * 1000), // Cap at 30 min
            });
          }
          await batch.commit();
          console.log(
            `Closed ${staleSessions.size} stale sessions for ${apiKey}`
          );
        }

        console.log(`Aggregation complete for ${apiKey}: DAU=${dau}`);
      } catch (error) {
        console.error(`Aggregation failed for ${apiKey}:`, error);
      }
    }
  }
);

function formatDateKey(date: Date): string {
  const yyyy = date.getUTCFullYear();
  const mm = String(date.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(date.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}
