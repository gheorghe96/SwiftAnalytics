import { getDb, API_KEY } from "../firebase";
import {
  collection,
  query,
  orderBy,
  limit,
  startAfter,
  where,
  getDocs,
  DocumentSnapshot,
  onSnapshot,
  doc,
  Unsubscribe,
} from "firebase/firestore";

export interface EventRow {
  id: string;
  event_type: string;
  user_id: string | null;
  device_id: string;
  session_id: number;
  time: number;
  device_model: string;
  app_version: string;
  country: string | null;
  event_properties: Record<string, unknown> | null;
  user_properties: Record<string, unknown> | null;
}

/**
 * Fetch paginated events.
 */
export async function fetchEvents(options: {
  pageSize?: number;
  afterDoc?: DocumentSnapshot;
  eventType?: string;
  userId?: string;
}): Promise<{ events: EventRow[]; lastDoc: DocumentSnapshot | null }> {
  const { pageSize = 25, afterDoc, eventType, userId } = options;
  const colRef = collection(getDb(), "projects", API_KEY, "events");

  const constraints: any[] = [orderBy("timestamp", "desc"), limit(pageSize)];

  if (eventType) {
    constraints.unshift(where("event_type", "==", eventType));
  }

  if (userId) {
    constraints.unshift(where("user_id", "==", userId));
  }

  if (afterDoc) {
    constraints.push(startAfter(afterDoc));
  }

  const q = query(colRef, ...constraints);
  const snap = await getDocs(q);

  const events: EventRow[] = snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      event_type: data.event_type,
      user_id: data.user_id || null,
      device_id: data.device_id,
      session_id: data.session_id,
      time: data.time,
      device_model: data.device_model || "",
      app_version: data.app_version || "",
      country: data.country || null,
      event_properties: data.event_properties || null,
      user_properties: data.user_properties || null,
    };
  });

  const lastDoc = snap.docs.length > 0 ? snap.docs[snap.docs.length - 1] : null;

  return { events, lastDoc };
}

/**
 * Subscribe to realtime events feed.
 */
export function subscribeToRealtimeEvents(
  callback: (events: EventRow[]) => void
): Unsubscribe {
  const docRef = doc(getDb(), "projects", API_KEY, "realtime", "latest");

  return onSnapshot(docRef, (snap) => {
    if (!snap.exists()) {
      callback([]);
      return;
    }
    const data = snap.data();
    const events: EventRow[] = (data.events || []).map(
      (e: any, i: number) => ({
        id: `rt-${i}`,
        event_type: e.event_type,
        user_id: e.user_id || null,
        device_id: e.device_id,
        session_id: 0,
        time: e.time,
        device_model: e.device_model || "",
        app_version: e.app_version || "",
        country: e.country || null,
        event_properties: e.event_properties || null,
        user_properties: null,
      })
    );
    callback(events.reverse());
  });
}
