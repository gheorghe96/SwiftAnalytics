"use client";

import { useEffect, useState, useCallback } from "react";
import DataTable, { Column } from "@/components/tables/DataTable";
import { fetchEvents, EventRow } from "@/lib/queries/events";
import { formatDateTime } from "@/lib/utils/dates";
import { getEventColor } from "@/lib/utils/constants";
import { DocumentSnapshot } from "firebase/firestore";

export default function EventsPage() {
  const [events, setEvents] = useState<EventRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [lastDoc, setLastDoc] = useState<DocumentSnapshot | null>(null);
  const [filter, setFilter] = useState("");
  const [selectedEvent, setSelectedEvent] = useState<EventRow | null>(null);

  const loadEvents = useCallback(
    async (reset = false) => {
      setLoading(true);
      try {
        const result = await fetchEvents({
          pageSize: 50,
          afterDoc: reset ? undefined : lastDoc ?? undefined,
          eventType: filter || undefined,
        });
        if (reset) {
          setEvents(result.events);
        } else {
          setEvents((prev) => [...prev, ...result.events]);
        }
        setLastDoc(result.lastDoc);
      } catch (err) {
        console.error("Failed to fetch events:", err);
      } finally {
        setLoading(false);
      }
    },
    [filter, lastDoc]
  );

  useEffect(() => {
    loadEvents(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter]);

  const columns: Column<EventRow>[] = [
    {
      key: "time",
      header: "Time",
      render: (row) => (
        <span className="text-xs text-gray-500 font-mono">
          {formatDateTime(row.time)}
        </span>
      ),
      className: "w-44",
    },
    {
      key: "event_type",
      header: "Event Type",
      render: (row) => (
        <span className="flex items-center gap-2">
          <span
            className="w-2 h-2 rounded-full"
            style={{ backgroundColor: getEventColor(row.event_type) }}
          />
          <span className="font-medium text-sm">{row.event_type}</span>
        </span>
      ),
    },
    {
      key: "user_id",
      header: "User",
      render: (row) => (
        <span className="text-xs font-mono text-gray-500">
          {row.user_id || row.device_id.slice(0, 12) + "..."}
        </span>
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
      key: "app_version",
      header: "Version",
      render: (row) => (
        <span className="text-xs text-gray-400">{row.app_version}</span>
      ),
    },
  ];

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Events</h1>
        <div className="flex items-center gap-3">
          <input
            type="text"
            placeholder="Filter by event type..."
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 w-64"
          />
        </div>
      </div>

      <DataTable<EventRow>
        columns={columns}
        data={events}
        loading={loading}
        emptyMessage="No events found"
        onRowClick={(row) => setSelectedEvent(row)}
      />

      {lastDoc && events.length >= 50 && (
        <div className="mt-4 text-center">
          <button
            onClick={() => loadEvents(false)}
            className="px-4 py-2 text-sm font-medium text-primary-600 bg-primary-50 rounded-lg hover:bg-primary-100 transition-colors"
          >
            Load more
          </button>
        </div>
      )}

      {/* Event Detail Panel */}
      {selectedEvent && (
        <div className="fixed inset-0 bg-black/30 flex justify-end z-50">
          <div className="bg-white w-[480px] h-full overflow-y-auto shadow-xl">
            <div className="p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-lg font-bold">{selectedEvent.event_type}</h2>
                <button
                  onClick={() => setSelectedEvent(null)}
                  className="text-gray-400 hover:text-gray-600 text-xl"
                >
                  x
                </button>
              </div>

              <div className="space-y-4">
                <DetailRow label="Time" value={formatDateTime(selectedEvent.time)} />
                <DetailRow label="User ID" value={selectedEvent.user_id || "N/A"} />
                <DetailRow label="Device ID" value={selectedEvent.device_id} />
                <DetailRow label="Device" value={selectedEvent.device_model} />
                <DetailRow label="App Version" value={selectedEvent.app_version} />
                <DetailRow label="Country" value={selectedEvent.country || "N/A"} />

                {selectedEvent.event_properties && (
                  <div>
                    <p className="text-xs text-gray-500 font-semibold uppercase mb-2">
                      Event Properties
                    </p>
                    <pre className="bg-gray-50 rounded-lg p-3 text-xs text-gray-700 overflow-x-auto">
                      {JSON.stringify(selectedEvent.event_properties, null, 2)}
                    </pre>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs text-gray-500 font-semibold uppercase">{label}</p>
      <p className="text-sm text-gray-800 font-mono mt-0.5">{value}</p>
    </div>
  );
}
