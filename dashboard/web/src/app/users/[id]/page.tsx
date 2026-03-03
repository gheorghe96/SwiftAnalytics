"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { fetchUser, UserRow } from "@/lib/queries/users";
import { fetchEvents, EventRow } from "@/lib/queries/events";
import { formatDateTime } from "@/lib/utils/dates";
import { formatNumber, formatCurrency } from "@/lib/utils/numbers";
import { getEventColor } from "@/lib/utils/constants";
import DataTable, { Column } from "@/components/tables/DataTable";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";

export default function UserDetailPage() {
  const params = useParams();
  const userId = params.id as string;
  const [user, setUser] = useState<UserRow | null>(null);
  const [events, setEvents] = useState<EventRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!userId) return;

    Promise.all([
      fetchUser(userId),
      fetchEvents({ userId, pageSize: 50 }),
    ])
      .then(([userData, eventsData]) => {
        setUser(userData);
        setEvents(eventsData.events);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [userId]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-gray-400">
        Loading user...
      </div>
    );
  }

  if (!user) {
    return (
      <div className="text-center py-12 text-gray-500">User not found</div>
    );
  }

  const eventColumns: Column<EventRow>[] = [
    {
      key: "time",
      header: "Time",
      render: (row) => (
        <span className="text-xs text-gray-500 font-mono">
          {formatDateTime(row.time)}
        </span>
      ),
    },
    {
      key: "event_type",
      header: "Event",
      render: (row) => (
        <span className="flex items-center gap-2">
          <span
            className="w-2 h-2 rounded-full"
            style={{ backgroundColor: getEventColor(row.event_type) }}
          />
          <span className="text-sm">{row.event_type}</span>
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
  ];

  return (
    <div>
      <Link
        href="/users"
        className="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 mb-4"
      >
        <ArrowLeft size={14} /> Back to Users
      </Link>

      <h1 className="text-2xl font-bold mb-6">
        {user.user_id || user.id.slice(0, 20) + "..."}
      </h1>

      {/* User Info */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <InfoCard label="Total Events" value={formatNumber(user.total_events)} />
        <InfoCard label="Total Sessions" value={formatNumber(user.total_sessions)} />
        <InfoCard
          label="Revenue"
          value={user.total_revenue > 0 ? formatCurrency(user.total_revenue) : "$0.00"}
        />
        <InfoCard
          label="Last Seen"
          value={user.last_seen ? formatDateTime(user.last_seen) : "-"}
        />
      </div>

      {/* User Properties */}
      {Object.keys(user.properties).length > 0 && (
        <div className="bg-white rounded-xl border border-gray-200 p-6 mb-6">
          <h3 className="text-sm font-semibold text-gray-700 mb-3">
            User Properties
          </h3>
          <pre className="bg-gray-50 rounded-lg p-4 text-xs text-gray-700 overflow-x-auto">
            {JSON.stringify(user.properties, null, 2)}
          </pre>
        </div>
      )}

      {/* Event Timeline */}
      <h3 className="text-sm font-semibold text-gray-700 mb-3">
        Event Timeline
      </h3>
      <DataTable
        columns={eventColumns}
        data={events}
        emptyMessage="No events for this user"
      />
    </div>
  );
}

function InfoCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-4">
      <p className="text-xs text-gray-500 font-medium">{label}</p>
      <p className="text-lg font-bold mt-1">{value}</p>
    </div>
  );
}
