"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createUserWithEmailAndPassword } from "firebase/auth";
import { getAuthInstance } from "@/lib/firebase";
import { getFunctions, httpsCallable } from "firebase/functions";
import Link from "next/link";

export default function RegisterPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [appName, setAppName] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      // Create the Firebase Auth account
      await createUserWithEmailAndPassword(getAuthInstance(), email, password);

      // Create the first app via Cloud Function
      const functions = getFunctions();
      const createAppFn = httpsCallable(functions, "createApp");
      await createAppFn({ name: appName.trim() || "My App" });

      // Try to claim any existing legacy project (pre-auth migration)
      try {
        const claimFn = httpsCallable(functions, "claimProject");
        await claimFn({ api_key: "sa_prod_key_001" });
      } catch {
        // Ignore — project may not exist or is already owned
      }

      router.replace("/overview");
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Registration failed";
      if (message.includes("email-already-in-use")) {
        setError("An account with this email already exists");
      } else if (message.includes("weak-password")) {
        setError("Password should be at least 6 characters");
      } else {
        setError(message);
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold text-gray-900">SwiftAnalytics</h1>
          <p className="text-sm text-gray-500 mt-1">Create your account</p>
        </div>

        <form onSubmit={handleSubmit} className="bg-white rounded-xl border border-gray-200 p-6 space-y-4">
          {error && (
            <div className="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2">
              {error}
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="you@example.com"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
            <input
              type="password"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="At least 6 characters"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">First App Name</label>
            <input
              type="text"
              required
              value={appName}
              onChange={(e) => setAppName(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="e.g. My iOS App"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-2 px-4 bg-primary-600 text-white rounded-lg text-sm font-medium hover:bg-primary-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? "Creating account..." : "Create Account"}
          </button>

          <p className="text-center text-sm text-gray-500">
            Already have an account?{" "}
            <Link href="/login" className="text-primary-600 hover:underline font-medium">
              Sign In
            </Link>
          </p>
        </form>
      </div>
    </div>
  );
}
