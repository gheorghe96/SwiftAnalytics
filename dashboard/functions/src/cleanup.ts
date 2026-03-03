import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

/**
 * Cleanup job — runs daily at 03:00 UTC.
 * Deletes expired dedup documents and old events past retention.
 */
export const dailyCleanup = onSchedule(
  {
    schedule: "0 3 * * *", // 03:00 UTC daily
    timeZone: "UTC",
    memory: "512MiB",
    timeoutSeconds: 540,
  },
  async () => {
    const db = getFirestore();

    const projectsSnap = await db.collection("projects").get();

    for (const projectDoc of projectsSnap.docs) {
      const apiKey = projectDoc.id;
      const projectRef = db.collection("projects").doc(apiKey);
      const settings = projectDoc.data()?.settings || {};
      const retentionDays = settings.retention_days || 90;

      try {
        // 1. Clean up dedup documents older than 48 hours
        const dedupThreshold = Timestamp.fromMillis(
          Date.now() - 48 * 60 * 60 * 1000
        );

        let dedupDeleted = 0;
        const dedupQuery = projectRef
          .collection("dedup")
          .where("t", "<", dedupThreshold)
          .limit(500);

        let dedupSnap = await dedupQuery.get();
        while (!dedupSnap.empty) {
          const batch = db.batch();
          for (const doc of dedupSnap.docs) {
            batch.delete(doc.ref);
          }
          await batch.commit();
          dedupDeleted += dedupSnap.size;

          if (dedupSnap.size < 500) break;
          dedupSnap = await dedupQuery.get();
        }

        if (dedupDeleted > 0) {
          console.log(`Deleted ${dedupDeleted} dedup docs for ${apiKey}`);
        }

        // 2. Delete raw events older than retention period
        const retentionThreshold = Timestamp.fromMillis(
          Date.now() - retentionDays * 24 * 60 * 60 * 1000
        );

        let eventsDeleted = 0;
        const eventsQuery = projectRef
          .collection("events")
          .where("timestamp", "<", retentionThreshold)
          .limit(500);

        let eventsSnap = await eventsQuery.get();
        while (!eventsSnap.empty) {
          const batch = db.batch();
          for (const doc of eventsSnap.docs) {
            batch.delete(doc.ref);
          }
          await batch.commit();
          eventsDeleted += eventsSnap.size;

          if (eventsSnap.size < 500) break;
          eventsSnap = await eventsQuery.get();
        }

        if (eventsDeleted > 0) {
          console.log(
            `Deleted ${eventsDeleted} expired events for ${apiKey} (retention: ${retentionDays}d)`
          );
        }

        // 3. Clean up old daily_users documents (older than 31 days)
        const dauThreshold = new Date();
        dauThreshold.setUTCDate(dauThreshold.getUTCDate() - 31);
        const dauDateKey = formatDateKey(dauThreshold);

        const oldDauDocs = await projectRef
          .collection("aggregates")
          .doc("daily_users")
          .collection("data")
          .where("date", "<", dauDateKey)
          .limit(100)
          .get();

        if (!oldDauDocs.empty) {
          const batch = db.batch();
          for (const doc of oldDauDocs.docs) {
            batch.delete(doc.ref);
          }
          await batch.commit();
          console.log(
            `Deleted ${oldDauDocs.size} old daily_users docs for ${apiKey}`
          );
        }
      } catch (error) {
        console.error(`Cleanup failed for ${apiKey}:`, error);
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
