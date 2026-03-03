import { getDb, API_KEY } from "../firebase";
import {
  collection,
  query,
  orderBy,
  limit,
  startAfter,
  getDocs,
  doc,
  getDoc,
  DocumentSnapshot,
} from "firebase/firestore";

export interface UserRow {
  id: string;
  user_id: string | null;
  device_ids: string[];
  first_seen: number;
  last_seen: number;
  total_events: number;
  total_sessions: number;
  total_revenue: number;
  last_app_version: string;
  last_device_model: string;
  last_country: string | null;
  properties: Record<string, unknown>;
}

/**
 * Fetch paginated users.
 */
export async function fetchUsers(options: {
  pageSize?: number;
  afterDoc?: DocumentSnapshot;
}): Promise<{ users: UserRow[]; lastDoc: DocumentSnapshot | null }> {
  const { pageSize = 25, afterDoc } = options;
  const colRef = collection(getDb(), "projects", API_KEY, "users");

  const constraints: any[] = [orderBy("last_seen", "desc"), limit(pageSize)];

  if (afterDoc) {
    constraints.push(startAfter(afterDoc));
  }

  const q = query(colRef, ...constraints);
  const snap = await getDocs(q);

  const users: UserRow[] = snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      user_id: data.user_id || null,
      device_ids: data.device_ids || [],
      first_seen: data.first_seen?.toMillis?.() || 0,
      last_seen: data.last_seen?.toMillis?.() || 0,
      total_events: data.total_events || 0,
      total_sessions: data.total_sessions || 0,
      total_revenue: data.total_revenue || 0,
      last_app_version: data.last_app_version || "",
      last_device_model: data.last_device_model || "",
      last_country: data.last_country || null,
      properties: data.properties || {},
    };
  });

  const lastDoc = snap.docs.length > 0 ? snap.docs[snap.docs.length - 1] : null;

  return { users, lastDoc };
}

/**
 * Fetch a single user by ID.
 */
export async function fetchUser(userId: string): Promise<UserRow | null> {
  const docRef = doc(getDb(), "projects", API_KEY, "users", userId);
  const snap = await getDoc(docRef);

  if (!snap.exists()) return null;
  const data = snap.data();

  return {
    id: snap.id,
    user_id: data.user_id || null,
    device_ids: data.device_ids || [],
    first_seen: data.first_seen?.toMillis?.() || 0,
    last_seen: data.last_seen?.toMillis?.() || 0,
    total_events: data.total_events || 0,
    total_sessions: data.total_sessions || 0,
    total_revenue: data.total_revenue || 0,
    last_app_version: data.last_app_version || "",
    last_device_model: data.last_device_model || "",
    last_country: data.last_country || null,
    properties: data.properties || {},
  };
}
