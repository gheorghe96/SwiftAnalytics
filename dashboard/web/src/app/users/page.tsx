"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import DataTable, { Column } from "@/components/tables/DataTable";
import { fetchUsers, fetchUser, UserRow } from "@/lib/queries/users";
import { fetchEvents, EventRow } from "@/lib/queries/events";
import { formatDateTime } from "@/lib/utils/dates";
import { formatNumber, formatCurrency } from "@/lib/utils/numbers";
import { getEventColor } from "@/lib/utils/constants";
import { ArrowLeft } from "lucide-react";
import { useCurrentApiKey } from "@/lib/hooks/useCurrentApiKey";

export default function UsersPage() {
  return (
    <Suspense fallback={<div className="flex items-center justify-center h-64 text-gray-400">Loading...</div>}>
      <UsersPageContent />
    </Suspense>
  );
}

function UsersPageContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const selectedId = searchParams.get("id");

  if (selectedId) {
    return <UserDetail userId={selectedId} onBack={() => router.push("/users")} />;
  }

  return <UserList />;
}

function UserList() {
  const apiKey = useCurrentApiKey();
  const [users, setUsers] = useState<UserRow[]>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    if (!apiKey) return;
    setLoading(true);
    fetchUsers(apiKey, { pageSize: 50 })
      .then((result) => setUsers(result.users))
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [apiKey]);

  const columns: Column<UserRow>[] = [
    {
      key: "id",
      header: "User / Device",
      render: (row) => (
        <div>
          <p className="font-medium text-sm">
            {row.user_id || row.id.slice(0, 16) + "..."}
          </p>
          {row.user_id && (
            <p className="text-xs text-gray-400 font-mono">
              {row.device_ids[0]?.slice(0, 12)}...
            </p>
          )}
        </div>
      ),
    },
    {
      key: "total_events",
      header: "Events",
      render: (row) => (
        <span className="text-sm">{formatNumber(row.total_events)}</span>
      ),
    },
    {
      key: "total_sessions",
      header: "Sessions",
      render: (row) => (
        <span className="text-sm">{formatNumber(row.total_sessions)}</span>
      ),
    },
    {
      key: "total_revenue",
      header: "Revenue",
      render: (row) => (
        <span className="text-sm">
          {row.total_revenue > 0 ? formatCurrency(row.total_revenue) : "-"}
        </span>
      ),
    },
    {
      key: "last_seen",
      header: "Last Seen",
      render: (row) => (
        <span className="text-xs text-gray-500">
          {row.last_seen ? formatDateTime(row.last_seen) : "-"}
        </span>
      ),
    },
    {
      key: "last_country",
      header: "Country",
      render: (row) => (
        <span className="text-xs text-gray-500">{row.last_country || "-"}</span>
      ),
    },
    {
      key: "last_device_model",
      header: "Device",
      render: (row) => (
        <span className="text-xs text-gray-500">{row.last_device_model}</span>
      ),
    },
  ];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Users</h1>
      <DataTable
        columns={columns}
        data={users}
        loading={loading}
        emptyMessage="No users found"
        onRowClick={(row) => router.push(`/users?id=${(row as UserRow).id}`)}
      />
    </div>
  );
}

function UserDetail({ userId, onBack }: { userId: string; onBack: () => void }) {
  const apiKey = useCurrentApiKey();
  const [user, setUser] = useState<UserRow | null>(null);
  const [events, setEvents] = useState<EventRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!apiKey) return;
    setLoading(true);
    Promise.all([
      fetchUser(apiKey, userId),
      fetchEvents(apiKey, { userId, pageSize: 50 }),
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
      <button
        onClick={onBack}
        className="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 mb-4"
      >
        <ArrowLeft size={14} /> Back to Users
      </button>

      <h1 className="text-2xl font-bold mb-6">
        {user.user_id || user.id.slice(0, 20) + "..."}
      </h1>

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
