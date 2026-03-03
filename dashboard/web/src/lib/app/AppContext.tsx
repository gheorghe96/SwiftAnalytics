"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  ReactNode,
} from "react";
import { doc, onSnapshot } from "firebase/firestore";
import { getDb } from "@/lib/firebase";
import { getFunctions, httpsCallable } from "firebase/functions";
import { useAuth } from "@/lib/auth/AuthContext";

export interface AppInfo {
  api_key: string;
  name: string;
}

interface AppContextType {
  apps: AppInfo[];
  currentApp: AppInfo | null;
  setCurrentApp: (app: AppInfo) => void;
  createApp: (name: string) => Promise<AppInfo>;
  deleteApp: (apiKey: string) => Promise<void>;
  loading: boolean;
}

const AppContext = createContext<AppContextType>({
  apps: [],
  currentApp: null,
  setCurrentApp: () => {},
  createApp: async () => ({ api_key: "", name: "" }),
  deleteApp: async () => {},
  loading: true,
});

const STORAGE_KEY = "sa_current_app";

export function AppProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [apps, setApps] = useState<AppInfo[]>([]);
  const [currentApp, setCurrentAppState] = useState<AppInfo | null>(null);
  const [loading, setLoading] = useState(true);

  // Listen to user's app list in real-time
  useEffect(() => {
    if (!user) {
      setApps([]);
      setCurrentAppState(null);
      setLoading(false);
      return;
    }

    const unsub = onSnapshot(
      doc(getDb(), "users", user.uid),
      (snap) => {
        const data = snap.data();
        const appList: AppInfo[] = (data?.apps || []).map(
          (a: Record<string, unknown>) => ({
            api_key: a.api_key as string,
            name: a.name as string,
          })
        );
        setApps(appList);

        // Restore last selected app from localStorage, or pick first
        const stored =
          typeof window !== "undefined"
            ? localStorage.getItem(STORAGE_KEY)
            : null;
        const match = appList.find((a) => a.api_key === stored);
        setCurrentAppState(match || appList[0] || null);
        setLoading(false);
      },
      () => {
        // Doc doesn't exist yet (new user) — that's fine
        setApps([]);
        setCurrentAppState(null);
        setLoading(false);
      }
    );

    return () => unsub();
  }, [user]);

  const setCurrentApp = useCallback((app: AppInfo) => {
    setCurrentAppState(app);
    localStorage.setItem(STORAGE_KEY, app.api_key);
  }, []);

  const createAppFn = useCallback(
    async (name: string): Promise<AppInfo> => {
      const functions = getFunctions();
      const callable = httpsCallable(functions, "createApp");
      const result = await callable({ name });
      const newApp = result.data as AppInfo;
      setCurrentApp(newApp);
      return newApp;
    },
    [setCurrentApp]
  );

  const deleteAppFn = useCallback(
    async (apiKey: string): Promise<void> => {
      const functions = getFunctions();
      const callable = httpsCallable(functions, "deleteApp");
      await callable({ api_key: apiKey });

      // If we deleted the current app, switch to next available
      if (currentApp?.api_key === apiKey) {
        const remaining = apps.filter((a) => a.api_key !== apiKey);
        setCurrentAppState(remaining[0] || null);
        if (remaining[0]) {
          localStorage.setItem(STORAGE_KEY, remaining[0].api_key);
        } else {
          localStorage.removeItem(STORAGE_KEY);
        }
      }
    },
    [currentApp, apps]
  );

  return (
    <AppContext.Provider
      value={{
        apps,
        currentApp,
        setCurrentApp,
        createApp: createAppFn,
        deleteApp: deleteAppFn,
        loading,
      }}
    >
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  return useContext(AppContext);
}
