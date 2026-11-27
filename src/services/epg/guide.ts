/**
 * EPG por canal (Xtream get_short_epg). Cache en memoria + cola de 3 peticiones
 * simultaneas para no saturar al proveedor ni gastar conexiones de la cuenta.
 * Los canales sin guia devuelven [] y se cachean mas tiempo (cache negativa).
 */
import { db } from "../../db";
import { proxify } from "../proxy";
import type { Channel } from "../../types";

export interface Programme {
  title: string;
  desc: string;
  start: number; // ms
  end: number;   // ms
}

const TTL_OK = 5 * 60 * 1000;
const TTL_EMPTY = 20 * 60 * 1000;
const cache = new Map<string, { at: number; items: Programme[] }>();
const inflight = new Map<string, Promise<Programme[]>>();

const inTauri =
  typeof window !== "undefined" && "__TAURI_INTERNALS__" in (window as any);

async function httpGet(url: string): Promise<Response> {
  if (inTauri) {
    const mod: any = await import(/* @vite-ignore */ "@tauri-apps/plugin-http");
    return mod.fetch(url, {
      headers: { "User-Agent": "VLC/3.0.20 LibVLC/3.0.20", Accept: "*/*" },
    });
  }
  return fetch(await proxify(url, "playlist"));
}

// Cola de concurrencia limitada
let running = 0;
const waiting: Array<() => void> = [];
function slot<T>(job: () => Promise<T>): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const run = () => {
      running++;
      job()
        .then(resolve, reject)
        .finally(() => {
          running--;
          const next = waiting.shift();
          if (next) next();
        });
    };
    if (running < 3) run();
    else waiting.push(run);
  });
}

function decodeB64(s: string): string {
  if (!s) return "";
  try {
    const bin = atob(s);
    const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
    return new TextDecoder("utf-8").decode(bytes).trim();
  } catch {
    return s;
  }
}

function toMs(v: unknown): number {
  const n = Number(v);
  if (!isFinite(n) || n <= 0) return 0;
  return n < 1e12 ? n * 1000 : n;
}

export function hasEpgSource(ch: Channel): boolean {
  return !!ch.streamId;
}

export async function getProgrammes(ch: Channel, limit = 10): Promise<Programme[]> {
  const hit = cache.get(ch.id);
  if (hit) {
    const ttl = hit.items.length ? TTL_OK : TTL_EMPTY;
    if (Date.now() - hit.at < ttl) return hit.items;
  }
  const busy = inflight.get(ch.id);
  if (busy) return busy;

  const task = slot(async () => {
    try {
      const pl = await db.playlists.get(ch.playlistId);
      if (!pl || pl.type !== "xtream" || !ch.streamId) {
        cache.set(ch.id, { at: Date.now(), items: [] });
        return [] as Programme[];
      }
      const base = String(pl.server || "").replace(/\/+$/, "");
      const url =
        `${base}/player_api.php?username=${encodeURIComponent(pl.username || "")}` +
        `&password=${encodeURIComponent(pl.password || "")}` +
        `&action=get_short_epg&stream_id=${encodeURIComponent(ch.streamId)}&limit=${limit}`;

      const res = await httpGet(url);
      if (!res.ok) throw new Error(String(res.status));
      const data: any = await res.json();
      const rows: any[] = Array.isArray(data?.epg_listings) ? data.epg_listings : [];

      const items: Programme[] = rows
        .map((r) => {
          const start = toMs(r.start_timestamp);
          const end = toMs(r.stop_timestamp ?? r.end_timestamp);
          return {
            title: decodeB64(r.title) || "Sin titulo",
            desc: decodeB64(r.description),
            start,
            end: end > start ? end : start + 30 * 60 * 1000,
          };
        })
        .filter((p) => p.start > 0)
        .sort((a, b) => a.start - b.start);

      cache.set(ch.id, { at: Date.now(), items });
      return items;
    } catch {
      cache.set(ch.id, { at: Date.now(), items: [] });
      return [] as Programme[];
    } finally {
      inflight.delete(ch.id);
    }
  });

  inflight.set(ch.id, task);
  return task;
}

export function nowNext(items: Programme[], at = Date.now()) {
  let now: Programme | null = null;
  let next: Programme | null = null;
  for (const p of items) {
    if (p.start <= at && p.end > at) now = p;
    else if (p.start > at && !next) next = p;
  }
  return { now, next };
}

export function hhmm(ms: number): string {
  const d = new Date(ms);
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}
