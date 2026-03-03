import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { RawEvent, EventTypes, RevenueKeys } from "../types";

/**
 * Build the Firestore update object for daily aggregate counters.
 * Uses FieldValue.increment() for atomic updates.
 */
export function buildAggregateUpdate(event: RawEvent): Record<string, unknown> {
  const eventDate = new Date(event.time);
  const hour = eventDate.getUTCHours();

  // Sanitize event type for use as Firestore field key (dots not allowed)
  const safeEventType = event.event_type.replace(/\./g, "_");

  const update: Record<string, unknown> = {
    total_events: FieldValue.increment(1),
    [`events_by_type.${safeEventType}`]: FieldValue.increment(1),
    [`hourly_events.${hour}`]: FieldValue.increment(1),
  };

  // Device breakdown
  if (event.device_model) {
    const safeModel = event.device_model.replace(/\./g, "_");
    update[`by_device_model.${safeModel}`] = FieldValue.increment(1);
  }

  // Country breakdown
  if (event.country) {
    update[`by_country.${event.country}`] = FieldValue.increment(1);
  }

  // App version breakdown
  if (event.app_version) {
    const safeVersion = event.app_version.replace(/\./g, "_");
    update[`by_app_version.${safeVersion}`] = FieldValue.increment(1);
  }

  // OS version breakdown
  if (event.os_version) {
    const safeOS = event.os_version.replace(/\./g, "_");
    update[`by_os_version.${safeOS}`] = FieldValue.increment(1);
  }

  // Network type breakdown
  if (event.network_type) {
    update[`by_network_type.${event.network_type}`] = FieldValue.increment(1);
  }

  // Session counting
  if (event.event_type === EventTypes.SESSION_START) {
    update.total_sessions = FieldValue.increment(1);
  }

  // Revenue
  if (event.event_type === EventTypes.REVENUE && event.event_properties) {
    const price =
      (event.event_properties[RevenueKeys.PRICE] as number) || 0;
    const quantity =
      (event.event_properties[RevenueKeys.QUANTITY] as number) || 1;
    const revenueAmount = price * quantity;
    update.total_revenue = FieldValue.increment(revenueAmount);
  }

  return update;
}

/**
 * Get the date string for an event timestamp (UTC).
 */
export function getDateKey(timeMs: number): string {
  const d = new Date(timeMs);
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

/**
 * Initial aggregate document structure for a new day.
 */
export function createDailyAggregate(date: string): Record<string, unknown> {
  return {
    date,
    timestamp: Timestamp.now(),
    dau: 0,
    new_users: 0,
    total_events: 0,
    events_by_type: {},
    total_sessions: 0,
    avg_session_duration_ms: 0,
    total_revenue: 0,
    by_device_model: {},
    by_country: {},
    by_app_version: {},
    by_os_version: {},
    by_network_type: {},
    hourly_events: new Array(24).fill(0),
  };
}
