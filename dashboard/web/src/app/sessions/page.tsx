"use client";

import { useEffect, useState } from "react";
import DataTable, { Column } from "@/components/tables/DataTable";
import { fetchSessions, SessionRow } from "@/lib/queries/sessions";
import { formatDateTime, formatDuration } from "@/lib/utils/dates";
import { formatNumber } from "@/lib/utils/numbers";
import { useCurrentApiKey } from "@/lib/hooks/useCurrentApiKey";

export default function SessionsPage() {
  const apiKey = useCurrentApiKey();
  const [sessions, setSessions] = useState<SessionRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!apiKey) return;
    setLoading(true);
    fetchSessions(apiKey, { pageSize: 50 })
      .then((result) => setSessions(result.sessions))
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [apiKey]);

  const columns: Column<SessionRow>[] = [
    {
      key: "start_time",
      header: "Start Time",
      render: (row) => (
        <span className="text-xs text-gray-500 font-mono">
          {formatDateTime(row.start_time)}
        </span>
      ),
    },
    {
      key: "user_id",
      header: "User",
      render: (row) => (
        <span className="text-xs font-mono text-gray-600">
          {row.user_id || row.device_id.slice(0, 12) + "..."}
        </span>
      ),
    },
    {
      key: "duration_ms",
      header: "Duration",
      render: (row) => (
        <span className="text-sm">
          {row.duration_ms ? formatDuration(row.duration_ms) : "-"}
        </span>
      ),
    },
    {
      key: "event_count",
      header: "Events",
      render: (row) => (
        <span className="text-sm">{formatNumber(row.event_count)}</span>
      ),
    },
    {
      key: "is_completed",
      header: "Status",
      render: (row) => (
        <span
          className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
            row.is_completed
              ? "bg-green-50 text-green-700"
              : "bg-yellow-50 text-yellow-700"
          }`}
        >
          {row.is_completed ? "Completed" : "Active"}
        </span>
      ),
    },
    {
      key: "has_crash",
      header: "Crash",
      render: (row) =>
        row.has_crash ? (
          <span className="text-xs text-red-600 font-medium">Yes</span>
        ) : (
          <span className="text-xs text-gray-300">-</span>
        ),
    },
    {
      key: "device_model",
      header: "Device",
      render: (row) => (
        <span className="text-xs text-gray-500">{row.device_model}</span>
      ),
    },
    {
      key: "country",
      header: "Country",
      render: (row) => (
        <span className="text-xs text-gray-500">{row.country || "-"}</span>
      ),
    },
  ];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Sessions</h1>
      <DataTable
        columns={columns}
        data={sessions}
        loading={loading}
        emptyMessage="No sessions found"
      />
    </div>
  );
}
