import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { AuthProvider } from "@/lib/auth/AuthContext";
import AuthGuard from "@/components/auth/AuthGuard";
import { AppProvider } from "@/lib/app/AppContext";
import AppShell from "@/components/layout/AppShell";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "SwiftAnalytics Dashboard",
  description: "Self-hosted analytics dashboard",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <AuthProvider>
          <AuthGuard>
            <AppProvider>
              <AppShell>{children}</AppShell>
            </AppProvider>
          </AuthGuard>
        </AuthProvider>
      </body>
    </html>
  );
}
