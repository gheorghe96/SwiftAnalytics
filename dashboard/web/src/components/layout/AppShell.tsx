"use client";

import { usePathname } from "next/navigation";
import Sidebar from "./Sidebar";

const AUTH_PAGES = ["/login", "/register"];

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const isAuthPage = AUTH_PAGES.includes(pathname || "");

  if (isAuthPage) {
    return <main className="min-h-screen">{children}</main>;
  }

  return (
    <>
      <Sidebar />
      <main className="ml-60 min-h-screen p-8">{children}</main>
    </>
  );
}
