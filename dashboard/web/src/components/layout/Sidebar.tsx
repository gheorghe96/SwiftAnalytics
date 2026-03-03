"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { clsx } from "clsx";
import { useState } from "react";
import { signOut } from "firebase/auth";
import { getAuthInstance } from "@/lib/firebase";
import { useAuth } from "@/lib/auth/AuthContext";
import { useApp, AppInfo } from "@/lib/app/AppContext";
import {
  LayoutDashboard,
  Zap,
  Users,
  Clock,
  DollarSign,
  Radio,
  Settings,
  ChevronDown,
  Plus,
  LogOut,
  Check,
} from "lucide-react";

const navItems = [
  { href: "/overview", label: "Overview", icon: LayoutDashboard },
  { href: "/events", label: "Events", icon: Zap },
  { href: "/users", label: "Users", icon: Users },
  { href: "/sessions", label: "Sessions", icon: Clock },
  { href: "/revenue", label: "Revenue", icon: DollarSign },
  { href: "/realtime", label: "Realtime", icon: Radio },
  { href: "/settings", label: "Settings", icon: Settings },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { user } = useAuth();
  const { apps, currentApp, setCurrentApp, createApp } = useApp();
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [newAppName, setNewAppName] = useState("");

  async function handleCreateApp(e: React.FormEvent) {
    e.preventDefault();
    if (!newAppName.trim()) return;
    setCreating(true);
    try {
      await createApp(newAppName.trim());
      setNewAppName("");
      setDropdownOpen(false);
    } catch {
      // Error handling could be improved
    } finally {
      setCreating(false);
    }
  }

  function handleSwitchApp(app: AppInfo) {
    setCurrentApp(app);
    setDropdownOpen(false);
  }

  return (
    <aside className="fixed left-0 top-0 h-screen w-60 bg-white border-r border-gray-200 flex flex-col z-40">
      {/* App Switcher */}
      <div className="px-3 pt-4 pb-3 border-b border-gray-100 relative">
        <button
          onClick={() => setDropdownOpen(!dropdownOpen)}
          className="w-full flex items-center justify-between px-3 py-2.5 rounded-lg bg-gray-50 hover:bg-gray-100 transition-colors"
        >
          <div className="text-left min-w-0">
            <p className="text-xs text-gray-400 font-medium">App</p>
            <p className="text-sm font-semibold text-gray-900 truncate">
              {currentApp?.name || "No app selected"}
            </p>
          </div>
          <ChevronDown
            size={16}
            className={clsx(
              "text-gray-400 transition-transform flex-shrink-0",
              dropdownOpen && "rotate-180"
            )}
          />
        </button>

        {/* Dropdown */}
        {dropdownOpen && (
          <>
            <div
              className="fixed inset-0 z-40"
              onClick={() => setDropdownOpen(false)}
            />
            <div className="absolute left-3 right-3 top-full mt-1 bg-white border border-gray-200 rounded-lg shadow-lg z-50 overflow-hidden">
              <div className="max-h-48 overflow-y-auto py-1">
                {apps.map((app) => (
                  <button
                    key={app.api_key}
                    onClick={() => handleSwitchApp(app)}
                    className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 text-left"
                  >
                    {app.api_key === currentApp?.api_key ? (
                      <Check size={14} className="text-primary-600 flex-shrink-0" />
                    ) : (
                      <span className="w-3.5" />
                    )}
                    <span className="truncate">{app.name}</span>
                  </button>
                ))}
              </div>

              <div className="border-t border-gray-100 p-2">
                <form onSubmit={handleCreateApp} className="flex gap-1">
                  <input
                    type="text"
                    value={newAppName}
                    onChange={(e) => setNewAppName(e.target.value)}
                    placeholder="New app name"
                    className="flex-1 min-w-0 px-2 py-1.5 text-xs border border-gray-200 rounded-md focus:outline-none focus:ring-1 focus:ring-primary-500"
                  />
                  <button
                    type="submit"
                    disabled={creating || !newAppName.trim()}
                    className="p-1.5 bg-primary-600 text-white rounded-md hover:bg-primary-700 disabled:opacity-50"
                  >
                    <Plus size={14} />
                  </button>
                </form>
              </div>
            </div>
          </>
        )}
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-3 py-4 space-y-1">
        {navItems.map((item) => {
          const isActive =
            pathname === item.href || pathname?.startsWith(item.href + "/");
          const Icon = item.icon;

          return (
            <Link
              key={item.href}
              href={item.href}
              className={clsx(
                "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors",
                isActive
                  ? "bg-primary-50 text-primary-700"
                  : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
              )}
            >
              <Icon size={18} />
              {item.label}
            </Link>
          );
        })}
      </nav>

      {/* Footer — User + Sign Out */}
      <div className="px-4 py-3 border-t border-gray-100">
        <p className="text-xs text-gray-500 truncate mb-1">{user?.email}</p>
        <button
          onClick={() => signOut(getAuthInstance())}
          className="flex items-center gap-1.5 text-xs text-gray-400 hover:text-red-500 transition-colors"
        >
          <LogOut size={12} />
          Sign out
        </button>
      </div>
    </aside>
  );
}
