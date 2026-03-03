"use client";

import { useState } from "react";
import { useApp } from "@/lib/app/AppContext";
import { useAuth } from "@/lib/auth/AuthContext";
import { Trash2, Copy, Check, Plus } from "lucide-react";

export default function SettingsPage() {
  const { user } = useAuth();
  const { apps, currentApp, createApp, deleteApp, setCurrentApp } = useApp();
  const [newAppName, setNewAppName] = useState("");
  const [creating, setCreating] = useState(false);
  const [deleting, setDeleting] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const apiKey = currentApp?.api_key || "";

  async function handleCreateApp(e: React.FormEvent) {
    e.preventDefault();
    if (!newAppName.trim()) return;
    setCreating(true);
    try {
      await createApp(newAppName.trim());
      setNewAppName("");
    } catch (err) {
      console.error("Failed to create app:", err);
    } finally {
      setCreating(false);
    }
  }

  async function handleDeleteApp(key: string) {
    if (!confirm("Are you sure you want to delete this app? All data will be lost.")) return;
    setDeleting(key);
    try {
      await deleteApp(key);
    } catch (err) {
      console.error("Failed to delete app:", err);
    } finally {
      setDeleting(null);
    }
  }

  function handleCopy() {
    navigator.clipboard.writeText(apiKey);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Settings</h1>

      <div className="max-w-2xl space-y-6">
        {/* Current App API Key */}
        {currentApp && (
          <div className="bg-white rounded-xl border border-gray-200 p-6">
            <h2 className="text-sm font-semibold text-gray-700 mb-1">
              API Token — {currentApp.name}
            </h2>
            <p className="text-xs text-gray-400 mb-3">
              Use this token in your iOS app to send events to this project.
            </p>
            <div className="flex items-center gap-3">
              <code className="flex-1 px-3 py-2 bg-gray-50 rounded-lg text-sm font-mono text-gray-700 border border-gray-200 truncate">
                {apiKey}
              </code>
              <button
                onClick={handleCopy}
                className="flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-primary-600 bg-primary-50 rounded-lg hover:bg-primary-100 transition-colors"
              >
                {copied ? <Check size={14} /> : <Copy size={14} />}
                {copied ? "Copied" : "Copy"}
              </button>
            </div>
          </div>
        )}

        {/* SDK Integration */}
        {currentApp && (
          <div className="bg-white rounded-xl border border-gray-200 p-6">
            <h2 className="text-sm font-semibold text-gray-700 mb-3">
              SDK Integration
            </h2>
            <p className="text-sm text-gray-500 mb-3">
              Add this to your iOS app to start tracking events:
            </p>
            <pre className="bg-gray-50 rounded-lg p-4 text-xs text-gray-700 overflow-x-auto">
{`let config = SAConfiguration(
    apiKey: "${apiKey}",
    serverURL: "https://us-central1-app-user-tracking.cloudfunctions.net/ingest"
)
let analytics = SwiftAnalytics(configuration: config)`}
            </pre>
          </div>
        )}

        {/* My Apps */}
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h2 className="text-sm font-semibold text-gray-700 mb-3">My Apps</h2>

          <div className="space-y-2 mb-4">
            {apps.map((app) => (
              <div
                key={app.api_key}
                className={`flex items-center justify-between px-4 py-3 rounded-lg border transition-colors cursor-pointer ${
                  app.api_key === currentApp?.api_key
                    ? "border-primary-200 bg-primary-50"
                    : "border-gray-200 hover:bg-gray-50"
                }`}
                onClick={() => setCurrentApp(app)}
              >
                <div className="min-w-0">
                  <p className="text-sm font-medium text-gray-900">{app.name}</p>
                  <p className="text-xs font-mono text-gray-400 truncate">
                    {app.api_key}
                  </p>
                </div>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    handleDeleteApp(app.api_key);
                  }}
                  disabled={deleting === app.api_key}
                  className="p-1.5 text-gray-400 hover:text-red-500 transition-colors disabled:opacity-50"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            ))}

            {apps.length === 0 && (
              <p className="text-sm text-gray-400 py-2">No apps yet. Create one below.</p>
            )}
          </div>

          <form onSubmit={handleCreateApp} className="flex gap-2">
            <input
              type="text"
              value={newAppName}
              onChange={(e) => setNewAppName(e.target.value)}
              placeholder="New app name"
              className="flex-1 px-3 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
            />
            <button
              type="submit"
              disabled={creating || !newAppName.trim()}
              className="flex items-center gap-1.5 px-4 py-2 bg-primary-600 text-white rounded-lg text-sm font-medium hover:bg-primary-700 disabled:opacity-50"
            >
              <Plus size={14} />
              {creating ? "Creating..." : "Create App"}
            </button>
          </form>
        </div>

        {/* Account */}
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h2 className="text-sm font-semibold text-gray-700 mb-3">Account</h2>
          <p className="text-sm text-gray-600">{user?.email}</p>
        </div>
      </div>
    </div>
  );
}
