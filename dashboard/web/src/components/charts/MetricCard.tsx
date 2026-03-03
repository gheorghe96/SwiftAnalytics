"use client";

import { clsx } from "clsx";
import { LucideIcon } from "lucide-react";

interface MetricCardProps {
  title: string;
  value: string;
  change?: string;
  changeType?: "positive" | "negative" | "neutral";
  icon: LucideIcon;
  iconColor?: string;
}

export default function MetricCard({
  title,
  value,
  change,
  changeType = "neutral",
  icon: Icon,
  iconColor = "text-primary-600",
}: MetricCardProps) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-500 font-medium">{title}</p>
          <p className="text-2xl font-bold mt-1">{value}</p>
          {change && (
            <p
              className={clsx("text-xs mt-1 font-medium", {
                "text-green-600": changeType === "positive",
                "text-red-600": changeType === "negative",
                "text-gray-500": changeType === "neutral",
              })}
            >
              {change}
            </p>
          )}
        </div>
        <div
          className={clsx(
            "w-12 h-12 rounded-xl flex items-center justify-center bg-opacity-10",
            iconColor.replace("text-", "bg-")
          )}
        >
          <Icon size={24} className={iconColor} />
        </div>
      </div>
    </div>
  );
}
