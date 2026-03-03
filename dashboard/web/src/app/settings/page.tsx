"use client";

import { API_KEY } from "@/lib/firebase";

export default function SettingsPage() {
  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Settings</h1>

      <div className="max-w-2xl space-y-6">
        {/* API Key */}
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h2 className="text-sm font-semibold text-gray-700 mb-3">API Key</h2>
          <div className="flex items-center gap-3">
            <code className="flex-1 px-3 py-2 bg-gray-50 rounded-lg text-sm font-mono text-gray-700 border border-gray-200">
              {API_KEY}
            </code>
            <button
              onClick={() => navigator.clipboard.writeText(API_KEY)}
              className="px-3 py-2 text-sm font-medium text-primary-600 bg-primary-50 rounded-lg hover:bg-primary-100 transition-colors"
            >
              Copy
            </button>
          </div>
        </div>

        {/* SDK Integration */}
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h2 className="text-sm font-semibold text-gray-700 mb-3">
            SDK Integration
          </h2>
          <p className="text-sm text-gray-500 mb-3">
            Point your SwiftAnalytics SDK to your Cloud Function URL:
          </p>
          <pre className="bg-gray-50 rounded-lg p-4 text-xs text-gray-700 overflow-x-auto">
{`let config = SAConfiguration(
    apiKey: "${API_KEY}",
    serverURL: "https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net"
)
SwiftAnalytics.initialize(configuration: config)`}
          </pre>
        </div>

        {/* Environment Variables */}
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h2 className="text-sm font-semibold text-gray-700 mb-3">
            Required Environment Variables
          </h2>
          <p className="text-sm text-gray-500 mb-3">
            Create a <code className="text-xs bg-gray-100 px-1 py-0.5 rounded">.env.local</code> file
            in the <code className="text-xs bg-gray-100 px-1 py-0.5 rounded">dashboard/web/</code> directory:
          </p>
          <pre className="bg-gray-50 rounded-lg p-4 text-xs text-gray-700 overflow-x-auto">
{`NEXT_PUBLIC_FIREBASE_API_KEY=your-firebase-api-key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your-project-id
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=your-project.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789
NEXT_PUBLIC_FIREBASE_APP_ID=1:123:web:abc
NEXT_PUBLIC_SA_API_KEY=${API_KEY}`}
          </pre>
        </div>
      </div>
    </div>
  );
}
