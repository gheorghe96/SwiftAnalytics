"use client";

import { useEffect, useState } from "react";
import { DollarSign, TrendingUp, ShoppingCart, Users } from "lucide-react";
import MetricCard from "@/components/charts/MetricCard";
import LineChart from "@/components/charts/LineChart";
import DataTable, { Column } from "@/components/tables/DataTable";
import { fetchDailyAggregates, DailyData } from "@/lib/queries/aggregates";
import { fetchEvents, EventRow } from "@/lib/queries/events";
import { formatCurrency, formatNumber } from "@/lib/utils/numbers";
import { formatDateTime } from "@/lib/utils/dates";

export default function RevenuePage() {
  const [dailyData, setDailyData] = useState<DailyData[]>([]);
  const [revenueEvents, setRevenueEvents] = useState<EventRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      fetchDailyAggregates(30),
      fetchEvents({ eventType: "$revenue", pageSize: 50 }),
    ])
      .then(([aggregates, eventsResult]) => {
        setDailyData(aggregates);
        setRevenueEvents(eventsResult.events);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-gray-400">
        Loading revenue data...
      </div>
    );
  }

  const totalRevenue = dailyData.reduce((sum, d) => sum + d.total_revenue, 0);
  const totalDAU = dailyData.reduce((sum, d) => sum + d.dau, 0);
  const arpu = totalDAU > 0 ? totalRevenue / totalDAU : 0;
  const transactionCount = revenueEvents.length;

  const todayRevenue = dailyData[dailyData.length - 1]?.total_revenue || 0;

  const revenueTrend = dailyData.map((d) => ({
    date: d.date.slice(5),
    revenue: d.total_revenue,
  }));

  const txColumns: Column<EventRow>[] = [
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
      key: "product",
      header: "Product",
      render: (row) => (
        <span className="text-sm font-medium">
          {(row.event_properties?.["$productId"] as string) || "N/A"}
        </span>
      ),
    },
    {
      key: "amount",
      header: "Amount",
      render: (row) => {
        const price = (row.event_properties?.["$price"] as number) || 0;
        const qty = (row.event_properties?.["$quantity"] as number) || 1;
        return (
          <span className="text-sm font-semibold text-green-700">
            {formatCurrency(price * qty)}
          </span>
        );
      },
    },
    {
      key: "type",
      header: "Type",
      render: (row) => (
        <span className="text-xs text-gray-500">
          {(row.event_properties?.["$revenueType"] as string) || "purchase"}
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
  ];

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Revenue</h1>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <MetricCard
          title="Total Revenue (30d)"
          value={formatCurrency(totalRevenue)}
          icon={DollarSign}
          iconColor="text-emerald-600"
        />
        <MetricCard
          title="Revenue Today"
          value={formatCurrency(todayRevenue)}
          icon={TrendingUp}
          iconColor="text-green-600"
        />
        <MetricCard
          title="ARPU (30d)"
          value={formatCurrency(arpu)}
          icon={Users}
          iconColor="text-blue-600"
        />
        <MetricCard
          title="Transactions"
          value={formatNumber(transactionCount)}
          icon={ShoppingCart}
          iconColor="text-purple-600"
        />
      </div>

      <div className="mb-8">
        <LineChart
          title="Daily Revenue"
          data={revenueTrend}
          xKey="date"
          yKey="revenue"
          color="#22c55e"
        />
      </div>

      <h2 className="text-lg font-semibold mb-3">Recent Transactions</h2>
      <DataTable
        columns={txColumns}
        data={revenueEvents}
        emptyMessage="No revenue events found"
      />
    </div>
  );
}
