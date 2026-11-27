<#
  StreamBox - UI Zonix + Netflix
  ---------------------------------------------------------------------------
  TV en vivo  -> guia con columna de categorias (contadores) + rejilla EPG
                 con linea de tiempo, marca de "ahora" y bloques por programa.
  Pelis/Series -> portada hero + carruseles de posters estilo Netflix/Prime,
                 fila "Continuar viendo" con progreso.

  Solo CREA archivos nuevos + reescribe 3 envoltorios de 4 lineas
  (LiveTV/Movies/Series). No toca Layout, store, db, usePlayer, proxy ni server.
  Dentro de cada vista hay un boton para volver a la lista clasica.

  Guarda este archivo como UTF-8 y ejecuta en la raiz del repo:
    powershell -ExecutionPolicy Bypass -File .\ui-zonix-netflix.ps1
#>
param([switch]$Force)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "package.json"))) {
  Write-Host "ERROR: ejecuta en la raiz del repo." -ForegroundColor Red; return
}
Write-Host ""
Write-Host "StreamBox UI -> $root" -ForegroundColor Cyan
if (-not $Force) {
  $r = Read-Host "Continuar? (S/N)"
  if ($r -notmatch '^[sSyY]') { Write-Host "Cancelado."; return }
}

function Save-File {
  param([string]$RelPath, [string]$Content, [switch]$OnlyIfMissing)
  $full = Join-Path $root $RelPath
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if ((Test-Path $full) -and $OnlyIfMissing) { Write-Host "  = $RelPath (existe)" -ForegroundColor Gray; return }
  if (-not $Content.EndsWith("`n")) { $Content += "`n" }
  if (Test-Path $full) {
    $old = [System.IO.File]::ReadAllText($full)
    if ($old -eq $Content) { Write-Host "  = $RelPath (sin cambios)" -ForegroundColor Gray; return }
    Copy-Item $full "$full.bak" -Force
  }
  [System.IO.File]::WriteAllText($full, $Content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  + $RelPath" -ForegroundColor Green
}

# ===================================================== declaracion plugin http
Save-File 'src/types/tauri-http.d.ts' @'
declare module "@tauri-apps/plugin-http" {
  export function fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>;
}
'@ -OnlyIfMissing

# ============================================================ tokens visuales
Save-File 'src/styles/streambox-ui.css' @'
/* Tokens propios de las vistas Guia y Portadas. Prefijo sb- para no chocar. */
.sb-scope {
  --sb-bg: #070a12;
  --sb-panel: #0d1320;
  --sb-raise: #141d2e;
  --sb-line: #22304a;
  --sb-ink: #eef3fb;
  --sb-mute: #93a3bd;
  --sb-dim: #5d6d88;
  --sb-blue: #4c8dff;
  --sb-cyan: #38bdf8;
  --sb-live: #ff2d55;
  --sb-gold: #ffb020;
  --sb-iris: #8b5cf6;
  color: var(--sb-ink);
}

.sb-scroll { scrollbar-width: thin; scrollbar-color: #2b3a55 #0a0f1a; }
.sb-scroll::-webkit-scrollbar { width: 12px; height: 12px; }
.sb-scroll::-webkit-scrollbar-track { background: #0a0f1a; }
.sb-scroll::-webkit-scrollbar-thumb {
  background: linear-gradient(180deg, #33456a, #22304a);
  border: 3px solid #0a0f1a; border-radius: 999px;
}
.sb-scroll::-webkit-scrollbar-thumb:hover { background: linear-gradient(180deg, #4c8dff, #8b5cf6); }
.sb-scroll::-webkit-scrollbar-corner { background: #0a0f1a; }
.sb-noscroll { scrollbar-width: none; }
.sb-noscroll::-webkit-scrollbar { height: 0; width: 0; }

.sb-grain {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='3'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.5'/%3E%3C/svg%3E");
}

[data-sbfocus="1"] { outline: none; transition: box-shadow .15s ease, transform .15s ease, background-color .15s ease; }
[data-sbfocus="1"]:focus-visible {
  box-shadow: 0 0 0 2px var(--sb-blue), 0 0 22px rgba(76,141,255,.45);
  position: relative; z-index: 5;
}

.sb-row-on {
  box-shadow: inset 0 0 0 2px var(--sb-blue), 0 0 20px rgba(76,141,255,.35);
  background: linear-gradient(90deg, rgba(76,141,255,.16), rgba(76,141,255,.04));
}

.sb-poster { transition: transform .22s cubic-bezier(.2,.8,.2,1), box-shadow .22s ease; }
.sb-poster:hover, .sb-poster:focus-visible {
  transform: translateY(-6px) scale(1.05);
  box-shadow: 0 18px 40px -14px rgba(0,0,0,.95), 0 0 0 2px var(--sb-blue);
  z-index: 20;
}

.sb-fade-l { background: linear-gradient(90deg, #070a12 0%, rgba(7,10,18,0) 100%); }
.sb-fade-r { background: linear-gradient(270deg, #070a12 0%, rgba(7,10,18,0) 100%); }

@keyframes sbIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: none; } }
.sb-in { animation: sbIn .3s cubic-bezier(.2,.8,.2,1) both; }
@keyframes sbPulse { 0%,100% { opacity: 1; } 50% { opacity: .3; } }
.sb-pulse { animation: sbPulse 1.6s ease-in-out infinite; }
@keyframes sbShimmer { 0% { background-position: 220% 0; } 100% { background-position: -220% 0; } }
.sb-skel {
  background: linear-gradient(90deg, #101828 0%, #1b2740 45%, #101828 90%);
  background-size: 220% 100%; animation: sbShimmer 1.5s linear infinite;
}
.sb-tnum { font-variant-numeric: tabular-nums; }
'@

# ============================================================ servicio de EPG
Save-File 'src/services/epg/guide.ts' @'
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
'@

# ======================================================= columna de categorias
Save-File 'src/components/tv/CategoryColumn.tsx' @'
import { useMemo } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Search, Star, History, Tv } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../../db";
import { useFavorites } from "../../hooks/useFavorites";
import type { Channel } from "../../types";

export type CatKey = string; // "__all" | "__fav" | "__recent" | nombre de grupo

interface Props {
  channels: Channel[];
  value: CatKey;
  onChange: (k: CatKey) => void;
  query: string;
  onQuery: (v: string) => void;
}

export function CategoryColumn({ channels, value, onChange, query, onQuery }: Props) {
  const { favSet } = useFavorites();
  const recent = useLiveQuery(async () => {
    const rows = await db.history.orderBy("updatedAt").reverse().limit(60).toArray();
    return new Set(rows.map((r) => r.id));
  }, []);

  const groups = useMemo(() => {
    const m = new Map<string, number>();
    for (const c of channels) {
      const g = c.group || "Sin categoria";
      m.set(g, (m.get(g) ?? 0) + 1);
    }
    return Array.from(m.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [channels]);

  const favCount = useMemo(() => channels.filter((c) => favSet.has(c.id)).length, [channels, favSet]);
  const recentCount = useMemo(
    () => (recent ? channels.filter((c) => recent.has(c.id)).length : 0),
    [channels, recent]
  );

  const Item = ({ k, label, count, icon: Icon }: { k: CatKey; label: string; count: number; icon?: any }) => {
    const on = value === k;
    return (
      <button
        data-sbfocus="1"
        onClick={() => onChange(k)}
        title={label}
        className={clsx(
          "flex w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-[13px]",
          on ? "sb-row-on font-semibold text-white" : "text-[#93a3bd] hover:bg-[#141d2e] hover:text-white"
        )}
      >
        {Icon && <Icon className="h-3.5 w-3.5 shrink-0 opacity-80" />}
        <span className="min-w-0 flex-1 truncate">{label}</span>
        <span className={clsx("sb-tnum shrink-0 text-[11px]", on ? "text-[#4c8dff]" : "text-[#5d6d88]")}>
          {count.toLocaleString()}
        </span>
      </button>
    );
  };

  return (
    <div className="flex h-full min-h-0 w-full flex-col border-r border-[#22304a] bg-[#0d1320]">
      <div className="border-b border-[#22304a] p-3">
        <div className="mb-2 flex items-center gap-2">
          <Tv className="h-4 w-4 text-[#4c8dff]" />
          <h2 className="text-sm font-bold uppercase tracking-[0.18em]">TV</h2>
        </div>
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-[#5d6d88]" />
          <input
            value={query}
            onChange={(e) => onQuery(e.target.value)}
            placeholder="Buscar canal..."
            className="w-full rounded-lg border border-[#22304a] bg-[#070a12] py-1.5 pl-8 pr-2 text-[13px] placeholder:text-[#5d6d88] focus:border-[#4c8dff] focus:outline-none"
          />
        </div>
      </div>

      <div className="sb-scroll min-h-0 flex-1 space-y-0.5 overflow-y-auto p-2">
        <Item k="__fav" label="Favoritos" count={favCount} icon={Star} />
        <Item k="__recent" label="Vistos recientemente" count={recentCount} icon={History} />
        <Item k="__all" label="Todos los canales" count={channels.length} icon={Tv} />
        <div className="my-2 border-t border-[#22304a]" />
        {groups.map(([g, n]) => (
          <Item key={g} k={g} label={g} count={n} />
        ))}
        {groups.length === 0 && <p className="px-2 py-6 text-center text-xs text-[#5d6d88]">Sin categorias.</p>}
      </div>
    </div>
  );
}
'@

# ============================================================ preview superior
Save-File 'src/components/tv/ChannelPreview.tsx' @'
import { useEffect, useState } from "react";
import { Play, Star, CalendarClock } from "lucide-react";
import { clsx } from "clsx";
import { imgUrl } from "../../services/proxy";
import { getProgrammes, nowNext, hhmm, type Programme } from "../../services/epg/guide";
import type { Channel } from "../../types";

interface Props {
  channel: Channel | null;
  isFav: boolean;
  onFav: (id: string) => void;
  onPlay: (c: Channel) => void;
}

export function ChannelPreview({ channel, isFav, onFav, onPlay }: Props) {
  const [items, setItems] = useState<Programme[]>([]);
  const [tick, setTick] = useState(Date.now());
  const [imgBad, setImgBad] = useState(false);

  useEffect(() => {
    setImgBad(false);
    setItems([]);
    if (!channel) return;
    let alive = true;
    getProgrammes(channel, 6).then((r) => { if (alive) setItems(r); });
    return () => { alive = false; };
  }, [channel?.id]);

  useEffect(() => {
    const t = window.setInterval(() => setTick(Date.now()), 30000);
    return () => window.clearInterval(t);
  }, []);

  if (!channel) {
    return (
      <div className="flex h-[132px] items-center justify-center border-b border-[#22304a] bg-[#0d1320] text-sm text-[#5d6d88]">
        Selecciona un canal de la guia
      </div>
    );
  }

  const { now, next } = nowNext(items, tick);
  const pct = now ? Math.min(100, Math.max(0, ((tick - now.start) / (now.end - now.start)) * 100)) : 0;
  const logo = imgUrl(channel.logo);

  return (
    <div className="flex h-[132px] shrink-0 items-stretch gap-4 border-b border-[#22304a] bg-[#0d1320] p-3">
      <button
        data-sbfocus="1"
        onClick={() => onPlay(channel)}
        className="group relative aspect-video h-full shrink-0 overflow-hidden rounded-lg border border-[#22304a] bg-black"
        aria-label={`Reproducir ${channel.name}`}
      >
        {logo && !imgBad ? (
          <img src={logo} alt="" onError={() => setImgBad(true)} className="h-full w-full object-contain p-3 opacity-80" />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-[#141d2e] to-[#070a12] text-xs text-[#5d6d88]">
            {channel.name.slice(0, 22)}
          </div>
        )}
        <span className="absolute inset-0 flex items-center justify-center bg-black/55 opacity-0 transition-opacity group-hover:opacity-100">
          <span className="flex h-11 w-11 items-center justify-center rounded-full bg-[#4c8dff]">
            <Play className="h-5 w-5 text-white" fill="currentColor" />
          </span>
        </span>
      </button>

      <div className="flex min-w-0 flex-1 flex-col justify-center gap-1">
        <div className="flex items-start gap-2">
          <h3 className="min-w-0 flex-1 truncate text-lg font-bold">{channel.name}</h3>
          <button
            onClick={() => onFav(channel.id)}
            className="rounded-lg p-1.5 hover:bg-[#141d2e]"
            aria-label={isFav ? "Quitar de favoritos" : "Anadir a favoritos"}
          >
            <Star className={clsx("h-4 w-4", isFav ? "fill-[#ffb020] text-[#ffb020]" : "text-[#5d6d88]")} />
          </button>
        </div>
        <p className="truncate text-xs text-[#5d6d88]">{channel.group}</p>

        {now ? (
          <div className="mt-1 space-y-1">
            <div className="flex items-baseline gap-2">
              <span className="flex items-center gap-1 rounded bg-[#ff2d55]/15 px-1.5 py-0.5 text-[10px] font-bold uppercase text-[#ff2d55]">
                <span className="sb-pulse h-1.5 w-1.5 rounded-full bg-[#ff2d55]" /> Ahora
              </span>
              <span className="min-w-0 flex-1 truncate text-sm font-semibold">{now.title}</span>
              <span className="sb-tnum shrink-0 text-xs text-[#93a3bd]">{hhmm(now.start)} - {hhmm(now.end)}</span>
            </div>
            <div className="h-1 w-full overflow-hidden rounded-full bg-[#22304a]">
              <div className="h-full rounded-full bg-gradient-to-r from-[#4c8dff] to-[#38bdf8]" style={{ width: `${pct}%` }} />
            </div>
            {next && (
              <p className="truncate text-xs text-[#93a3bd]">
                <span className="text-[#5d6d88]">A continuacion {hhmm(next.start)}:</span> {next.title}
              </p>
            )}
          </div>
        ) : (
          <p className="mt-1 flex items-center gap-1.5 text-xs text-[#5d6d88]">
            <CalendarClock className="h-3.5 w-3.5" /> Sin guia para este canal
          </p>
        )}
      </div>
    </div>
  );
}
'@

# =============================================================== rejilla EPG
Save-File 'src/components/tv/EpgTimeline.tsx' @'
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { Play } from "lucide-react";
import { clsx } from "clsx";
import { imgUrl } from "../../services/proxy";
import { getProgrammes, hhmm, type Programme } from "../../services/epg/guide";
import type { Channel } from "../../types";

const LEFT = 296;
const ROW = 54;
const OVERSCAN = 6;
const NO_INFO = "Sin informacion";

interface Props {
  channels: Channel[];
  selectedId: string | null;
  onSelect: (c: Channel) => void;
  onPlay: (c: Channel) => void;
  pxPerMin: number;
  startMs: number;
  minutes: number;
}

interface Block { left: number; width: number; p: Programme | null }

export function EpgTimeline({ channels, selectedId, onSelect, onPlay, pxPerMin, startMs, minutes }: Props) {
  const scRef = useRef<HTMLDivElement | null>(null);
  const rafRef = useRef<number | null>(null);
  const [range, setRange] = useState({ s: 0, e: 24 });
  const [data, setData] = useState<Record<string, Programme[]>>({});
  const [now, setNow] = useState(Date.now());
  const width = minutes * pxPerMin;

  const recompute = useCallback(() => {
    const el = scRef.current;
    if (!el) return;
    const s = Math.max(0, Math.floor((el.scrollTop - 40) / ROW) - OVERSCAN);
    const e = Math.min(channels.length, Math.ceil((el.scrollTop + el.clientHeight) / ROW) + OVERSCAN);
    setRange((r) => (r.s === s && r.e === e ? r : { s, e }));
  }, [channels.length]);

  useLayoutEffect(() => { recompute(); }, [recompute]);

  useEffect(() => {
    const el = scRef.current;
    if (!el) return;
    const onScroll = () => {
      if (rafRef.current != null) return;
      rafRef.current = window.requestAnimationFrame(() => { rafRef.current = null; recompute(); });
    };
    el.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      el.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      if (rafRef.current != null) window.cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    };
  }, [recompute]);

  useEffect(() => {
    const t = window.setInterval(() => setNow(Date.now()), 30000);
    return () => window.clearInterval(t);
  }, []);

  // Carga EPG solo de las filas visibles (el servicio deduplica y cachea)
  useEffect(() => {
    let alive = true;
    const slice = channels.slice(range.s, range.e);
    for (const ch of slice) {
      getProgrammes(ch).then((items) => {
        if (!alive) return;
        setData((d) => (d[ch.id] === items ? d : { ...d, [ch.id]: items }));
      });
    }
    return () => { alive = false; };
  }, [range.s, range.e, channels]);

  // Al montar, coloca la linea de "ahora" a la vista
  useEffect(() => {
    const el = scRef.current;
    if (!el) return;
    const x = ((Date.now() - startMs) / 60000) * pxPerMin;
    el.scrollLeft = Math.max(0, x - 140);
  }, [startMs, pxPerMin]);

  // Mantiene visible la fila seleccionada con teclado
  useEffect(() => {
    const el = scRef.current;
    if (!el || !selectedId) return;
    const i = channels.findIndex((c) => c.id === selectedId);
    if (i < 0) return;
    const top = i * ROW + 40;
    if (top < el.scrollTop + 40 || top + ROW > el.scrollTop + el.clientHeight) {
      el.scrollTop = Math.max(0, top - el.clientHeight / 2);
    }
  }, [selectedId, channels]);

  const marks: number[] = [];
  for (let m = 0; m <= minutes; m += 30) marks.push(m);

  const nowX = ((now - startMs) / 60000) * pxPerMin;
  const rows = channels.slice(range.s, range.e);
  const dateLabel = new Date(startMs).toLocaleDateString("es-ES", { weekday: "short", day: "2-digit", month: "short" });

  const blocksFor = (items: Programme[] | undefined): Block[] => {
    if (!items || items.length === 0) {
      const out: Block[] = [];
      for (let m = 0; m < minutes; m += 30) out.push({ left: m * pxPerMin, width: 30 * pxPerMin, p: null });
      return out;
    }
    const out: Block[] = [];
    for (const p of items) {
      const a = Math.max(0, ((p.start - startMs) / 60000) * pxPerMin);
      const b = Math.min(width, ((p.end - startMs) / 60000) * pxPerMin);
      if (b - a > 1) out.push({ left: a, width: b - a, p });
    }
    if (out.length === 0) out.push({ left: 0, width, p: null });
    return out;
  };

  const onKey = (e: React.KeyboardEvent) => {
    const i = channels.findIndex((c) => c.id === selectedId);
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      const n = e.key === "ArrowDown" ? Math.min(channels.length - 1, i + 1) : Math.max(0, i - 1);
      if (channels[n]) onSelect(channels[n]);
    } else if (e.key === "Enter" && i >= 0) {
      e.preventDefault();
      onPlay(channels[i]);
    } else if (e.key === "ArrowRight" || e.key === "ArrowLeft") {
      e.preventDefault();
      scRef.current?.scrollBy({ left: (e.key === "ArrowRight" ? 1 : -1) * 30 * pxPerMin, behavior: "smooth" });
    }
  };

  return (
    <div
      ref={scRef}
      tabIndex={0}
      onKeyDown={onKey}
      className="sb-scroll relative min-h-0 flex-1 overflow-auto bg-[#070a12] outline-none"
    >
      <div style={{ width: LEFT + width, position: "relative" }}>
        {/* Regla de horas */}
        <div className="sticky top-0 z-30 flex h-10 border-b border-[#22304a] bg-[#0d1320]">
          <div className="sticky left-0 z-40 flex h-10 shrink-0 items-center border-r border-[#22304a] bg-[#0d1320] px-3 text-[13px] font-bold capitalize" style={{ width: LEFT }}>
            {dateLabel} <span className="sb-tnum ml-2 text-[#4c8dff]">{hhmm(now)}</span>
          </div>
          <div className="relative h-10" style={{ width }}>
            {marks.map((m) => (
              <div key={m} className="absolute top-0 flex h-10 items-center" style={{ left: m * pxPerMin }}>
                <span className="sb-tnum pl-1.5 text-[11px] text-[#93a3bd]">{hhmm(startMs + m * 60000)}</span>
                <span className="absolute left-0 top-6 h-4 w-px bg-[#22304a]" />
              </div>
            ))}
            {nowX >= 0 && nowX <= width && (
              <div className="absolute top-0 z-10 h-10" style={{ left: nowX }}>
                <span className="absolute -left-1 top-6 h-2 w-2 rounded-full bg-[#38bdf8]" />
              </div>
            )}
          </div>
        </div>

        {/* Cuerpo virtualizado */}
        <div style={{ height: channels.length * ROW, position: "relative" }}>
          <div style={{ position: "absolute", top: range.s * ROW, left: 0, width: LEFT + width }}>
            {rows.map((ch, i) => {
              const n = range.s + i;
              const on = ch.id === selectedId;
              const logo = imgUrl(ch.logo);
              const blocks = blocksFor(data[ch.id]);
              return (
                <div key={ch.id} className="flex border-b border-[#141d2e]" style={{ height: ROW }}>
                  <div
                    onClick={() => onSelect(ch)}
                    onDoubleClick={() => onPlay(ch)}
                    className={clsx(
                      "group sticky left-0 z-20 flex shrink-0 cursor-pointer items-center gap-2 border-r border-[#22304a] px-2",
                      on ? "sb-row-on" : "bg-[#0d1320] hover:bg-[#141d2e]"
                    )}
                    style={{ width: LEFT }}
                  >
                    <span className="sb-tnum w-8 shrink-0 text-right text-[11px] text-[#5d6d88]">{n + 1}</span>
                    <span className="flex h-7 w-10 shrink-0 items-center justify-center overflow-hidden rounded bg-[#070a12] ring-1 ring-[#22304a]">
                      {logo ? (
                        <img src={logo} alt="" loading="lazy" className="h-full w-full object-contain p-0.5" />
                      ) : (
                        <span className="text-[9px] font-bold text-[#5d6d88]">{ch.name.slice(0, 2).toUpperCase()}</span>
                      )}
                    </span>
                    <span className={clsx("min-w-0 flex-1 truncate text-[13px]", on ? "font-bold text-white" : "font-medium")}>
                      {ch.name}
                    </span>
                    <button
                      onClick={(e) => { e.stopPropagation(); onPlay(ch); }}
                      className="shrink-0 rounded p-1 opacity-0 transition-opacity hover:bg-white/10 group-hover:opacity-100"
                      aria-label={`Reproducir ${ch.name}`}
                    >
                      <Play className="h-3.5 w-3.5 text-[#4c8dff]" fill="currentColor" />
                    </button>
                  </div>

                  <div className="relative" style={{ width }} onClick={() => onSelect(ch)}>
                    {blocks.map((b, k) => {
                      const live = b.p && b.p.start <= now && b.p.end > now;
                      return (
                        <div
                          key={k}
                          title={b.p ? `${hhmm(b.p.start)} - ${hhmm(b.p.end)}  ${b.p.title}` : NO_INFO}
                          className={clsx(
                            "absolute top-1 bottom-1 overflow-hidden rounded-md border px-2 py-1",
                            live
                              ? "border-[#4c8dff]/60 bg-[#4c8dff]/12"
                              : b.p
                                ? "border-[#22304a] bg-[#101828]"
                                : "border-[#1a2438] bg-[#0b111d]"
                          )}
                          style={{ left: b.left + 2, width: Math.max(0, b.width - 4) }}
                        >
                          <p className={clsx("truncate text-[12px] leading-tight", b.p ? "text-[#eef3fb]" : "text-[#5d6d88]")}>
                            {b.p ? b.p.title : NO_INFO}
                          </p>
                          {b.p && b.width > 110 && (
                            <p className="sb-tnum truncate text-[10px] text-[#5d6d88]">{hhmm(b.p.start)} - {hhmm(b.p.end)}</p>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>

          {/* Linea de ahora */}
          {nowX >= 0 && nowX <= width && (
            <div
              className="pointer-events-none absolute top-0 z-10 w-px bg-[#38bdf8]"
              style={{ left: LEFT + nowX, height: channels.length * ROW, boxShadow: "0 0 10px rgba(56,189,248,.8)" }}
            />
          )}
        </div>
      </div>

      {channels.length === 0 && (
        <p className="py-16 text-center text-sm text-[#5d6d88]">No hay canales con ese filtro.</p>
      )}
    </div>
  );
}
'@

# ============================================================== pagina TV Guia
Save-File 'src/pages/TvGuide.tsx' @'
import { useDeferredValue, useEffect, useMemo, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { List, CalendarClock, ZoomIn, ZoomOut, Locate } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { CategoryColumn, type CatKey } from "../components/tv/CategoryColumn";
import { ChannelPreview } from "../components/tv/ChannelPreview";
import { EpgTimeline } from "../components/tv/EpgTimeline";
import { CategoryPage } from "./CategoryPage";
import type { Channel } from "../types";
import "../styles/streambox-ui.css";

const MINUTES = 360;

export function TvGuide() {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const setNowPlaying = useStore((s) => s.setNowPlaying);
  const { favSet, toggle } = useFavorites();

  const [mode, setMode] = useState<"guide" | "list">("guide");
  const [cat, setCat] = useState<CatKey>("__all");
  const [query, setQuery] = useState("");
  const q = useDeferredValue(query);
  const [pxPerMin, setPxPerMin] = useState(6);
  const [selected, setSelected] = useState<Channel | null>(null);
  const [startMs, setStartMs] = useState(() => {
    const d = new Date();
    d.setMinutes(d.getMinutes() < 30 ? 0 : 30, 0, 0);
    return d.getTime() - 30 * 60000;
  });

  const recent = useLiveQuery(async () => {
    const rows = await db.history.orderBy("updatedAt").reverse().limit(60).toArray();
    return new Set(rows.map((r) => r.id));
  }, []);

  const all = useLiveQuery(
    () =>
      activePlaylistId
        ? db.channels.where("[playlistId+category]").equals([activePlaylistId, "live"]).toArray()
        : Promise.resolve([] as Channel[]),
    [activePlaylistId]
  );

  const groups = useMemo(
    () => Array.from(new Set((all ?? []).map((c) => c.group || "Sin categoria"))).sort((a, b) => a.localeCompare(b)),
    [all]
  );

  const visible = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (all ?? []).filter((c) => {
      const g = c.group || "Sin categoria";
      if (cat === "__fav" && !favSet.has(c.id)) return false;
      if (cat === "__recent" && !(recent?.has(c.id))) return false;
      if (cat !== "__all" && cat !== "__fav" && cat !== "__recent" && g !== cat) return false;
      if (needle && !c.name.toLowerCase().includes(needle)) return false;
      return true;
    });
  }, [all, cat, q, favSet, recent]);

  useEffect(() => {
    if (visible.length === 0) { setSelected(null); return; }
    if (!selected || !visible.some((c) => c.id === selected.id)) setSelected(visible[0]);
  }, [visible]); // eslint-disable-line react-hooks/exhaustive-deps

  if (mode === "list") {
    return (
      <div className="sb-scope">
        <button
          onClick={() => setMode("guide")}
          className="mb-4 flex items-center gap-2 rounded-lg border border-[#22304a] bg-[#0d1320] px-3 py-1.5 text-sm hover:bg-[#141d2e]"
        >
          <CalendarClock className="h-4 w-4 text-[#4c8dff]" /> Volver a la guia
        </button>
        <CategoryPage category="live" title="TV en vivo" placeholder="Buscar canal..." noun="canales" />
      </div>
    );
  }

  if (!activePlaylistId) {
    return <div className="py-20 text-center text-[#93a3bd]">Carga una lista en Mis listas para ver la guia.</div>;
  }

  const jumpNow = () => {
    const d = new Date();
    d.setMinutes(d.getMinutes() < 30 ? 0 : 30, 0, 0);
    setStartMs(d.getTime() - 30 * 60000);
  };

  return (
    <div className="sb-scope sb-in flex h-[calc(100vh-11rem)] min-h-[520px] overflow-hidden rounded-xl border border-[#22304a] bg-[#070a12]">
      <aside className="hidden w-[262px] shrink-0 lg:block">
        <CategoryColumn channels={all ?? []} value={cat} onChange={setCat} query={query} onQuery={setQuery} />
      </aside>

      <section className="flex min-w-0 flex-1 flex-col">
        <ChannelPreview channel={selected} isFav={!!selected && favSet.has(selected.id)} onFav={toggle} onPlay={setNowPlaying} />

        <div className="flex shrink-0 flex-wrap items-center gap-2 border-b border-[#22304a] bg-[#0d1320] px-3 py-2">
          <select
            value={cat}
            onChange={(e) => setCat(e.target.value)}
            className="max-w-[220px] rounded-lg border border-[#22304a] bg-[#070a12] px-2 py-1.5 text-xs focus:border-[#4c8dff] focus:outline-none lg:hidden"
          >
            <option value="__all">Todos ({(all ?? []).length})</option>
            <option value="__fav">Favoritos</option>
            <option value="__recent">Recientes</option>
            {groups.map((g) => <option key={g} value={g}>{g}</option>)}
          </select>

          <span className="sb-tnum rounded-full bg-[#141d2e] px-2.5 py-1 text-[11px] font-semibold text-[#93a3bd]">
            {visible.length.toLocaleString()} canales
          </span>

          <div className="flex-1" />

          <button onClick={jumpNow} className="flex items-center gap-1.5 rounded-lg border border-[#22304a] px-2.5 py-1.5 text-xs hover:bg-[#141d2e]">
            <Locate className="h-3.5 w-3.5 text-[#38bdf8]" /> Ahora
          </button>
          <div className="flex items-center gap-1 rounded-lg border border-[#22304a] px-1 py-0.5">
            <button onClick={() => setPxPerMin((v) => Math.max(3, v - 1.5))} className="rounded p-1 hover:bg-[#141d2e]" aria-label="Alejar">
              <ZoomOut className="h-3.5 w-3.5" />
            </button>
            <span className="sb-tnum w-8 text-center text-[11px] text-[#93a3bd]">{pxPerMin.toFixed(1)}</span>
            <button onClick={() => setPxPerMin((v) => Math.min(16, v + 1.5))} className="rounded p-1 hover:bg-[#141d2e]" aria-label="Acercar">
              <ZoomIn className="h-3.5 w-3.5" />
            </button>
          </div>
          <button
            onClick={() => setMode("list")}
            className={clsx("flex items-center gap-1.5 rounded-lg border border-[#22304a] px-2.5 py-1.5 text-xs hover:bg-[#141d2e]")}
          >
            <List className="h-3.5 w-3.5" /> Lista
          </button>
        </div>

        <EpgTimeline
          channels={visible}
          selectedId={selected?.id ?? null}
          onSelect={setSelected}
          onPlay={setNowPlaying}
          pxPerMin={pxPerMin}
          startMs={startMs}
          minutes={MINUTES}
        />
      </section>
    </div>
  );
}
'@

# ==================================================================== poster
Save-File 'src/components/vod/Poster.tsx' @'
import { memo, useState } from "react";
import { Play, Star, Check } from "lucide-react";
import { clsx } from "clsx";
import { imgUrl } from "../../services/proxy";
import type { Channel } from "../../types";

interface Props {
  item: Channel;
  onOpen: (c: Channel) => void;
  width: number;
  progress?: number;
  fav?: boolean;
  onFav?: (id: string) => void;
}

function Base({ item, onOpen, width, progress, fav, onFav }: Props) {
  const [bad, setBad] = useState(false);
  const src = imgUrl(item.logo);
  return (
    <div className="shrink-0" style={{ width }}>
      <button
        data-sbfocus="1"
        onClick={() => onOpen(item)}
        title={item.name}
        className="sb-poster group relative block w-full overflow-hidden rounded-xl border border-[#22304a] bg-[#0d1320] text-left"
      >
        <div className="relative aspect-[2/3] w-full overflow-hidden bg-gradient-to-br from-[#141d2e] to-[#070a12]">
          {src && !bad ? (
            <img src={src} alt="" loading="lazy" decoding="async" onError={() => setBad(true)} className="h-full w-full object-cover" />
          ) : (
            <div className="flex h-full w-full items-center justify-center p-3 text-center text-xs font-semibold text-[#5d6d88]">
              {item.name.slice(0, 46)}
            </div>
          )}

          <div className="absolute inset-0 bg-gradient-to-t from-[#070a12] via-transparent to-transparent opacity-0 transition-opacity group-hover:opacity-100" />
          <div className="absolute inset-0 flex items-center justify-center opacity-0 transition-opacity group-hover:opacity-100">
            <span className="flex h-12 w-12 items-center justify-center rounded-full bg-white/95 shadow-lg">
              <Play className="h-5 w-5 text-black" fill="currentColor" />
            </span>
          </div>

          {item.rating && (
            <span className="sb-tnum absolute left-2 top-2 flex items-center gap-1 rounded-md bg-black/75 px-1.5 py-0.5 text-[10px] font-bold text-[#ffb020]">
              <Star className="h-2.5 w-2.5" fill="currentColor" /> {item.rating}
            </span>
          )}
          {fav && (
            <span className="absolute right-2 top-2 flex h-5 w-5 items-center justify-center rounded-full bg-[#4c8dff]">
              <Check className="h-3 w-3 text-white" />
            </span>
          )}
          {progress != null && progress > 0 && (
            <span className="absolute inset-x-0 bottom-0 h-1 bg-black/70">
              <span className="block h-full bg-gradient-to-r from-[#4c8dff] to-[#38bdf8]" style={{ width: `${Math.min(100, progress)}%` }} />
            </span>
          )}
        </div>
      </button>

      <div className="mt-2 flex items-start gap-1">
        <p className="min-w-0 flex-1 truncate text-[13px] font-medium">{item.name}</p>
        {onFav && (
          <button onClick={() => onFav(item.id)} className="shrink-0 rounded p-0.5 hover:bg-white/10" aria-label="Favorito">
            <Star className={clsx("h-3.5 w-3.5", fav ? "fill-[#ffb020] text-[#ffb020]" : "text-[#5d6d88]")} />
          </button>
        )}
      </div>
      <p className="truncate text-[11px] text-[#5d6d88]">{item.group}</p>
    </div>
  );
}

export const Poster = memo(Base);
'@

# =============================================================== carrusel fila
Save-File 'src/components/vod/PosterRow.tsx' @'
import { useRef, useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { Poster } from "./Poster";
import type { Channel } from "../../types";

interface Props {
  title: string;
  accent?: string;
  items: Channel[];
  onOpen: (c: Channel) => void;
  width?: number;
  favSet?: Set<string>;
  onFav?: (id: string) => void;
  progressOf?: (id: string) => number | undefined;
  onSeeAll?: () => void;
}

export function PosterRow({ title, accent = "#4c8dff", items, onOpen, width = 158, favSet, onFav, progressOf, onSeeAll }: Props) {
  const ref = useRef<HTMLDivElement | null>(null);
  const [hover, setHover] = useState(false);
  if (items.length === 0) return null;

  const step = () => Math.max(320, (ref.current?.clientWidth ?? 600) - 120);
  const go = (dir: number) => ref.current?.scrollBy({ left: dir * step(), behavior: "smooth" });

  return (
    <section className="sb-in" onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}>
      <div className="mb-2.5 flex items-baseline gap-3 px-1">
        <h2 className="text-lg font-bold tracking-tight">{title}</h2>
        <span className="sb-tnum text-[11px] font-semibold uppercase tracking-widest" style={{ color: accent }}>
          {items.length}
        </span>
        <div className="flex-1" />
        {onSeeAll && (
          <button onClick={onSeeAll} className="text-xs font-semibold text-[#93a3bd] hover:text-white">
            Ver todo
          </button>
        )}
      </div>

      <div className="relative">
        <div ref={ref} className="sb-noscroll flex gap-3 overflow-x-auto px-1 pb-3 pt-1">
          {items.map((it) => (
            <Poster
              key={it.id}
              item={it}
              onOpen={onOpen}
              width={width}
              fav={favSet?.has(it.id)}
              onFav={onFav}
              progress={progressOf?.(it.id)}
            />
          ))}
        </div>

        {hover && items.length > 3 && (
          <>
            <button
              onClick={() => go(-1)}
              className="absolute left-0 top-0 z-30 flex h-[calc(100%-3rem)] w-10 items-center justify-center rounded-l-xl sb-fade-l"
              aria-label="Anterior"
            >
              <ChevronLeft className="h-7 w-7 text-white drop-shadow" />
            </button>
            <button
              onClick={() => go(1)}
              className="absolute right-0 top-0 z-30 flex h-[calc(100%-3rem)] w-10 items-center justify-center rounded-r-xl sb-fade-r"
              aria-label="Siguiente"
            >
              <ChevronRight className="h-7 w-7 text-white drop-shadow" />
            </button>
          </>
        )}
      </div>
    </section>
  );
}
'@

# ================================================================= hero portada
Save-File 'src/components/vod/HeroSpotlight.tsx' @'
import { useState } from "react";
import { Play, Star, Info, Plus, Check } from "lucide-react";
import { imgUrl } from "../../services/proxy";
import type { Channel } from "../../types";

interface Props {
  item: Channel;
  kind: "movies" | "series";
  fav: boolean;
  onFav: (id: string) => void;
  onOpen: (c: Channel) => void;
}

export function HeroSpotlight({ item, kind, fav, onFav, onOpen }: Props) {
  const [bad, setBad] = useState(false);
  const src = imgUrl(item.logo);
  return (
    <section className="relative overflow-hidden rounded-2xl border border-[#22304a] bg-[#0d1320]">
      {src && !bad && (
        <img src={src} alt="" onError={() => setBad(true)} className="absolute inset-0 h-full w-full scale-110 object-cover opacity-25 blur-[3px]" />
      )}
      <div className="absolute inset-0 bg-gradient-to-r from-[#070a12] via-[#070a12]/90 to-[#070a12]/20" />
      <div className="absolute inset-0 bg-gradient-to-t from-[#070a12] via-transparent to-transparent" />
      <div className="sb-grain pointer-events-none absolute inset-0 opacity-[0.05] mix-blend-overlay" />

      <div className="relative flex min-h-[300px] items-end gap-6 p-6 md:p-9">
        {src && !bad && (
          <img src={src} alt="" className="hidden h-[220px] w-[147px] shrink-0 rounded-xl object-cover shadow-2xl ring-1 ring-white/10 md:block" />
        )}
        <div className="min-w-0 flex-1">
          <p className="text-[11px] font-bold uppercase tracking-[0.24em] text-[#4c8dff]">
            {kind === "movies" ? "Pelicula destacada" : "Serie destacada"}
          </p>
          <h1 className="mt-2 line-clamp-2 text-3xl font-black leading-tight tracking-tight md:text-5xl">{item.name}</h1>
          <div className="mt-3 flex flex-wrap items-center gap-3 text-sm text-[#93a3bd]">
            {item.rating && (
              <span className="sb-tnum flex items-center gap-1 font-bold text-[#ffb020]">
                <Star className="h-3.5 w-3.5" fill="currentColor" /> {item.rating}
              </span>
            )}
            {item.year && <span className="sb-tnum">{item.year}</span>}
            <span className="truncate">{item.group}</span>
          </div>
          {item.plot && <p className="mt-3 line-clamp-3 max-w-2xl text-sm text-[#93a3bd]">{item.plot}</p>}

          <div className="mt-5 flex flex-wrap gap-2">
            <button
              data-sbfocus="1"
              onClick={() => onOpen(item)}
              className="flex items-center gap-2 rounded-lg bg-white px-5 py-2.5 font-bold text-black hover:bg-white/85"
            >
              <Play className="h-4 w-4" fill="currentColor" /> {kind === "movies" ? "Reproducir" : "Ver episodios"}
            </button>
            <button
              data-sbfocus="1"
              onClick={() => onFav(item.id)}
              className="flex items-center gap-2 rounded-lg bg-white/12 px-4 py-2.5 font-semibold backdrop-blur hover:bg-white/20"
            >
              {fav ? <Check className="h-4 w-4" /> : <Plus className="h-4 w-4" />}
              {fav ? "En mi lista" : "Mi lista"}
            </button>
            <button
              onClick={() => onOpen(item)}
              className="flex items-center gap-2 rounded-lg bg-white/12 px-4 py-2.5 font-semibold backdrop-blur hover:bg-white/20"
            >
              <Info className="h-4 w-4" /> Detalles
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}
'@

# ============================================================ pagina portadas
Save-File 'src/pages/VodBrowse.tsx' @'
import { useDeferredValue, useMemo, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Search, LayoutGrid, Rows3, Star } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { PosterRow } from "../components/vod/PosterRow";
import { Poster } from "../components/vod/Poster";
import { HeroSpotlight } from "../components/vod/HeroSpotlight";
import { CategoryPage } from "./CategoryPage";
import type { Channel } from "../types";
import "../styles/streambox-ui.css";

interface Props { kind: "movies" | "series" }

export function VodBrowse({ kind }: Props) {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const setNowPlaying = useStore((s) => s.setNowPlaying);
  const { favSet, toggle } = useFavorites();

  const [view, setView] = useState<"rows" | "grid" | "list">("rows");
  const [group, setGroup] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const q = useDeferredValue(query);

  const items = useLiveQuery(
    () =>
      activePlaylistId
        ? db.channels.where("[playlistId+category]").equals([activePlaylistId, kind]).toArray()
        : Promise.resolve([] as Channel[]),
    [activePlaylistId, kind]
  );

  const hist = useLiveQuery(async () => {
    const rows = await db.history.orderBy("updatedAt").reverse().limit(80).toArray();
    return rows.filter((r) => r.duration > 0 && r.position > 30 && r.position / r.duration < 0.97);
  }, []);

  const resume = useMemo(() => {
    if (!hist || !items) return [] as Array<{ ch: Channel; pct: number }>;
    const byId = new Map(items.map((c) => [c.id, c]));
    const out: Array<{ ch: Channel; pct: number }> = [];
    for (const h of hist) {
      const ch = byId.get(h.id);
      if (ch) out.push({ ch, pct: (h.position / h.duration) * 100 });
      if (out.length >= 18) break;
    }
    return out;
  }, [hist, items]);

  const pctMap = useMemo(() => new Map(resume.map((r) => [r.ch.id, r.pct])), [resume]);

  const groups = useMemo(() => {
    const m = new Map<string, Channel[]>();
    for (const c of items ?? []) {
      const g = c.group || "Sin categoria";
      const arr = m.get(g);
      if (arr) arr.push(c); else m.set(g, [c]);
    }
    return Array.from(m.entries()).sort((a, b) => b[1].length - a[1].length);
  }, [items]);

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (items ?? []).filter(
      (c) => (!group || (c.group || "Sin categoria") === group) && (!needle || c.name.toLowerCase().includes(needle))
    );
  }, [items, group, q]);

  const hero = useMemo(() => {
    const pool = (items ?? []).filter((c) => c.logo);
    if (pool.length === 0) return null;
    return pool[Math.floor(Math.random() * Math.min(pool.length, 60))];
  }, [items]);

  const title = kind === "movies" ? "Peliculas" : "Series";
  const noun = kind === "movies" ? "peliculas" : "series";

  if (view === "list") {
    return (
      <div className="sb-scope">
        <button onClick={() => setView("rows")} className="mb-4 flex items-center gap-2 rounded-lg border border-[#22304a] bg-[#0d1320] px-3 py-1.5 text-sm hover:bg-[#141d2e]">
          <Rows3 className="h-4 w-4 text-[#4c8dff]" /> Volver a portadas
        </button>
        <CategoryPage category={kind} title={title} placeholder={`Buscar ${noun}...`} noun={noun} />
      </div>
    );
  }

  if (!activePlaylistId) {
    return <div className="py-20 text-center text-[#93a3bd]">Carga una lista en Mis listas para ver el catalogo.</div>;
  }

  const searching = q.trim().length > 0 || !!group;

  return (
    <div className="sb-scope sb-in space-y-7">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="text-2xl font-black tracking-tight md:text-3xl">{title}</h1>
        <span className="sb-tnum rounded-full bg-[#141d2e] px-2.5 py-1 text-[11px] font-semibold text-[#93a3bd]">
          {(items ?? []).length.toLocaleString()}
        </span>
        <div className="flex-1" />
        <div className="relative w-full max-w-xs">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#5d6d88]" />
          <input
            value={query}
            onChange={(e) => { setQuery(e.target.value); setGroup(null); }}
            placeholder={`Buscar ${noun}...`}
            className="w-full rounded-lg border border-[#22304a] bg-[#0d1320] py-2 pl-9 pr-3 text-sm placeholder:text-[#5d6d88] focus:border-[#4c8dff] focus:outline-none"
          />
        </div>
        <div className="flex overflow-hidden rounded-lg border border-[#22304a]">
          {([["rows", Rows3], ["grid", LayoutGrid]] as const).map(([k, Icon]) => (
            <button
              key={k}
              onClick={() => { setView(k); setGroup(null); }}
              className={clsx("p-2", view === k ? "bg-[#4c8dff]/20 text-[#4c8dff]" : "hover:bg-[#141d2e]")}
              aria-label={k === "rows" ? "Carruseles" : "Rejilla"}
            >
              <Icon className="h-4 w-4" />
            </button>
          ))}
          <button onClick={() => setView("list")} className="p-2 hover:bg-[#141d2e]" aria-label="Lista clasica">
            <Star className="h-4 w-4" />
          </button>
        </div>
      </div>

      {!searching && view === "rows" && hero && (
        <HeroSpotlight item={hero} kind={kind} fav={favSet.has(hero.id)} onFav={toggle} onOpen={setNowPlaying} />
      )}

      {!searching && resume.length > 0 && (
        <PosterRow
          title="Continuar viendo"
          accent="#38bdf8"
          items={resume.map((r) => r.ch)}
          onOpen={setNowPlaying}
          favSet={favSet}
          onFav={toggle}
          progressOf={(id) => pctMap.get(id)}
          width={230}
        />
      )}

      {!searching && view === "rows" && groups.slice(0, 14).map(([g, list]) => (
        <PosterRow
          key={g}
          title={g}
          items={list.slice(0, 24)}
          onOpen={setNowPlaying}
          favSet={favSet}
          onFav={toggle}
          progressOf={(id) => pctMap.get(id)}
          onSeeAll={() => { setGroup(g); setView("grid"); }}
        />
      ))}

      {(searching || view === "grid") && (
        <>
          {group && (
            <div className="flex items-center gap-3">
              <h2 className="text-lg font-bold">{group}</h2>
              <button onClick={() => { setGroup(null); setView("rows"); }} className="text-xs text-[#93a3bd] hover:text-white">
                Volver
              </button>
            </div>
          )}
          <p className="sb-tnum text-sm text-[#93a3bd]">{filtered.length.toLocaleString()} resultados</p>
          <div className="flex flex-wrap gap-4">
            {filtered.slice(0, 240).map((it) => (
              <Poster key={it.id} item={it} onOpen={setNowPlaying} width={158} fav={favSet.has(it.id)} onFav={toggle} progress={pctMap.get(it.id)} />
            ))}
          </div>
          {filtered.length === 0 && <p className="py-14 text-center text-[#5d6d88]">Sin resultados.</p>}
          {filtered.length > 240 && (
            <p className="text-center text-xs text-[#5d6d88]">Mostrando 240. Afina la busqueda para ver mas.</p>
          )}
        </>
      )}
    </div>
  );
}
'@

# ============================================ envoltorios (archivos de 4 lineas)
Save-File 'src/pages/LiveTV.tsx' @'
import { TvGuide } from "./TvGuide";

export function LiveTV() {
  return <TvGuide />;
}
'@

Save-File 'src/pages/Movies.tsx' @'
import { VodBrowse } from "./VodBrowse";

export function Movies() {
  return <VodBrowse kind="movies" />;
}
'@

Save-File 'src/pages/Series.tsx' @'
import { VodBrowse } from "./VodBrowse";

export function Series() {
  return <VodBrowse kind="series" />;
}
'@

Write-Host ""
Write-Host "Listo. Verifica y arranca:" -ForegroundColor Green
Write-Host "  npm run build" -ForegroundColor White
Write-Host "  npm start        (o  npx tauri dev  con npm run server al lado)" -ForegroundColor White
Write-Host ""
Write-Host "TV en vivo  -> columna de categorias con contadores + guia con horarios" -ForegroundColor Cyan
Write-Host "Peliculas/Series -> portada hero + carruseles de posters + continuar viendo" -ForegroundColor Cyan
Write-Host "Cada vista tiene un boton para volver a la lista clasica." -ForegroundColor Gray