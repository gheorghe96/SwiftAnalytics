import { getDb, API_KEY } from "../firebase";
import { doc, getDoc, collection, getDocs, query, where, orderBy } from "firebase/firestore";
import { getDateRange } from "../utils/dates";

export interface DailyData {
  date: string;
  dau: number;
  total_events: number;
  total_sessions: number;
  total_revenue: number;
  events_by_type: Record<string, number>;
  by_device_model: Record<string, number>;
  by_country: Record<string, number>;
  by_app_version: Record<string, number>;
  hourly_events: number[];
}

/**
 * Fetch daily aggregates for the last N days.
 */
export async function fetchDailyAggregates(days = 30): Promise<DailyData[]> {
  const dateKeys = getDateRange(days);
  const results: DailyData[] = [];

  const colRef = collection(getDb(), "projects", API_KEY, "aggregates", "daily", "data");

  for (const dateKey of dateKeys) {
    const docRef = doc(colRef, dateKey);
    const snap = await getDoc(docRef);

    if (snap.exists()) {
      const data = snap.data();
      results.push({
        date: dateKey,
        dau: data.dau || 0,
        total_events: data.total_events || 0,
        total_sessions: data.total_sessions || 0,
        total_revenue: data.total_revenue || 0,
        events_by_type: data.events_by_type || {},
        by_device_model: data.by_device_model || {},
        by_country: data.by_country || {},
        by_app_version: data.by_app_version || {},
        hourly_events: data.hourly_events || new Array(24).fill(0),
      });
    } else {
      results.push({
        date: dateKey,
        dau: 0,
        total_events: 0,
        total_sessions: 0,
        total_revenue: 0,
        events_by_type: {},
        by_device_model: {},
        by_country: {},
        by_app_version: {},
        hourly_events: new Array(24).fill(0),
      });
    }
  }

  return results;
}

/**
 * Get today's summary.
 */
export async function fetchTodaySummary(): Promise<DailyData | null> {
  const today = new Date();
  const dateKey = `${today.getUTCFullYear()}-${String(today.getUTCMonth() + 1).padStart(2, "0")}-${String(today.getUTCDate()).padStart(2, "0")}`;

  const docRef = doc(getDb(), "projects", API_KEY, "aggregates", "daily", "data", dateKey);
  const snap = await getDoc(docRef);

  if (!snap.exists()) return null;
  const data = snap.data();

  return {
    date: dateKey,
    dau: data.dau || 0,
    total_events: data.total_events || 0,
    total_sessions: data.total_sessions || 0,
    total_revenue: data.total_revenue || 0,
    events_by_type: data.events_by_type || {},
    by_device_model: data.by_device_model || {},
    by_country: data.by_country || {},
    by_app_version: data.by_app_version || {},
    hourly_events: data.hourly_events || new Array(24).fill(0),
  };
}
