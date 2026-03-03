import { onRequest } from "firebase-functions/v2/https";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { validatePayload } from "./lib/validation";
import { decompressBody } from "./lib/decompress";
import { applyIdentifyOperations } from "./lib/identify";
import { buildAggregateUpdate, getDateKey } from "./lib/counters";
import { createSessionDoc, buildSessionUpdate } from "./lib/session";
import { RawEvent, EventTypes, RevenueKeys } from "./types";

// In-memory cache for validated API keys (per function instance)
const validApiKeys = new Map<string, boolean>();

/**
 * Main ingestion endpoint — receives event batches from the SwiftAnalytics SDK.
 * POST /2/httpapi
 */
export const ingest = onRequest(
  {
    memory: "512MiB",
    timeoutSeconds: 60,
    maxInstances: 100,
    cors: true,
  },
  async (req, res) => {
    // Only accept POST
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    const db = getFirestore();

    try {
      // 1. Decompress body if needed
      let rawBody: Buffer;
      if (req.rawBody) {
        rawBody = req.rawBody;
      } else {
        res.status(400).json({ error: "Empty request body" });
        return;
      }

      const contentEncoding = req.headers["content-encoding"] as
        | string
        | undefined;
      const decompressed = await decompressBody(rawBody, contentEncoding);
      const bodyStr = decompressed.toString("utf-8");

      // 2. Parse JSON
      let parsed: unknown;
      try {
        parsed = JSON.parse(bodyStr);
      } catch {
        res.status(400).json({ error: "Invalid JSON" });
        return;
      }

      // 3. Validate payload
      const validation = validatePayload(parsed);
      if (!validation.success || !validation.data) {
        res.status(400).json({ error: validation.error });
        return;
      }

      const { api_key, events } = validation.data;

      // 4. Validate API key
      if (!validApiKeys.has(api_key)) {
        const projectSnap = await db
          .collection("projects")
          .doc(api_key)
          .get();
        if (!projectSnap.exists) {
          res.status(400).json({ error: "Invalid API key" });
          return;
        }
        validApiKeys.set(api_key, true);
      }

      const projectRef = db.collection("projects").doc(api_key);
      const now = Timestamp.now();
      let ingestedCount = 0;

      // 5. Process events in batches of 250 (Firestore batch limit is 500 ops,
      //    each event can produce ~2-4 writes)
      const CHUNK_SIZE = 100;
      for (let i = 0; i < events.length; i += CHUNK_SIZE) {
        const chunk = events.slice(i, i + CHUNK_SIZE);
        const batch = db.batch();

        for (const event of chunk) {
          // 5a. Deduplication — check if insert_id already exists
          const dedupRef = projectRef
            .collection("dedup")
            .doc(event.insert_id);
          const dedupSnap = await dedupRef.get();

          if (dedupSnap.exists) {
            continue; // Skip duplicate
          }

          // Mark as seen
          batch.set(dedupRef, { t: now });

          // 5b. Write raw event
          const eventRef = projectRef.collection("events").doc();
          const storedEvent: Record<string, unknown> = {
            ...event,
            server_received_time: now,
            timestamp: Timestamp.fromMillis(event.time),
          };

          // Extract revenue amount for fast queries
          if (
            event.event_type === EventTypes.REVENUE &&
            event.event_properties
          ) {
            const price =
              (event.event_properties[RevenueKeys.PRICE] as number) || 0;
            const quantity =
              (event.event_properties[RevenueKeys.QUANTITY] as number) || 1;
            storedEvent.revenue_amount = price * quantity;
          }

          batch.set(eventRef, storedEvent);

          // 5c. Handle special event types
          if (
            event.event_type === EventTypes.IDENTIFY &&
            event.user_properties
          ) {
            // Identify ops need a transaction, do them outside the batch
            const canonicalId = event.user_id || event.device_id;
            const userRef = projectRef
              .collection("users")
              .doc(canonicalId);
            // Queue for after batch commit
            await applyIdentifyOperations(
              db,
              userRef,
              event.user_properties as Record<string, unknown>
            );
          }

          // 5d. Update/create session document
          const sessionRef = projectRef
            .collection("sessions")
            .doc(String(event.session_id));

          if (event.event_type === EventTypes.SESSION_START) {
            batch.set(sessionRef, createSessionDoc(event), { merge: true });
          } else {
            // Update session counters (will create if not exists due to merge)
            batch.set(sessionRef, buildSessionUpdate(event), { merge: true });
          }

          // 5e. Update user document (basic stats)
          const canonicalId = event.user_id || event.device_id;
          const userRef = projectRef.collection("users").doc(canonicalId);
          batch.set(
            userRef,
            {
              user_id: event.user_id || null,
              device_ids: FieldValue.arrayUnion(event.device_id),
              last_seen: now,
              total_events: FieldValue.increment(1),
              last_app_version: event.app_version || "",
              last_device_model: event.device_model || "",
              last_country: event.country || null,
            },
            { merge: true }
          );

          // 5f. Update daily aggregate
          const dateKey = getDateKey(event.time);
          const aggregateRef = projectRef
            .collection("aggregates")
            .doc("daily")
            .collection("data")
            .doc(dateKey);
          batch.set(aggregateRef, buildAggregateUpdate(event), {
            merge: true,
          });

          // 5g. Track unique users per day (for DAU)
          const dauRef = projectRef
            .collection("aggregates")
            .doc("daily_users")
            .collection("data")
            .doc(dateKey);
          batch.set(
            dauRef,
            {
              user_ids: FieldValue.arrayUnion(canonicalId),
              date: dateKey,
            },
            { merge: true }
          );

          ingestedCount++;
        }

        // Commit this chunk
        await batch.commit();
      }

      // 6. Update realtime feed (last 50 events)
      if (events.length > 0) {
        const realtimeEvents = events.slice(-50).map((e) => ({
          event_type: e.event_type,
          user_id: e.user_id || null,
          device_id: e.device_id,
          time: e.time,
          device_model: e.device_model || "",
          app_version: e.app_version || "",
          country: e.country || null,
          event_properties: e.event_properties || null,
        }));

        await projectRef.collection("realtime").doc("latest").set(
          {
            events: realtimeEvents,
            updated_at: now,
          },
          { merge: false }
        );
      }

      // 7. Return success
      res.status(200).json({
        code: 200,
        events_ingested: ingestedCount,
        server_upload_time: new Date().toISOString(),
      });
    } catch (error) {
      console.error("Ingestion error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }
);
