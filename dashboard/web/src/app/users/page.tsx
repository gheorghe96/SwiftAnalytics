"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import DataTable, { Column } from "@/components/tables/DataTable";
import { fetchUsers, UserRow } from "@/lib/queries/users";
import { formatDateTime } from "@/lib/utils/dates";
import { formatNumber, formatCurrency } from "@/lib/utils/numbers";

export default function UsersPage() {
  const [users, setUsers] = useState<UserRow[]>([]);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    fetchUsers({ pageSize: 50 })
      .then((result) => setUsers(result.users))
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

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
          {row.total_revenue > 0
            ? formatCurrency(row.total_revenue)
            : "-"}
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
        onRowClick={(row) => router.push(`/users/${(row as UserRow).id}`)}
      />
    </div>
  );
}
