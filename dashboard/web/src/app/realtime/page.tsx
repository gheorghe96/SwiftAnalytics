"use client";

import { useEffect, useState } from "react";
import { Radio } from "lucide-react";
import { subscribeToRealtimeEvents, EventRow } from "@/lib/queries/events";
import { formatDateTime } from "@/lib/utils/dates";
import { getEventColor } from "@/lib/utils/constants";

export default function RealtimePage() {
  const [events, setEvents] = useState<EventRow[]>([]);
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    const unsubscribe = subscribeToRealtimeEvents((newEvents) => {
      setEvents(newEvents);
      setConnected(true);
    });

    return () => unsubscribe();
  }, []);

  return (
    <div>
      <div className="flex items-center gap-3 mb-6">
        <h1 className="text-2xl font-bold">Realtime</h1>
        <span
          className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ${
            connected
              ? "bg-green-50 text-green-700"
              : "bg-gray-100 text-gray-500"
          }`}
        >
          <span
            className={`w-1.5 h-1.5 rounded-full ${
              connected ? "bg-green-500 animate-pulse" : "bg-gray-400"
            }`}
          />
          {connected ? "Live" : "Connecting..."}
        </span>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="px-4 py-3 border-b border-gray-100 bg-gray-50 flex items-center gap-2">
          <Radio size={14} className="text-gray-500" />
          <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
            Live Event Feed
          </span>
          <span className="text-xs text-gray-400 ml-auto">
            {events.length} events
          </span>
        </div>

        <div className="divide-y divide-gray-50 max-h-[70vh] overflow-y-auto">
          {events.length === 0 ? (
            <div className="px-4 py-12 text-center text-gray-400 text-sm">
              Waiting for events...
            </div>
          ) : (
            events.map((event, i) => (
              <div
                key={event.id || i}
                className="px-4 py-3 hover:bg-gray-50 transition-colors flex items-center gap-4"
              >
                <span
                  className="w-2.5 h-2.5 rounded-full flex-shrink-0"
                  style={{ backgroundColor: getEventColor(event.event_type) }}
                />

                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-900 truncate">
                    {event.event_type}
                  </p>
                  <p className="text-xs text-gray-400 mt-0.5">
                    {event.user_id || event.device_id.slice(0, 16) + "..."}
                    {event.country && ` \u00b7 ${event.country}`}
                    {event.device_model && ` \u00b7 ${event.device_model}`}
                  </p>
                </div>

                <span className="text-xs text-gray-400 font-mono flex-shrink-0">
                  {formatDateTime(event.time)}
                </span>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
