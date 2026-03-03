import { useApp } from "@/lib/app/AppContext";

export function useCurrentApiKey(): string | null {
  const { currentApp } = useApp();
  return currentApp?.api_key ?? null;
}
