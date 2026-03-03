"use client";

import { useEffect, useState } from "react";
import { Users, Zap, Clock, DollarSign } from "lucide-react";
import MetricCard from "@/components/charts/MetricCard";
import LineChart from "@/components/charts/LineChart";
import BarChart from "@/components/charts/BarChart";
import PieChart from "@/components/charts/PieChart";
import { fetchDailyAggregates, DailyData } from "@/lib/queries/aggregates";
import { formatNumber, formatCurrency, formatCompact } from "@/lib/utils/numbers";
import { useCurrentApiKey } from "@/lib/hooks/useCurrentApiKey";

export default function OverviewPage() {
  const apiKey = useCurrentApiKey();
  const [data, setData] = useState<DailyData[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!apiKey) return;
    setLoading(true);
    fetchDailyAggregates(apiKey, 30)
      .then(setData)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [apiKey]);

  if (!apiKey || loading) {
    return (
      <div className="flex items-center justify-center h-64 text-gray-400">
        {!apiKey ? "No app selected" : "Loading analytics..."}
      </div>
    );
  }

  // Compute totals
  const today = data[data.length - 1];
  const totalEvents = data.reduce((sum, d) => sum + d.total_events, 0);
  const totalSessions = data.reduce((sum, d) => sum + d.total_sessions, 0);
  const totalRevenue = data.reduce((sum, d) => sum + d.total_revenue, 0);
  const todayDAU = today?.dau || 0;

  // Event trend data
  const trendData = data.map((d) => ({
    date: d.date.slice(5), // MM-DD
    events: d.total_events,
    users: d.dau,
    sessions: d.total_sessions,
    revenue: d.total_revenue,
  }));

  // Top event types (aggregated across all days)
  const eventTypeTotals: Record<string, number> = {};
  for (const d of data) {
    for (const [type, count] of Object.entries(d.events_by_type)) {
      eventTypeTotals[type] = (eventTypeTotals[type] || 0) + count;
    }
  }
  const topEvents = Object.entries(eventTypeTotals)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 10)
    .map(([name, count]) => ({ name: name.replace(/\[SA\] /g, ""), count }));

  // Device distribution
  const deviceTotals: Record<string, number> = {};
  for (const d of data) {
    for (const [model, count] of Object.entries(d.by_device_model)) {
      deviceTotals[model] = (deviceTotals[model] || 0) + count;
    }
  }
  const deviceData = Object.entries(deviceTotals)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 8)
    .map(([name, value]) => ({ name, value }));

  // Country distribution
  const countryTotals: Record<string, number> = {};
  for (const d of data) {
    for (const [country, count] of Object.entries(d.by_country)) {
      countryTotals[country] = (countryTotals[country] || 0) + count;
    }
  }
  const countryData = Object.entries(countryTotals)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 8)
    .map(([name, count]) => ({ name, count }));

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Overview</h1>

      {/* Metric Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <MetricCard
          title="Daily Active Users"
          value={formatNumber(todayDAU)}
          icon={Users}
          iconColor="text-blue-600"
        />
        <MetricCard
          title="Events (30d)"
          value={formatCompact(totalEvents)}
          icon={Zap}
          iconColor="text-purple-600"
        />
        <MetricCard
          title="Sessions (30d)"
          value={formatCompact(totalSessions)}
          icon={Clock}
          iconColor="text-green-600"
        />
        <MetricCard
          title="Revenue (30d)"
          value={formatCurrency(totalRevenue)}
          icon={DollarSign}
          iconColor="text-emerald-600"
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <LineChart
          title="Daily Active Users"
          data={trendData}
          xKey="date"
          yKey="users"
          color="#3b82f6"
        />
        <LineChart
          title="Events per Day"
          data={trendData}
          xKey="date"
          yKey="events"
          color="#8b5cf6"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <BarChart
          title="Top Event Types"
          data={topEvents}
          xKey="name"
          yKey="count"
          color="#6366f1"
        />
        <LineChart
          title="Revenue per Day"
          data={trendData}
          xKey="date"
          yKey="revenue"
          color="#22c55e"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <PieChart title="Device Models" data={deviceData} />
        <BarChart
          title="Top Countries"
          data={countryData}
          xKey="name"
          yKey="count"
          color="#f59e0b"
        />
      </div>
    </div>
  );
}
