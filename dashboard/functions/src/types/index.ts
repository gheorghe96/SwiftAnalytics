import { Timestamp } from "firebase-admin/firestore";

// ── Ingestion Payload (matches SDK's SAUploader.buildPayload) ──

export interface IngestPayload {
  api_key: string;
  events: RawEvent[];
  options?: { min_id_length?: number };
}

// ── Raw Event (matches SDK's SAEvent.toJSON()) ──

export interface RawEvent {
  // Identity
  user_id?: string;
  device_id: string;
  session_id: number;
  insert_id: string;
  event_id: number;

  // Event
  event_type: string;
  event_properties?: Record<string, unknown>;
  user_properties?: Record<string, unknown>;
  groups?: Record<string, unknown>;
  group_properties?: Record<string, unknown>;

  // Timestamps
  time: number; // ms since epoch
  client_event_time?: string;
  client_upload_time?: string;

  // Device
  platform: string;
  os_name: string;
  os_version: string;
  device_model: string;
  device_family: string;
  device_brand: string;
  screen_width?: number;
  screen_height?: number;
  screen_density?: number;

  // App
  app_version: string;
  app_build: string;
  library: string;

  // Network
  carrier?: string;
  network_type?: string;
  cellular_technology?: string;

  // Geo
  country?: string;
  country_code?: string;
  region?: string;
  city?: string;
  dma?: string;

  // GPS
  location_lat?: number;
  location_lng?: number;

  // Attribution
  utm_source?: string;
  utm_medium?: string;
  utm_campaign?: string;
  utm_term?: string;
  utm_content?: string;
  referrer?: string;

  // Locale
  language: string;
  locale: string;
  timezone: string;

  // Identifiers
  idfv?: string;
  idfa?: string;

  // Internal
  ip?: string;
}

// ── Firestore Document Types ──

export interface ProjectDoc {
  name: string;
  created_at: Timestamp;
  settings: {
    retention_days: number;
    rate_limit_per_minute: number;
  };
}

export interface StoredEvent extends RawEvent {
  server_received_time: Timestamp;
  timestamp: Timestamp;
  revenue_amount?: number;
}

export interface UserDoc {
  user_id: string | null;
  device_ids: string[];
  properties: Record<string, unknown>;
  first_seen: Timestamp;
  last_seen: Timestamp;
  total_events: number;
  total_sessions: number;
  total_revenue: number;
  last_app_version: string;
  last_device_model: string;
  last_country: string | null;
}

export interface SessionDoc {
  session_id: number;
  user_id: string | null;
  device_id: string;
  start_time: Timestamp;
  end_time: Timestamp | null;
  duration_ms: number | null;
  event_count: number;
  has_crash: boolean;
  has_revenue: boolean;
  revenue_total: number;
  is_completed: boolean;
  app_version: string;
  os_version: string;
  device_model: string;
  country: string | null;
}

export interface DailyAggregate {
  date: string;
  timestamp: Timestamp;
  dau: number;
  new_users: number;
  total_events: number;
  events_by_type: Record<string, number>;
  total_sessions: number;
  avg_session_duration_ms: number;
  total_revenue: number;
  by_device_model: Record<string, number>;
  by_country: Record<string, number>;
  by_app_version: Record<string, number>;
  by_os_version: Record<string, number>;
  by_network_type: Record<string, number>;
  hourly_events: number[];
}

// ── Constants matching SDK's SAConstants ──

export const EventTypes = {
  APPLICATION_INSTALLED: "[SA] Application Installed",
  APPLICATION_UPDATED: "[SA] Application Updated",
  APPLICATION_OPENED: "[SA] Application Opened",
  APPLICATION_BACKGROUNDED: "[SA] Application Backgrounded",
  APPLICATION_CRASHED: "[SA] Application Crashed",
  SESSION_START: "[SA] Session Start",
  SESSION_END: "[SA] Session End",
  SCREEN_VIEWED: "[SA] Screen Viewed",
  DEEP_LINK_OPENED: "[SA] Deep Link Opened",
  PUSH_NOTIFICATION_OPENED: "[SA] Push Notification Opened",
  PUSH_NOTIFICATION_RECEIVED: "[SA] Push Notification Received",
  REVENUE: "$revenue",
  IDENTIFY: "$identify",
  GROUP_IDENTIFY: "$groupidentify",
} as const;

export const RevenueKeys = {
  PRODUCT_ID: "$productId",
  PRICE: "$price",
  QUANTITY: "$quantity",
  REVENUE: "$revenue",
  REVENUE_TYPE: "$revenueType",
  CURRENCY: "$currency",
} as const;

export const IdentifyOps = {
  SET: "$set",
  SET_ONCE: "$setOnce",
  ADD: "$add",
  APPEND: "$append",
  PREPEND: "$prepend",
  POST_INSERT: "$postInsert",
  PRE_INSERT: "$preInsert",
  REMOVE: "$remove",
  UNSET: "$unset",
  CLEAR_ALL: "$clearAll",
} as const;
