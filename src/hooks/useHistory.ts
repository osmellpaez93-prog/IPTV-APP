import { useCallback } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { db } from "../db";
import type { Channel, WatchHistory } from "../types";

export interface ResumeItem {
  history: WatchHistory;
  channel: Channel;
  percent: number;
}

/** "Continuar viendo": empezados y no terminados, mas recientes primero.
 *  Usa la copia guardada en el historial (sirve tambien para episodios de series,
 *  que no existen en la tabla de canales). */
export function useContinueWatching(limit = 14): ResumeItem[] {
  const rows = useLiveQuery(async () => {
    const hist = await db.history.orderBy("updatedAt").reverse().limit(limit * 3).toArray();
    const usable = hist.filter((h) => h.duration > 0 && h.position > 30 && h.position / h.duration < 0.97);
    const missing = usable.filter((h) => !h.item);
    const found = missing.length ? await db.channels.bulkGet(missing.map((h) => h.id)) : [];
    const byId = new Map<string, Channel | undefined>(missing.map((h, i) => [h.id, found[i]]));
    const out: ResumeItem[] = [];
    for (const h of usable) {
      const ch = h.item ?? byId.get(h.id);
      if (ch) out.push({ history: h, channel: ch, percent: Math.min(99, (h.position / h.duration) * 100) });
    }
    return out.slice(0, limit);
  }, [limit]);
  return rows ?? [];
}

export function useRemoveResume() {
  return useCallback((id: string) => { void db.history.delete(id).catch(() => {}); }, []);
}

