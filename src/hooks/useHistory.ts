import { useCallback } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { db } from "../db";
import type { Channel, WatchHistory } from "../types";

export interface ResumeItem {
  history: WatchHistory;
  channel: Channel;
  percent: number;
}

/** "Continuar viendo": empezados y no terminados, mas recientes primero. */
export function useContinueWatching(limit = 14): ResumeItem[] {
  const rows = useLiveQuery(async () => {
    const hist = await db.history.orderBy("updatedAt").reverse().limit(limit * 3).toArray();
    const usable = hist.filter((h) => h.duration > 0 && h.position > 30 && h.position / h.duration < 0.97);
    if (usable.length === 0) return [] as ResumeItem[];
    const found = await db.channels.bulkGet(usable.map((h) => h.id));
    const out: ResumeItem[] = [];
    usable.forEach((h, i) => {
      const ch = found[i];
      if (!ch) return;
      out.push({ history: h, channel: ch, percent: Math.min(99, (h.position / h.duration) * 100) });
    });
    return out.slice(0, limit);
  }, [limit]);
  return rows ?? [];
}

export function useRemoveResume() {
  return useCallback((id: string) => { void db.history.delete(id).catch(() => {}); }, []);
}
