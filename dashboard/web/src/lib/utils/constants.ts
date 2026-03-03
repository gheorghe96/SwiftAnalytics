export const EVENT_COLORS: Record<string, string> = {
  "[SA] Application Opened": "#3b82f6",
  "[SA] Screen Viewed": "#8b5cf6",
  "[SA] Session Start": "#10b981",
  "[SA] Session End": "#ef4444",
  "[SA] Application Installed": "#f59e0b",
  "[SA] Application Updated": "#06b6d4",
  "[SA] Application Backgrounded": "#6b7280",
  "[SA] Application Crashed": "#dc2626",
  "[SA] Deep Link Opened": "#ec4899",
  "[SA] Push Notification Opened": "#f97316",
  "$revenue": "#22c55e",
  "$identify": "#a855f7",
};

export const CHART_COLORS = [
  "#3b82f6",
  "#8b5cf6",
  "#10b981",
  "#f59e0b",
  "#ef4444",
  "#06b6d4",
  "#ec4899",
  "#f97316",
  "#84cc16",
  "#6366f1",
];

export function getEventColor(eventType: string): string {
  return EVENT_COLORS[eventType] || "#6b7280";
}
