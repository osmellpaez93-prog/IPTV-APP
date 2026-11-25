/**
 * Guia de programacion (EPG) via Xtream: action=get_short_epg.
 * Funciona con cuentas Xtream y tambien con listas M3U de paneles Xtream
 * (las credenciales y el id del canal se leen de la URL del stream).
 * Cache en memoria + limite de 3 peticiones simultaneas.
 */
import type { Channel } from "../../types";
import { proxify } from "../proxy";

export interface EpgItem {
  title: string;
  description: string;
  start: number; // ms
  end: number;   // ms
}

export interface EpgSource {
  server: string;
  username: string;
  password: string;
  streamId: string;
}

const LIMIT = 6;
const TTL_OK = 5 * 60 * 1000;
const TTL_FAIL = 3 * 60 * 1000;

export function epgSource(ch: Channel): EpgSource | null {
  if (ch.category !== "live" || !ch.url) return null;
  const m = ch.url.match(/^(https?:\/\/[^/]+)\/(?:live\/)?([^/]+)\/([^/]+)\/(\d+)(?:\.[a-z0-9]+)?(?:\?.*)?$/i);
  if (!m) return null;
  const dec = (s: string) => {
    try { return decodeURIComponent(s); } catch { return s; }
  };
  return { server: m[1], username: dec(m[2]), password: dec(m[3]), streamId: ch.streamId || m[4] };
}

function decodeText(s: unknown): string {
  if (typeof s !== "string" || !s) return "";
  if (s.length % 4 === 0 && /^[A-Za-z0-9+/=]+$/.test(s)) {
    try {
      const bin = atob(s);
      const bytes = Uint8Array.from(bin, (c) => c.charCodeAt(0));
      const out = new TextDecoder("utf-8").decode(bytes);
      if (!out.includes("\uFFFD")) return out.trim();
    } catch {}
  }
  return s.trim();
}

function toMs(ts: unknown, text: unknown): number {
  const n = Number(ts);
  if (n > 1e9) return n * 1000;
  if (typeof text === "string" && text) {
    const t = new Date(text.replace(" ", "T")).getTime();
    if (!isNaN(t)) return t;
  }
  return NaN;
}

// ---- limitador de concurrencia
let active = 0;
const waiting: Array<() => void> = [];
async function limited<T>(fn: () => Promise<T>): Promise<T> {
  if (active >= 3) await new Promise<void>((r) => waiting.push(r));
  active++;
  try {
    return await fn();
  } finally {
    active--;
    waiting.shift()?.();
  }
}

const cache = new Map<string, { at: number; items: EpgItem[]; ok: boolean }>();
const inflight = new Map<string, Promise<EpgItem[]>>();

export async function fetchEpg(src: EpgSource): Promise<EpgItem[]> {
  const key = `${src.server}|${src.username}|${src.streamId}`;
  const hit = cache.get(key);
  const now = Date.now();
  if (hit) {
    const fresh = hit.ok
      ? now - hit.at < TTL_OK && (hit.items.length === 0 || hit.items.some((i) => i.end > now))
      : now - hit.at < TTL_FAIL;
    if (fresh) return hit.items;
  }
  const running = inflight.get(key);
  if (running) return running;

  const p = limited(async () => {
    try {
      const url =
        `${src.server}/player_api.php?username=${encodeURIComponent(src.username)}` +
        `&password=${encodeURIComponent(src.password)}&action=get_short_epg` +
        `&stream_id=${encodeURIComponent(src.streamId)}&limit=${LIMIT}`;
      const res = await fetch(await proxify(url, "playlist"));
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: any = JSON.parse(await res.text());
      const list: any[] = Array.isArray(data?.epg_listings) ? data.epg_listings : [];
      const items = list
        .map((e) => ({
          title: decodeText(e.title),
          description: decodeText(e.description),
          start: toMs(e.start_timestamp, e.start),
          end: toMs(e.stop_timestamp, e.end),
        }))
        .filter((e) => e.title && isFinite(e.start) && isFinite(e.end) && e.end > e.start)
        .sort((a, b) => a.start - b.start);
      cache.set(key, { at: Date.now(), items, ok: true });
      return items;
    } catch {
      cache.set(key, { at: Date.now(), items: [], ok: false });
      return [] as EpgItem[];
    }
  }).finally(() => inflight.delete(key));

  inflight.set(key, p);
  return p;
}
