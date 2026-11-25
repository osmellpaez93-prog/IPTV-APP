import { useCallback, useMemo } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { db } from "../db";

export function useFavorites() {
  const favs = useLiveQuery(() => db.favorites.toArray(), []);
  const favSet = useMemo(() => new Set((favs ?? []).map((f) => f.id)), [favs]);

  const toggle = useCallback(async (id: string) => {
    const exists = await db.favorites.get(id);
    if (exists) await db.favorites.delete(id);
    else await db.favorites.put({ id, addedAt: Date.now() });
  }, []);

  return { favSet, toggle };
}
