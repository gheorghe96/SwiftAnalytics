import { Timestamp, FieldValue } from "firebase-admin/firestore";
import { RawEvent, EventTypes } from "../types";

/**
 * Build a new session document from a Session Start event.
 */
export function createSessionDoc(event: RawEvent): Record<string, unknown> {
  return {
    session_id: event.session_id,
    user_id: event.user_id || null,
    device_id: event.device_id,
    start_time: Timestamp.fromMillis(event.time),
    end_time: null,
    duration_ms: null,
    event_count: 1,
    has_crash: false,
    has_revenue: false,
    revenue_total: 0,
    is_completed: false,
    app_version: event.app_version || "",
    os_version: event.os_version || "",
    device_model: event.device_model || "",
    country: event.country || null,
  };
}

/**
 * Build an update object for a session based on the incoming event.
 */
export function buildSessionUpdate(event: RawEvent): Record<string, unknown> {
  const update: Record<string, unknown> = {
    event_count: FieldValue.increment(1),
  };

  if (event.event_type === EventTypes.SESSION_END) {
    update.end_time = Timestamp.fromMillis(event.time);
    update.is_completed = true;

    // Extract session duration from event properties if available
    if (event.event_properties?.session_duration_ms) {
      update.duration_ms = event.event_properties.session_duration_ms;
    }
  }

  if (event.event_type === EventTypes.APPLICATION_CRASHED) {
    update.has_crash = true;
  }

  if (event.event_type === EventTypes.REVENUE) {
    update.has_revenue = true;
    const price = (event.event_properties?.["$price"] as number) || 0;
    const quantity = (event.event_properties?.["$quantity"] as number) || 1;
    update.revenue_total = FieldValue.increment(price * quantity);
  }

  return update;
}
