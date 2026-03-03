import { z } from "zod";

// Zod schema for the raw event — matches SDK's SAEvent.toJSON()
const rawEventSchema = z.object({
  user_id: z.string().optional(),
  device_id: z.string().min(1),
  session_id: z.number(),
  insert_id: z.string().min(1),
  event_id: z.number(),
  event_type: z.string().min(1),
  event_properties: z.record(z.unknown()).optional(),
  user_properties: z.record(z.unknown()).optional(),
  groups: z.record(z.unknown()).optional(),
  group_properties: z.record(z.unknown()).optional(),
  time: z.number(),
  client_event_time: z.string().optional(),
  client_upload_time: z.string().optional(),
  platform: z.string().default("iOS"),
  os_name: z.string().default("ios"),
  os_version: z.string().default(""),
  device_model: z.string().default(""),
  device_family: z.string().default(""),
  device_brand: z.string().default("Apple"),
  screen_width: z.number().optional(),
  screen_height: z.number().optional(),
  screen_density: z.number().optional(),
  app_version: z.string().default(""),
  app_build: z.string().default(""),
  library: z.string().default(""),
  carrier: z.string().optional(),
  network_type: z.string().optional(),
  cellular_technology: z.string().optional(),
  country: z.string().optional(),
  country_code: z.string().optional(),
  region: z.string().optional(),
  city: z.string().optional(),
  dma: z.string().optional(),
  location_lat: z.number().optional(),
  location_lng: z.number().optional(),
  utm_source: z.string().optional(),
  utm_medium: z.string().optional(),
  utm_campaign: z.string().optional(),
  utm_term: z.string().optional(),
  utm_content: z.string().optional(),
  referrer: z.string().optional(),
  language: z.string().default(""),
  locale: z.string().default(""),
  timezone: z.string().default(""),
  idfv: z.string().optional(),
  idfa: z.string().optional(),
  ip: z.string().optional(),
});

// Full ingestion payload schema
const ingestPayloadSchema = z.object({
  api_key: z.string().min(1),
  events: z.array(rawEventSchema).min(1).max(2000),
  options: z
    .object({
      min_id_length: z.number().optional(),
    })
    .optional(),
});

export type ValidatedPayload = z.infer<typeof ingestPayloadSchema>;

export function validatePayload(body: unknown): {
  success: boolean;
  data?: ValidatedPayload;
  error?: string;
} {
  const result = ingestPayloadSchema.safeParse(body);
  if (result.success) {
    return { success: true, data: result.data };
  }
  const messages = result.error.issues
    .map((i) => `${i.path.join(".")}: ${i.message}`)
    .slice(0, 5)
    .join("; ");
  return { success: false, error: `Validation failed: ${messages}` };
}
