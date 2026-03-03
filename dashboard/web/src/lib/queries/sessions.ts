import { getDb } from "../firebase";
import {
  collection,
  query,
  orderBy,
  limit,
  startAfter,
  where,
  getDocs,
  DocumentSnapshot,
} from "firebase/firestore";

export interface SessionRow {
  id: string;
  session_id: number;
  user_id: string | null;
  device_id: string;
  start_time: number;
  end_time: number | null;
  duration_ms: number | null;
  event_count: number;
  has_crash: boolean;
  has_revenue: boolean;
  revenue_total: number;
  is_completed: boolean;
  app_version: string;
  device_model: string;
  country: string | null;
}

/**
 * Fetch paginated sessions.
 */
export async function fetchSessions(
  apiKey: string,
  options: {
    pageSize?: number;
    afterDoc?: DocumentSnapshot;
    completed?: boolean;
  }
): Promise<{ sessions: SessionRow[]; lastDoc: DocumentSnapshot | null }> {
  const { pageSize = 25, afterDoc, completed } = options;
  const colRef = collection(getDb(), "projects", apiKey, "sessions");

  const constraints: any[] = [orderBy("start_time", "desc"), limit(pageSize)];

  if (completed !== undefined) {
    constraints.unshift(where("is_completed", "==", completed));
  }

  if (afterDoc) {
    constraints.push(startAfter(afterDoc));
  }

  const q = query(colRef, ...constraints);
  const snap = await getDocs(q);

  const sessions: SessionRow[] = snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      session_id: data.session_id,
      user_id: data.user_id || null,
      device_id: data.device_id || "",
      start_time: data.start_time?.toMillis?.() || 0,
      end_time: data.end_time?.toMillis?.() || null,
      duration_ms: data.duration_ms || null,
      event_count: data.event_count || 0,
      has_crash: data.has_crash || false,
      has_revenue: data.has_revenue || false,
      revenue_total: data.revenue_total || 0,
      is_completed: data.is_completed || false,
      app_version: data.app_version || "",
      device_model: data.device_model || "",
      country: data.country || null,
    };
  });

  const lastDoc = snap.docs.length > 0 ? snap.docs[snap.docs.length - 1] : null;

  return { sessions, lastDoc };
}
