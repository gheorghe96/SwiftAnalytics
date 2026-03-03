"use client";

import { useAuth } from "@/lib/auth/AuthContext";
import { useRouter, usePathname } from "next/navigation";
import { useEffect } from "react";

const PUBLIC_PATHS = ["/login", "/register"];

export default function AuthGuard({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (!loading && !user && !PUBLIC_PATHS.includes(pathname || "")) {
      router.replace("/login");
    }
  }, [user, loading, pathname, router]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen text-gray-400">
        Loading...
      </div>
    );
  }

  if (!user && !PUBLIC_PATHS.includes(pathname || "")) {
    return null;
  }

  return <>{children}</>;
}
