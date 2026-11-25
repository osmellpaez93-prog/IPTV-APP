import { useEffect, useState } from "react";
import type { Channel } from "../types";
import { epgSource, fetchEpg, type EpgItem } from "../services/epg/xtreamEpg";

/** Programa actual y siguientes de un canal en vivo. `delay` evita pedir la guia mientras se hace scroll rapido. */
export function useEpg(channel: Channel | null, delay = 0) {
  const [items, setItems] = useState<EpgItem[] | null>(null);
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 30000);
    return () => window.clearInterval(id);
  }, []);

  const key = channel && channel.category === "live" ? channel.id : "";
  const slot = Math.floor(now / 300000); // refresco cada 5 min

  useEffect(() => { setItems(null); }, [key]);

  useEffect(() => {
    if (!channel || channel.category !== "live") return;
    const src = epgSource(channel);
    if (!src) { setItems([]); return; }
    let alive = true;
    const t = window.setTimeout(() => {
      fetchEpg(src).then((r) => { if (alive) setItems(r); }).catch(() => { if (alive) setItems([]); });
    }, delay);
    return () => { alive = false; window.clearTimeout(t); };
  }, [key, slot]);

  const current = items?.find((i) => i.start <= now && now < i.end) ?? null;
  const upcoming = (items ?? []).filter((i) => i.start >= (current ? current.end : now));
  return { items, current, next: upcoming[0] ?? null, upcoming, now, loading: key !== "" && items === null };
}
