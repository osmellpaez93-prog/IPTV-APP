<#
  StreamBox - update-zonix-ui.ps1
  ---------------------------------------------------------------------------
  Rediseño de interfaz inspirado en Zonix (sin copiar codigo ni assets):
    * El reproductor SALE del flujo del documento: ya no empuja ni parte la lista.
    * Tres modos: Mini flotante (arrastrable, 3 tamaños, 4 esquinas), Teatro
      (video + rail de canales con scroll propio) y Pantalla completa.
    * Multivision hasta 4 canales, audio solo en la celda activa.
    * Rail lateral de categorias, barra superior con reloj y busqueda.
    * Grid virtualizado real y densidad ajustable.
    * Panel de imagen en vivo: brillo, contraste, saturacion, zoom, encuadre.
    * Navegacion por flechas / D-pad.

  Uso (raiz del repo):
    powershell -ExecutionPolicy Bypass -File .\update-zonix-ui.ps1

  Guarda .bak de cada archivo que cambia. No toca usePlayer.ts ni el proxy:
  la reproduccion que ya funciona se mantiene intacta. No requiere npm install.
#>
param([switch]$Force)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "package.json"))) {
  Write-Host "ERROR: ejecuta esto en la raiz del proyecto (donde esta package.json)." -ForegroundColor Red
  return
}
Write-Host ""
Write-Host "StreamBox - interfaz Zonix -> $root" -ForegroundColor Cyan
if (-not $Force) {
  $r = Read-Host "Aplicar cambios? (S/N)"
  if ($r -notmatch '^[sSyY]') { Write-Host "Cancelado."; return }
}

function Write-ProjectFile {
  param([string]$RelPath, [string]$Content)
  $full = Join-Path $root $RelPath
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if (-not $Content.EndsWith("`n")) { $Content += "`n" }
  if (Test-Path $full) {
    $old = [System.IO.File]::ReadAllText($full)
    if ($old -ne $Content) { Copy-Item $full "$full.bak" -Force }
  }
  [System.IO.File]::WriteAllText($full, $Content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  + $RelPath" -ForegroundColor Green
}

# ========================================================== tailwind.config.js
Write-ProjectFile 'tailwind.config.js' @'
/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Azul broadcast nocturno: la base de toda la superficie.
        bg: {
          deep: "#05070f",
          DEFAULT: "#0a0e1a",
          surface: "#111a2e",
          raised: "#18233c",
          line: "#26314f",
        },
        brand: { DEFAULT: "#e50914", hover: "#ff2430", soft: "#ff6b70" },
        signal: { DEFAULT: "#22d3ee", soft: "#7ee7f7", deep: "#0e7490" },
        gold: { DEFAULT: "#ffb020", soft: "#ffd27a" },
        iris: { DEFAULT: "#8b5cf6", soft: "#b79bff" },
        lime: { DEFAULT: "#a3e635", soft: "#d0f58a" },
        ink: { DEFAULT: "#f2f5fb", muted: "#9aa7c2", dim: "#63708d" },
        ok: "#22c55e",
        warn: "#f59e0b",
        danger: "#ef4444",
        info: "#38bdf8",
      },
      fontFamily: { sans: ['"Inter"', "system-ui", "sans-serif"] },
      boxShadow: {
        dock: "0 24px 60px -18px rgba(0,0,0,.9), 0 0 0 1px rgba(38,49,79,.9)",
        glow: "0 0 32px -6px var(--accent-glow)",
      },
      animation: {
        "fade-in": "fadeIn .28s ease-out both",
        "slide-up": "slideUp .34s cubic-bezier(.2,.8,.2,1) both",
        "pop-in": "popIn .2s cubic-bezier(.2,.9,.3,1.25) both",
        drift: "drift 30s ease-in-out infinite alternate",
        sheen: "sheen 2.6s linear infinite",
        "live-dot": "liveDot 1.6s ease-in-out infinite",
      },
      keyframes: {
        fadeIn: { "0%": { opacity: "0" }, "100%": { opacity: "1" } },
        slideUp: {
          "0%": { opacity: "0", transform: "translateY(16px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        popIn: {
          "0%": { opacity: "0", transform: "scale(.95)" },
          "100%": { opacity: "1", transform: "scale(1)" },
        },
        drift: {
          "0%": { transform: "translate3d(-5%,-3%,0) scale(1)" },
          "100%": { transform: "translate3d(6%,4%,0) scale(1.15)" },
        },
        sheen: {
          "0%": { backgroundPosition: "220% 0" },
          "100%": { backgroundPosition: "-220% 0" },
        },
        liveDot: {
          "0%,100%": { opacity: "1", transform: "scale(1)" },
          "50%": { opacity: ".35", transform: "scale(.8)" },
        },
      },
    },
  },
  plugins: [],
};
'@

# ================================================================ src/index.css
Write-ProjectFile 'src/index.css' @'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  color-scheme: dark;
  --accent: #22d3ee;
  --accent-soft: #7ee7f7;
  --accent-glow: rgba(34, 211, 238, 0.45);
  --sb-track: #070b16;
  --sb-thumb: #26314f;
}

html,
body,
#root {
  height: 100%;
  background: #0a0e1a;
  color: #f2f5fb;
}

html {
  scroll-behavior: smooth;
  scroll-padding-top: 96px;
}

body {
  overscroll-behavior-y: none;
}

/* ---------- Scrollbars con el lenguaje de la app ---------- */
* {
  scrollbar-width: thin;
  scrollbar-color: var(--sb-thumb) var(--sb-track);
}
*::-webkit-scrollbar {
  width: 10px;
  height: 10px;
}
*::-webkit-scrollbar-track {
  background: var(--sb-track);
  border-radius: 999px;
}
*::-webkit-scrollbar-thumb {
  background: linear-gradient(180deg, #2c3a5e, #1b2540);
  border: 2px solid var(--sb-track);
  border-radius: 999px;
}
*::-webkit-scrollbar-thumb:hover {
  background: linear-gradient(180deg, var(--accent), #8b5cf6);
}
*::-webkit-scrollbar-corner {
  background: transparent;
}
.no-scrollbar {
  scrollbar-width: none;
}
.no-scrollbar::-webkit-scrollbar {
  width: 0;
  height: 0;
}

/* ---------- Foco visible para teclado / D-pad ---------- */
[data-focusable="true"] {
  outline: none;
  transition: transform 0.16s cubic-bezier(0.2, 0.8, 0.2, 1), box-shadow 0.16s ease,
    background-color 0.16s ease, border-color 0.16s ease;
}
[data-focusable="true"]:focus-visible {
  box-shadow: 0 0 0 3px var(--accent), 0 0 30px var(--accent-glow);
  transform: scale(1.03);
  z-index: 6;
  position: relative;
}
input:focus-visible,
select:focus-visible,
textarea:focus-visible,
button:focus-visible {
  outline: none;
  box-shadow: 0 0 0 2px var(--accent);
}

/* ---------- Sliders propios ---------- */
input[type="range"].sb-range {
  -webkit-appearance: none;
  appearance: none;
  height: 18px;
  background: transparent;
  cursor: pointer;
}
input[type="range"].sb-range::-webkit-slider-runnable-track {
  height: 4px;
  border-radius: 999px;
  background: linear-gradient(90deg, var(--accent), #8b5cf6);
  opacity: 0.85;
}
input[type="range"].sb-range::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 14px;
  height: 14px;
  margin-top: -5px;
  border-radius: 999px;
  background: #f2f5fb;
  border: 2px solid var(--accent);
  box-shadow: 0 0 10px var(--accent-glow);
}
input[type="range"].sb-range::-moz-range-track {
  height: 4px;
  border-radius: 999px;
  background: linear-gradient(90deg, var(--accent), #8b5cf6);
}
input[type="range"].sb-range::-moz-range-thumb {
  width: 12px;
  height: 12px;
  border-radius: 999px;
  background: #f2f5fb;
  border: 2px solid var(--accent);
}

/* ---------- Textura y capas ---------- */
.skeleton {
  background: linear-gradient(90deg, #111a2e 0%, #1d2947 45%, #111a2e 90%);
  background-size: 220% 100%;
  animation: shimmer 1.5s linear infinite;
}
@keyframes shimmer {
  0% { background-position: 220% 0; }
  100% { background-position: -220% 0; }
}
.grain {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='140' height='140'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='3'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.45'/%3E%3C/svg%3E");
}
.safe-bottom {
  padding-bottom: max(env(safe-area-inset-bottom), 0.5rem);
}

video::cue {
  background: rgba(4, 7, 15, 0.78);
  color: #fff;
  font-size: 1.12em;
  line-height: 1.35;
  text-shadow: 0 2px 6px rgba(0, 0, 0, 0.95);
}

@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.001ms !important;
  }
}
'@

# ============================================================= src/store/index.ts
Write-ProjectFile 'src/store/index.ts' @'
import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Channel } from "../types";

export type ViewMode = "mini" | "theater" | "full";
export type MiniSize = "s" | "m" | "l";
export type Corner = "tl" | "tr" | "bl" | "br";
export type Density = "compact" | "normal" | "comfy";
export type Aspect = "contain" | "cover" | "fill";
export type Accent = "signal" | "brand" | "gold" | "iris" | "lime";

export interface MiniPrefs {
  size: MiniSize;
  corner: Corner;
  opacity: number;
}
export interface UIPrefs {
  scale: number;
  density: Density;
  columns: 0 | 1 | 2 | 3;
  posterScale: number;
  accent: Accent;
  hiddenGroups: string[];
}
export interface VideoPrefs {
  brightness: number;
  contrast: number;
  saturate: number;
  zoom: number;
  aspect: Aspect;
}

export const DEFAULT_UI: UIPrefs = {
  scale: 1,
  density: "normal",
  columns: 0,
  posterScale: 1,
  accent: "signal",
  hiddenGroups: [],
};
export const DEFAULT_VIDEO: VideoPrefs = {
  brightness: 100,
  contrast: 100,
  saturate: 100,
  zoom: 100,
  aspect: "contain",
};
export const DEFAULT_MINI: MiniPrefs = { size: "m", corner: "br", opacity: 100 };

export const ACCENTS: Record<Accent, { hex: string; soft: string; label: string }> = {
  signal: { hex: "#22d3ee", soft: "#7ee7f7", label: "Cian" },
  brand: { hex: "#e50914", soft: "#ff6b70", label: "Rojo" },
  gold: { hex: "#ffb020", soft: "#ffd27a", label: "Ambar" },
  iris: { hex: "#8b5cf6", soft: "#b79bff", label: "Violeta" },
  lime: { hex: "#a3e635", soft: "#d0f58a", label: "Lima" },
};

export const ROW_HEIGHT: Record<Density, number> = { compact: 56, normal: 72, comfy: 92 };

interface UIState {
  sidebarOpen: boolean;
  setSidebarOpen: (v: boolean) => void;
  toggleSidebar: () => void;

  activePlaylistId: string | null;
  setActivePlaylistId: (id: string | null) => void;

  nowPlaying: Channel | null;
  setNowPlaying: (c: Channel | null) => void;
  play: (c: Channel, list?: Channel[]) => void;

  queue: Channel[];
  setQueue: (list: Channel[]) => void;
  zap: (delta: number) => void;
  zapTo: (index: number) => void;

  openSeries: Channel | null;
  closeSeries: () => void;

  viewMode: ViewMode;
  setViewMode: (m: ViewMode) => void;

  mini: MiniPrefs;
  setMini: (patch: Partial<MiniPrefs>) => void;

  multiview: Channel[];
  mvActive: number;
  addMultiview: (c: Channel) => void;
  removeMultiview: (index: number) => void;
  setMvActive: (index: number) => void;
  clearMultiview: () => void;

  ui: UIPrefs;
  setUI: (patch: Partial<UIPrefs>) => void;
  toggleGroup: (group: string) => void;
  resetUI: () => void;

  video: VideoPrefs;
  setVideo: (patch: Partial<VideoPrefs>) => void;
  resetVideo: () => void;

  settingsOpen: boolean;
  setSettingsOpen: (v: boolean) => void;
}

export const useStore = create<UIState>()(
  persist(
    (set, get) => ({
      sidebarOpen: false,
      setSidebarOpen: (v) => set({ sidebarOpen: v }),
      toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),

      activePlaylistId: null,
      setActivePlaylistId: (id) => set({ activePlaylistId: id }),

      nowPlaying: null,
      queue: [],
      setNowPlaying: (c) =>
        set((s) => {
          if (c && c.seriesId) return { openSeries: c };
          if (!c) return { nowPlaying: null, viewMode: "mini" };
          const inQueue = s.queue.some((x) => x.id === c.id);
          return { nowPlaying: c, queue: inQueue ? s.queue : [c] };
        }),
      play: (c, list) =>
        set((s) => {
          if (c.seriesId) return { openSeries: c };
          return {
            nowPlaying: c,
            queue: list && list.length ? list : [c],
            viewMode: s.viewMode === "full" ? "theater" : s.viewMode,
          };
        }),

      setQueue: (list) => set({ queue: list }),
      zap: (delta) => {
        const { queue, nowPlaying } = get();
        if (!nowPlaying || queue.length < 2) return;
        const i = queue.findIndex((x) => x.id === nowPlaying.id);
        if (i < 0) return;
        set({ nowPlaying: queue[(i + delta + queue.length) % queue.length] });
      },
      zapTo: (index) => {
        const { queue } = get();
        if (index >= 0 && index < queue.length) set({ nowPlaying: queue[index] });
      },

      openSeries: null,
      closeSeries: () => set({ openSeries: null }),

      viewMode: "mini",
      setViewMode: (m) => set({ viewMode: m }),

      mini: DEFAULT_MINI,
      setMini: (patch) => set((s) => ({ mini: { ...s.mini, ...patch } })),

      multiview: [],
      mvActive: 0,
      addMultiview: (c) =>
        set((s) => {
          if (s.multiview.length >= 4 || s.multiview.some((x) => x.id === c.id)) return {};
          const next = [...s.multiview, c];
          return { multiview: next, mvActive: next.length - 1, nowPlaying: null };
        }),
      removeMultiview: (index) =>
        set((s) => {
          const next = s.multiview.filter((_, i) => i !== index);
          return { multiview: next, mvActive: Math.max(0, Math.min(s.mvActive, next.length - 1)) };
        }),
      setMvActive: (index) => set({ mvActive: index }),
      clearMultiview: () => set({ multiview: [], mvActive: 0 }),

      ui: DEFAULT_UI,
      setUI: (patch) => set((s) => ({ ui: { ...s.ui, ...patch } })),
      toggleGroup: (group) =>
        set((s) => ({
          ui: {
            ...s.ui,
            hiddenGroups: s.ui.hiddenGroups.includes(group)
              ? s.ui.hiddenGroups.filter((g) => g !== group)
              : [...s.ui.hiddenGroups, group],
          },
        })),
      resetUI: () => set({ ui: DEFAULT_UI, mini: DEFAULT_MINI }),

      video: DEFAULT_VIDEO,
      setVideo: (patch) => set((s) => ({ video: { ...s.video, ...patch } })),
      resetVideo: () => set({ video: DEFAULT_VIDEO }),

      settingsOpen: false,
      setSettingsOpen: (v) => set({ settingsOpen: v }),
    }),
    {
      name: "streambox-ui",
      partialize: (s) => ({
        activePlaylistId: s.activePlaylistId,
        ui: s.ui,
        mini: s.mini,
        video: s.video,
      }),
    }
  )
);
'@

# ======================================================== src/hooks/useSpatialNav.ts
Write-ProjectFile 'src/hooks/useSpatialNav.ts' @'
/**
 * Navegacion espacial (flechas / D-pad / mando).
 * Elige el enfocable mas cercano en la direccion pulsada. Los overlays
 * marcados con data-nav-lock encierran la navegacion; el reproductor
 * gestiona sus propias flechas.
 */
import { useEffect } from "react";

const SELECTOR = '[data-focusable="true"]';
const DIRS: Record<string, [number, number]> = {
  ArrowUp: [0, -1],
  ArrowDown: [0, 1],
  ArrowLeft: [-1, 0],
  ArrowRight: [1, 0],
};

function isTyping(el: Element | null): boolean {
  if (!el) return false;
  const t = el as HTMLElement;
  return (
    t.tagName === "INPUT" ||
    t.tagName === "TEXTAREA" ||
    t.tagName === "SELECT" ||
    t.isContentEditable === true
  );
}

export function useSpatialNav(enabled = true) {
  useEffect(() => {
    if (!enabled) return;

    const collect = (): HTMLElement[] => {
      const locks = document.querySelectorAll("[data-nav-lock]");
      const root: ParentNode = locks.length ? locks[locks.length - 1] : document;
      return (Array.from(root.querySelectorAll(SELECTOR)) as HTMLElement[]).filter((n) => {
        const r = n.getBoundingClientRect();
        return r.width > 1 && r.height > 1 && !n.hasAttribute("disabled");
      });
    };

    const pick = (nodes: HTMLElement[], dir: [number, number]): HTMLElement | null => {
      const active = document.activeElement as HTMLElement | null;
      if (!active || !nodes.includes(active)) return nodes[0] ?? null;
      const a = active.getBoundingClientRect();
      const ax = a.left + a.width / 2;
      const ay = a.top + a.height / 2;
      let best: HTMLElement | null = null;
      let bestScore = Infinity;
      for (const n of nodes) {
        if (n === active) continue;
        const r = n.getBoundingClientRect();
        const dx = r.left + r.width / 2 - ax;
        const dy = r.top + r.height / 2 - ay;
        const primary = dx * dir[0] + dy * dir[1];
        if (primary < 6) continue;
        const cross = Math.abs(dx * dir[1] - dy * dir[0]);
        const score = primary + cross * 2.4;
        if (score < bestScore) { bestScore = score; best = n; }
      }
      return best;
    };

    const onKey = (e: KeyboardEvent) => {
      if (e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
      const dir = DIRS[e.key];
      if (!dir) return;
      const target = e.target as HTMLElement | null;
      if (isTyping(target)) return;
      if (target && target.closest('[data-nav-scope="player"]')) return;

      const nodes = collect();
      if (!nodes.length) return;
      const found = pick(nodes, dir);
      if (found) {
        e.preventDefault();
        found.focus({ preventScroll: true });
        found.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "smooth" });
        return;
      }
      if (dir[1] !== 0 && !document.querySelector("[data-nav-lock]")) {
        e.preventDefault();
        window.scrollBy({ top: dir[1] * window.innerHeight * 0.55, behavior: "smooth" });
        window.setTimeout(() => {
          const again = pick(collect(), dir);
          if (again) {
            again.focus({ preventScroll: true });
            again.scrollIntoView({ block: "nearest", behavior: "smooth" });
          }
        }, 250);
      }
    };

    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [enabled]);
}
'@

# ======================================================= src/components/ChannelCard.tsx
Write-ProjectFile 'src/components/ChannelCard.tsx' @'
import { memo, useState } from "react";
import { clsx } from "clsx";
import { Star, Play, LayoutGrid } from "lucide-react";
import type { Channel } from "../types";
import { imgUrl } from "../services/proxy";
import { ROW_HEIGHT, useStore } from "../store";

interface Props {
  channel: Channel;
  isFavorite: boolean;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
  index?: number;
  playing?: boolean;
}

const TONE: Record<Channel["category"], string> = {
  live: "text-brand",
  movies: "text-gold",
  series: "text-iris",
  other: "text-signal",
};

function CardBase({ channel, isFavorite, onToggleFavorite, onPlay, index, playing }: Props) {
  const [imgError, setImgError] = useState(false);
  const density = useStore((s) => s.ui.density);
  const addMultiview = useStore((s) => s.addMultiview);
  const logo = imgUrl(channel.logo);
  const h = ROW_HEIGHT[density];
  const thumb = density === "compact" ? 36 : density === "comfy" ? 60 : 48;

  return (
    <div
      data-focusable="true"
      tabIndex={0}
      role="button"
      title={channel.name}
      aria-label={`Reproducir ${channel.name}`}
      onClick={() => onPlay(channel)}
      onKeyDown={(e) => {
        if (e.target !== e.currentTarget) return;
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onPlay(channel); }
      }}
      style={{ height: h }}
      className={clsx(
        "group relative flex items-center gap-3 rounded-xl border px-3 cursor-pointer",
        playing
          ? "border-signal/60 bg-signal/10"
          : "border-white/5 bg-bg-surface hover:border-signal/40 hover:bg-bg-raised"
      )}
    >
      <div
        style={{ width: thumb, height: thumb }}
        className="relative shrink-0 overflow-hidden rounded-lg bg-bg-deep ring-1 ring-white/5"
      >
        {logo && !imgError ? (
          <img src={logo} alt="" loading="lazy" decoding="async"
            onError={() => setImgError(true)} className="h-full w-full object-contain p-1" />
        ) : (
          <span className="flex h-full w-full items-center justify-center text-[11px] font-bold text-ink-dim">
            {channel.name.replace(/[^\p{L}\p{N}]/gu, "").slice(0, 2).toUpperCase() || "TV"}
          </span>
        )}
        <span className="absolute inset-0 flex items-center justify-center bg-black/60 opacity-0 transition-opacity group-hover:opacity-100">
          <Play className="h-4 w-4 text-white" fill="currentColor" />
        </span>
      </div>

      <div className="min-w-0 flex-1">
        <p className={clsx("truncate font-semibold leading-tight", density === "compact" ? "text-[13px]" : "text-sm")}>
          {channel.name}
        </p>
        {density !== "compact" && (
          <p className="mt-0.5 truncate text-xs text-ink-muted">
            {index != null && <span className={clsx("font-mono", TONE[channel.category])}>{index + 1} · </span>}
            {channel.group || "Sin categoria"}
          </p>
        )}
      </div>

      {playing && (
        <span className="hidden items-center gap-1 rounded-full bg-brand/20 px-2 py-0.5 text-[10px] font-bold text-brand sm:flex">
          <span className="h-1.5 w-1.5 animate-live-dot rounded-full bg-brand" /> AL AIRE
        </span>
      )}

      {channel.category === "live" && (
        <button
          onClick={(e) => { e.stopPropagation(); addMultiview(channel); }}
          className="hidden rounded-full p-2 text-ink-dim hover:bg-white/10 hover:text-signal sm:block"
          aria-label="Anadir a multivision"
          title="Anadir a multivision"
        >
          <LayoutGrid className="h-4 w-4" />
        </button>
      )}

      <button
        onClick={(e) => { e.stopPropagation(); onToggleFavorite(channel.id); }}
        className="rounded-full p-2 hover:bg-white/10"
        aria-label={isFavorite ? "Quitar de favoritos" : "Anadir a favoritos"}
      >
        <Star className={clsx("h-5 w-5", isFavorite ? "fill-gold text-gold" : "text-ink-dim")} />
      </button>
    </div>
  );
}

export const ChannelCard = memo(CardBase);
'@

# ======================================================= src/components/ChannelGrid.tsx
Write-ProjectFile 'src/components/ChannelGrid.tsx' @'
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { ChannelCard } from "./ChannelCard";
import { ROW_HEIGHT, useStore } from "../store";
import type { Channel } from "../types";

const GAP = 8;
const OVERSCAN = 6;

interface Props {
  channels: Channel[];
  favSet: Set<string>;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
  emptyText?: string;
}

/** Grid virtualizado sin dependencias: solo monta las filas visibles. */
export function ChannelGrid({
  channels, favSet, onToggleFavorite, onPlay, emptyText = "No se encontraron resultados.",
}: Props) {
  const wrapRef = useRef<HTMLDivElement | null>(null);
  const rafRef = useRef<number | null>(null);
  const density = useStore((s) => s.ui.density);
  const colPref = useStore((s) => s.ui.columns);
  const nowPlaying = useStore((s) => s.nowPlaying);
  const [autoCols, setAutoCols] = useState(2);
  const [range, setRange] = useState({ start: 0, end: 24 });

  const stride = ROW_HEIGHT[density] + GAP;
  const cols = colPref || autoCols;
  const rows = Math.ceil(channels.length / cols);

  const recompute = useCallback(() => {
    const el = wrapRef.current;
    if (!el) return;
    const top = -el.getBoundingClientRect().top;
    const vh = window.innerHeight || 800;
    const total = Math.ceil(channels.length / cols);
    const start = Math.max(0, Math.floor(top / stride) - OVERSCAN);
    const end = Math.min(total, Math.ceil((top + vh) / stride) + OVERSCAN);
    setRange((r) => (r.start === start && r.end === end ? r : { start, end }));
  }, [channels.length, cols, stride]);

  useLayoutEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const measure = () => {
      const w = el.clientWidth;
      setAutoCols(w >= 1180 ? 3 : w >= 700 ? 2 : 1);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    const schedule = () => {
      if (rafRef.current != null) return;
      rafRef.current = window.requestAnimationFrame(() => { rafRef.current = null; recompute(); });
    };
    schedule();
    window.addEventListener("scroll", schedule, { passive: true });
    window.addEventListener("resize", schedule);
    return () => {
      window.removeEventListener("scroll", schedule);
      window.removeEventListener("resize", schedule);
      if (rafRef.current != null) window.cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    };
  }, [recompute]);

  if (channels.length === 0) return <p className="py-14 text-center text-ink-muted">{emptyText}</p>;

  const slice = channels.slice(range.start * cols, range.end * cols);

  return (
    <div ref={wrapRef} style={{ height: Math.max(0, rows * stride - GAP), position: "relative" }}>
      <div
        style={{
          position: "absolute", top: range.start * stride, left: 0, right: 0,
          display: "grid", gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: GAP,
        }}
      >
        {slice.map((c, i) => (
          <ChannelCard
            key={c.id}
            channel={c}
            index={range.start * cols + i}
            playing={nowPlaying?.id === c.id}
            isFavorite={favSet.has(c.id)}
            onToggleFavorite={onToggleFavorite}
            onPlay={onPlay}
          />
        ))}
      </div>
    </div>
  );
}
'@

# ======================================================= src/components/ChannelRail.tsx
Write-ProjectFile 'src/components/ChannelRail.tsx' @'
import { memo, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Search, X } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { useStore } from "../store";
import { imgUrl } from "../services/proxy";
import type { Channel } from "../types";

const ROW = 60;
const OVERSCAN = 8;

interface Props {
  onClose?: () => void;
  onPick?: (c: Channel) => void;
  title?: string;
}

/** Panel de canales con scroll propio: nunca mueve la pagina de fondo. */
function RailBase({ onClose, onPick, title = "Canales" }: Props) {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const nowPlaying = useStore((s) => s.nowPlaying);
  const play = useStore((s) => s.play);
  const setQueue = useStore((s) => s.setQueue);
  const hiddenGroups = useStore((s) => s.ui.hiddenGroups);
  const category = nowPlaying?.category ?? "live";

  const [q, setQ] = useState("");
  const [group, setGroup] = useState("Todas");
  const [range, setRange] = useState({ start: 0, end: 20 });
  const scrollRef = useRef<HTMLDivElement | null>(null);

  const items = useLiveQuery(
    () =>
      activePlaylistId
        ? db.channels.where("[playlistId+category]").equals([activePlaylistId, category]).toArray()
        : Promise.resolve([] as Channel[]),
    [activePlaylistId, category]
  );

  const groups = useMemo(
    () => Array.from(new Set((items ?? []).map((c) => c.group || "Sin categoria"))).sort((a, b) => a.localeCompare(b)),
    [items]
  );
  const activeGroup = groups.includes(group) ? group : "Todas";

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (items ?? []).filter(
      (c) =>
        !hiddenGroups.includes(c.group || "Sin categoria") &&
        (activeGroup === "Todas" || (c.group || "Sin categoria") === activeGroup) &&
        (!needle || c.name.toLowerCase().includes(needle))
    );
  }, [items, activeGroup, q, hiddenGroups]);

  useEffect(() => { if (filtered.length) setQueue(filtered); }, [filtered, setQueue]);

  const recompute = useCallback(() => {
    const el = scrollRef.current;
    if (!el) return;
    const start = Math.max(0, Math.floor(el.scrollTop / ROW) - OVERSCAN);
    const end = Math.min(Math.ceil(filtered.length), Math.ceil((el.scrollTop + el.clientHeight) / ROW) + OVERSCAN);
    setRange((r) => (r.start === start && r.end === end ? r : { start, end }));
  }, [filtered.length]);

  useEffect(() => {
    recompute();
    const el = scrollRef.current;
    if (el) el.scrollTop = 0;
  }, [recompute]);

  // Centra el canal que esta sonando al abrir el rail.
  useEffect(() => {
    const el = scrollRef.current;
    if (!el || !nowPlaying) return;
    const i = filtered.findIndex((c) => c.id === nowPlaying.id);
    if (i > 0) {
      el.scrollTop = Math.max(0, i * ROW - el.clientHeight / 2);
      recompute();
    }
  }, [nowPlaying?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  const choose = (c: Channel) => { if (onPick) onPick(c); else play(c, filtered); };
  const slice = filtered.slice(range.start, range.end);

  return (
    <div className="flex h-full min-h-0 flex-col border-l border-bg-line bg-bg-surface/95">
      <div className="flex items-center gap-2 border-b border-bg-line px-3 py-3">
        <h3 className="flex-1 text-sm font-bold uppercase tracking-widest text-signal">{title}</h3>
        <span className="rounded-full bg-bg-raised px-2 py-0.5 text-[11px] font-semibold text-ink-muted">
          {filtered.length.toLocaleString()}
        </span>
        {onClose && (
          <button onClick={onClose} className="rounded-lg p-1.5 hover:bg-white/10" aria-label="Cerrar panel">
            <X className="h-4 w-4" />
          </button>
        )}
      </div>

      <div className="space-y-2 border-b border-bg-line px-3 py-2">
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-ink-dim" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Filtrar canales..."
            className="w-full rounded-lg border border-bg-line bg-bg-deep py-1.5 pl-8 pr-2 text-sm focus:border-signal focus:outline-none"
          />
        </div>
        <select
          value={activeGroup}
          onChange={(e) => setGroup(e.target.value)}
          className="w-full rounded-lg border border-bg-line bg-bg-deep px-2 py-1.5 text-xs focus:border-signal focus:outline-none"
        >
          <option value="Todas">Todas las categorias</option>
          {groups.map((g) => <option key={g} value={g}>{g}</option>)}
        </select>
      </div>

      <div ref={scrollRef} onScroll={recompute} className="min-h-0 flex-1 overflow-y-auto px-2 py-2">
        {filtered.length === 0 ? (
          <p className="py-8 text-center text-xs text-ink-dim">Sin resultados.</p>
        ) : (
          <div style={{ height: filtered.length * ROW, position: "relative" }}>
            <div style={{ position: "absolute", top: range.start * ROW, left: 0, right: 0 }}>
              {slice.map((c, i) => {
                const n = range.start + i;
                const on = nowPlaying?.id === c.id;
                const logo = imgUrl(c.logo);
                return (
                  <button
                    key={c.id}
                    data-focusable="true"
                    onClick={() => choose(c)}
                    style={{ height: ROW }}
                    className={clsx(
                      "flex w-full items-center gap-2.5 rounded-lg px-2 text-left",
                      on ? "bg-signal/15 ring-1 ring-signal/50" : "hover:bg-bg-raised"
                    )}
                  >
                    <span className="w-8 shrink-0 text-right font-mono text-[11px] text-ink-dim">{n + 1}</span>
                    <span className="h-9 w-9 shrink-0 overflow-hidden rounded-md bg-bg-deep ring-1 ring-white/5">
                      {logo ? (
                        <img src={logo} alt="" loading="lazy" className="h-full w-full object-contain p-0.5" />
                      ) : (
                        <span className="flex h-full w-full items-center justify-center text-[10px] font-bold text-ink-dim">
                          {c.name.slice(0, 2).toUpperCase()}
                        </span>
                      )}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className={clsx("block truncate text-[13px] font-semibold", on && "text-signal")}>{c.name}</span>
                      <span className="block truncate text-[11px] text-ink-dim">{c.group}</span>
                    </span>
                    {on && <span className="h-1.5 w-1.5 shrink-0 animate-live-dot rounded-full bg-brand" />}
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export const ChannelRail = memo(RailBase);
'@

# ============================================================ src/components/Player.tsx
Write-ProjectFile 'src/components/Player.tsx' @'
import { useEffect, useRef, useState } from "react";
import {
  Play, Pause, Volume2, VolumeX, Maximize, Minimize, SkipBack, SkipForward,
  X, Loader2, AlertTriangle, ChevronLeft, ChevronRight, Subtitles,
  PanelRightClose, PanelRightOpen, RotateCcw, PictureInPicture2, Gauge,
} from "lucide-react";
import { clsx } from "clsx";
import { usePlayer } from "../hooks/usePlayer";
import { SubtitleDialog } from "./SubtitleDialog";
import { useStore } from "../store";
import type { Channel } from "../types";

export type PlayerMode = "mini" | "theater" | "full" | "cell";

interface Props {
  channel: Channel;
  mode: PlayerMode;
  onClose: () => void;
  onMode?: (m: "mini" | "theater" | "full") => void;
  onPrev?: () => void;
  onNext?: () => void;
  onJump?: (index: number) => void;
  position?: { index: number; total: number };
  silent?: boolean;
  railOpen?: boolean;
  onToggleRail?: () => void;
  onActivate?: () => void;
  active?: boolean;
}

const fmt = (s: number) => {
  if (!isFinite(s) || s < 0) return "0:00";
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = Math.floor(s % 60).toString().padStart(2, "0");
  return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
};

const selCls =
  "rounded-md border border-bg-line bg-bg-deep px-2 py-1 text-xs text-ink focus:border-signal focus:outline-none";

function Knob({
  label, value, min, max, step = 1, unit = "%", onChange,
}: { label: string; value: number; min: number; max: number; step?: number; unit?: string; onChange: (v: number) => void }) {
  return (
    <label className="flex min-w-[124px] flex-1 flex-col gap-1">
      <span className="flex items-baseline justify-between text-[10px] uppercase tracking-wider text-ink-dim">
        {label}
        <span className="font-mono text-signal">{value}{unit}</span>
      </span>
      <input
        type="range" className="sb-range w-full" min={min} max={max} step={step} value={value}
        onChange={(e) => onChange(parseFloat(e.target.value))} aria-label={label}
      />
    </label>
  );
}

export function Player({
  channel, mode, onClose, onMode, onPrev, onNext, onJump, position,
  silent, railOpen, onToggleRail, onActivate, active = true,
}: Props) {
  const { videoRef, state, actions } = usePlayer(channel);
  const video = useStore((s) => s.video);
  const setVideo = useStore((s) => s.setVideo);
  const resetVideo = useStore((s) => s.resetVideo);

  const boxRef = useRef<HTMLDivElement | null>(null);
  const hideTimer = useRef<number | null>(null);
  const numBuf = useRef("");
  const numTimer = useRef<number | null>(null);

  const [fs, setFs] = useState(false);
  const [controls, setControls] = useState(true);
  const [subs, setSubs] = useState(false);
  const [osd, setOsd] = useState<string | null>(null);

  const flash = (t: string) => {
    setOsd(t);
    window.setTimeout(() => setOsd((v) => (v === t ? null : v)), 1100);
  };

  const compact = mode === "mini" || mode === "cell";
  const showBar = mode === "theater" || mode === "full" ? controls || !state.isPlaying : true;

  useEffect(() => {
    if (mode === "theater" || compact) return;
    if (!controls) return;
    hideTimer.current = window.setTimeout(() => { if (state.isPlaying) setControls(false); }, 3200);
    return () => { if (hideTimer.current) window.clearTimeout(hideTimer.current); };
  }, [controls, state.isPlaying, mode, compact]);

  useEffect(() => {
    const onFs = () => setFs(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", onFs);
    return () => document.removeEventListener("fullscreenchange", onFs);
  }, []);

  useEffect(() => { boxRef.current?.focus({ preventScroll: true }); }, [channel.id, mode]);

  // Celdas de multivision: solo suena la activa.
  useEffect(() => {
    if (mode !== "cell") return;
    actions.setMuted(!active);
    if (!active) actions.setVolume(0);
    else actions.setVolume(1);
  }, [active, mode, channel.id]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (silent) actions.setMuted(true);
  }, [silent, channel.id]); // eslint-disable-line react-hooks/exhaustive-deps

  const toggleFs = async () => {
    const el = boxRef.current;
    const v = videoRef.current as (HTMLVideoElement & { webkitEnterFullscreen?: () => void }) | null;
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else if (el?.requestFullscreen) { await el.requestFullscreen(); el.focus({ preventScroll: true }); }
      else v?.webkitEnterFullscreen?.();
    } catch {}
  };

  const onKey = (e: React.KeyboardEvent) => {
    if (e.target !== e.currentTarget) return;
    setControls(true);
    if (/^[0-9]$/.test(e.key) && onJump && position && position.total > 1) {
      e.preventDefault();
      numBuf.current = (numBuf.current + e.key).slice(-4);
      flash(`Canal ${numBuf.current}`);
      if (numTimer.current) window.clearTimeout(numTimer.current);
      numTimer.current = window.setTimeout(() => {
        const n = parseInt(numBuf.current, 10);
        numBuf.current = "";
        if (!isNaN(n)) onJump(n - 1);
      }, 850);
      return;
    }
    switch (e.key) {
      case " ": case "k": case "Enter":
        e.preventDefault(); e.stopPropagation(); actions.playPause(); break;
      case "ArrowRight":
        e.preventDefault(); e.stopPropagation(); actions.seek(state.currentTime + 10); flash("+10 s"); break;
      case "ArrowLeft":
        e.preventDefault(); e.stopPropagation(); actions.seek(state.currentTime - 10); flash("-10 s"); break;
      case "ArrowUp":
        e.preventDefault(); e.stopPropagation();
        if (e.shiftKey) onNext?.();
        else { actions.setVolume(Math.min(1, state.volume + 0.1)); actions.setMuted(false); flash(`Volumen ${Math.round(Math.min(1, state.volume + 0.1) * 100)}%`); }
        break;
      case "ArrowDown":
        e.preventDefault(); e.stopPropagation();
        if (e.shiftKey) onPrev?.();
        else { actions.setVolume(Math.max(0, state.volume - 0.1)); flash(`Volumen ${Math.round(Math.max(0, state.volume - 0.1) * 100)}%`); }
        break;
      case "PageUp": e.preventDefault(); e.stopPropagation(); onNext?.(); break;
      case "PageDown": e.preventDefault(); e.stopPropagation(); onPrev?.(); break;
      case "m": actions.setMuted(!state.muted); flash(state.muted ? "Sonido activado" : "Silenciado"); break;
      case "f": toggleFs(); break;
      case "p": actions.requestPiP(); break;
      case "Escape":
        e.stopPropagation();
        if (document.fullscreenElement) break;
        if (mode === "full") onMode?.("theater");
        else if (mode === "theater") onMode?.("mini");
        else onClose();
        break;
    }
  };

  const filter = `brightness(${video.brightness}%) contrast(${video.contrast}%) saturate(${video.saturate}%)`;
  const pct = state.duration > 0 ? (state.currentTime / state.duration) * 100 : 0;

  return (
    <div
      ref={boxRef}
      tabIndex={-1}
      data-nav-scope="player"
      onKeyDown={onKey}
      onMouseMove={() => setControls(true)}
      onTouchStart={() => { setControls(true); onActivate?.(); }}
      onClick={() => { boxRef.current?.focus({ preventScroll: true }); setControls(true); onActivate?.(); }}
      className={clsx(
        "relative flex min-h-0 flex-col bg-black outline-none",
        mode === "mini" && "h-full w-full overflow-hidden rounded-xl",
        mode === "cell" && "h-full w-full overflow-hidden rounded-lg",
        (mode === "theater" || mode === "full") && "h-full w-full",
        mode === "cell" && active && "ring-2 ring-signal"
      )}
    >
      <div className="relative min-h-0 flex-1 overflow-hidden bg-black">
        <video
          ref={videoRef}
          className="h-full w-full bg-black"
          style={{
            objectFit: video.aspect,
            filter,
            transform: video.zoom !== 100 ? `scale(${video.zoom / 100})` : undefined,
          }}
          playsInline
          autoPlay
          onDoubleClick={toggleFs}
        />

        {subs && !compact && (
          <SubtitleDialog channel={channel} state={state} actions={actions} onClose={() => setSubs(false)} />
        )}

        {state.loading && !state.error && (
          <div className="pointer-events-none absolute inset-0 flex items-center justify-center bg-black/45">
            <Loader2 className={clsx("animate-spin text-signal", compact ? "h-7 w-7" : "h-12 w-12")} />
          </div>
        )}

        {state.error && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-black/85 p-4 text-center">
            <AlertTriangle className={clsx("text-brand", compact ? "h-6 w-6" : "h-9 w-9")} />
            {!compact && <p className="max-w-md text-sm text-ink">{state.error}</p>}
            <div className="flex gap-2">
              <button onClick={actions.retry} className="rounded-lg bg-brand px-3 py-1.5 text-xs font-semibold text-white hover:bg-brand-hover">
                Reintentar
              </button>
              <button onClick={onClose} className="rounded-lg bg-bg-raised px-3 py-1.5 text-xs text-ink hover:bg-bg-line">
                Cerrar
              </button>
            </div>
          </div>
        )}

        {osd && (
          <div className="pointer-events-none absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 animate-pop-in rounded-xl bg-black/80 px-4 py-2 text-base font-bold">
            {osd}
          </div>
        )}

        {/* Cabecera */}
        <div className={clsx(
          "absolute inset-x-0 top-0 flex items-center gap-2 bg-gradient-to-b from-black/80 to-transparent p-2 transition-opacity",
          showBar ? "opacity-100" : "pointer-events-none opacity-0"
        )}>
          {position && position.total > 1 && (
            <span className="rounded-md bg-black/60 px-1.5 py-0.5 font-mono text-[11px] text-signal">
              {position.index + 1}/{position.total}
            </span>
          )}
          <div className="min-w-0 flex-1">
            <p className={clsx("truncate font-semibold", compact ? "text-xs" : "text-sm")}>{channel.name}</p>
            {!compact && channel.group && <p className="truncate text-[11px] text-ink-muted">{channel.group}</p>}
          </div>
          {!compact && state.duration === 0 && (
            <span className="flex items-center gap-1 rounded-full bg-brand/20 px-2 py-0.5 text-[10px] font-bold text-brand">
              <span className="h-1.5 w-1.5 animate-live-dot rounded-full bg-brand" /> EN VIVO
            </span>
          )}
          {mode === "theater" && onToggleRail && (
            <button onClick={onToggleRail} className="rounded-lg p-1.5 hover:bg-white/10" aria-label="Mostrar u ocultar canales">
              {railOpen ? <PanelRightClose className="h-4 w-4" /> : <PanelRightOpen className="h-4 w-4" />}
            </button>
          )}
          {onMode && mode !== "cell" && (
            <button
              onClick={() => onMode(mode === "mini" ? "theater" : mode === "theater" ? "full" : "theater")}
              className="rounded-lg p-1.5 hover:bg-white/10"
              aria-label="Cambiar modo de vista"
              title={mode === "mini" ? "Modo teatro" : mode === "theater" ? "Pantalla completa" : "Volver a teatro"}
            >
              {mode === "full" ? <Minimize className="h-4 w-4" /> : <Maximize className="h-4 w-4" />}
            </button>
          )}
          <button onClick={onClose} className="rounded-lg p-1.5 hover:bg-white/10" aria-label="Cerrar reproductor">
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* Controles flotantes inferiores (mini / full / cell) */}
        {mode !== "theater" && (
          <div className={clsx(
            "absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/85 to-transparent p-2 transition-opacity",
            showBar ? "opacity-100" : "pointer-events-none opacity-0"
          )}>
            {state.duration > 0 && (
              <div className="mb-1.5 h-1 w-full overflow-hidden rounded-full bg-white/20">
                <div className="h-full rounded-full bg-signal" style={{ width: `${pct}%` }} />
              </div>
            )}
            <div className="flex items-center gap-1">
              {onPrev && position && position.total > 1 && (
                <button onClick={onPrev} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Canal anterior">
                  <ChevronLeft className="h-4 w-4" />
                </button>
              )}
              <button onClick={actions.playPause} className="rounded-full bg-white/10 p-1.5 hover:bg-white/20" aria-label="Reproducir o pausar">
                {state.isPlaying ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4" fill="currentColor" />}
              </button>
              {onNext && position && position.total > 1 && (
                <button onClick={onNext} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Canal siguiente">
                  <ChevronRight className="h-4 w-4" />
                </button>
              )}
              <button onClick={() => actions.setMuted(!state.muted)} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Silenciar">
                {state.muted || state.volume === 0 ? <VolumeX className="h-4 w-4" /> : <Volume2 className="h-4 w-4" />}
              </button>
              {!compact && state.duration > 0 && (
                <>
                  <button onClick={() => actions.seek(state.currentTime - 10)} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Atrasar 10 segundos">
                    <SkipBack className="h-4 w-4" />
                  </button>
                  <button onClick={() => actions.seek(state.currentTime + 10)} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Adelantar 10 segundos">
                    <SkipForward className="h-4 w-4" />
                  </button>
                  <span className="ml-1 text-[11px] text-ink-muted">{fmt(state.currentTime)} / {fmt(state.duration)}</span>
                </>
              )}
              <div className="flex-1" />
              {!compact && (
                <button onClick={toggleFs} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Pantalla completa">
                  {fs ? <Minimize className="h-4 w-4" /> : <Maximize className="h-4 w-4" />}
                </button>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Barra de control permanente del modo teatro */}
      {mode === "theater" && (
        <div className="shrink-0 space-y-2 border-t border-bg-line bg-bg-surface px-3 py-2.5">
          <div className="flex items-center gap-2">
            {onPrev && position && position.total > 1 && (
              <button onClick={onPrev} className="rounded-lg p-2 hover:bg-bg-raised" aria-label="Canal anterior"><ChevronLeft className="h-4 w-4" /></button>
            )}
            <button onClick={actions.playPause} className="rounded-lg bg-signal/20 p-2 text-signal hover:bg-signal/30" aria-label="Reproducir o pausar">
              {state.isPlaying ? <Pause className="h-5 w-5" /> : <Play className="h-5 w-5" fill="currentColor" />}
            </button>
            {onNext && position && position.total > 1 && (
              <button onClick={onNext} className="rounded-lg p-2 hover:bg-bg-raised" aria-label="Canal siguiente"><ChevronRight className="h-4 w-4" /></button>
            )}
            <button onClick={() => actions.setMuted(!state.muted)} className="rounded-lg p-2 hover:bg-bg-raised" aria-label="Silenciar">
              {state.muted || state.volume === 0 ? <VolumeX className="h-4 w-4" /> : <Volume2 className="h-4 w-4" />}
            </button>
            <input
              type="range" className="sb-range w-24" min={0} max={1} step={0.05}
              value={state.muted ? 0 : state.volume}
              onChange={(e) => { actions.setMuted(false); actions.setVolume(parseFloat(e.target.value)); }}
              aria-label="Volumen"
            />
            {state.duration > 0 ? (
              <span className="ml-1 hidden font-mono text-[11px] text-ink-muted sm:inline">
                {fmt(state.currentTime)} / {fmt(state.duration)}
              </span>
            ) : (
              <span className="ml-1 flex items-center gap-1 text-[11px] font-bold text-brand">
                <span className="h-1.5 w-1.5 animate-live-dot rounded-full bg-brand" /> EN VIVO
              </span>
            )}
            <div className="flex-1" />
            <button onClick={() => setSubs(true)} className="flex items-center gap-1.5 rounded-lg border border-bg-line px-2.5 py-1.5 text-xs hover:bg-bg-raised">
              <Subtitles className="h-4 w-4" /> Subtitulos
            </button>
            <button onClick={actions.requestPiP} className="rounded-lg border border-bg-line p-1.5 hover:bg-bg-raised" aria-label="Picture in Picture" title="Picture-in-Picture">
              <PictureInPicture2 className="h-4 w-4" />
            </button>
            <button onClick={toggleFs} className="rounded-lg border border-bg-line p-1.5 hover:bg-bg-raised" aria-label="Pantalla completa">
              {fs ? <Minimize className="h-4 w-4" /> : <Maximize className="h-4 w-4" />}
            </button>
          </div>

          {state.duration > 0 && (
            <input
              type="range" className="sb-range w-full" min={0} max={state.duration} step={0.1}
              value={state.currentTime} onChange={(e) => actions.seek(parseFloat(e.target.value))}
              aria-label="Posicion de reproduccion"
            />
          )}

          <div className="flex flex-wrap items-end gap-x-4 gap-y-2">
            <Knob label="Brillo" value={video.brightness} min={50} max={160} onChange={(v) => setVideo({ brightness: v })} />
            <Knob label="Contraste" value={video.contrast} min={50} max={160} onChange={(v) => setVideo({ contrast: v })} />
            <Knob label="Saturacion" value={video.saturate} min={0} max={200} onChange={(v) => setVideo({ saturate: v })} />
            <Knob label="Zoom" value={video.zoom} min={100} max={160} onChange={(v) => setVideo({ zoom: v })} />

            <label className="flex flex-col gap-1">
              <span className="text-[10px] uppercase tracking-wider text-ink-dim">Encuadre</span>
              <select className={selCls} value={video.aspect} onChange={(e) => setVideo({ aspect: e.target.value as "contain" | "cover" | "fill" })}>
                <option value="contain">Completo</option>
                <option value="cover">Recortar</option>
                <option value="fill">Estirar</option>
              </select>
            </label>

            <label className="flex flex-col gap-1">
              <span className="flex items-center gap-1 text-[10px] uppercase tracking-wider text-ink-dim"><Gauge className="h-3 w-3" /> Velocidad</span>
              <select className={selCls} value={state.playbackRate} onChange={(e) => actions.setPlaybackRate(parseFloat(e.target.value))}>
                {[0.5, 0.75, 1, 1.25, 1.5, 2].map((r) => <option key={r} value={r}>{r}x</option>)}
              </select>
            </label>

            {state.audioTracks.length > 1 && (
              <label className="flex flex-col gap-1">
                <span className="text-[10px] uppercase tracking-wider text-ink-dim">Audio</span>
                <select className={selCls} value={state.activeAudio} onChange={(e) => actions.setAudioTrack(parseInt(e.target.value, 10))}>
                  {state.audioTracks.map((t) => <option key={t.id} value={t.id}>{t.label}</option>)}
                </select>
              </label>
            )}

            {state.subtitleTracks.length > 0 && (
              <label className="flex flex-col gap-1">
                <span className="text-[10px] uppercase tracking-wider text-ink-dim">Sub. stream</span>
                <select className={selCls} value={state.activeSubtitle} onChange={(e) => actions.setSubtitleTrack(parseInt(e.target.value, 10))}>
                  <option value={-1}>Off</option>
                  {state.subtitleTracks.map((t) => <option key={t.id} value={t.id}>{t.label}</option>)}
                </select>
              </label>
            )}

            <button onClick={resetVideo} className="flex items-center gap-1.5 rounded-lg border border-bg-line px-2.5 py-1.5 text-xs hover:bg-bg-raised">
              <RotateCcw className="h-3.5 w-3.5" /> Reset imagen
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
'@

# ========================================================= src/components/Multiview.tsx
Write-ProjectFile 'src/components/Multiview.tsx' @'
import { useEffect, useState } from "react";
import { X, LayoutGrid, Volume2 } from "lucide-react";
import { clsx } from "clsx";
import { Player } from "./Player";
import { ChannelRail } from "./ChannelRail";
import { useStore } from "../store";

export function Multiview() {
  const multiview = useStore((s) => s.multiview);
  const mvActive = useStore((s) => s.mvActive);
  const setMvActive = useStore((s) => s.setMvActive);
  const removeMultiview = useStore((s) => s.removeMultiview);
  const clearMultiview = useStore((s) => s.clearMultiview);
  const addMultiview = useStore((s) => s.addMultiview);
  const [rail, setRail] = useState(true);

  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = prev; };
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") clearMultiview(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [clearMultiview]);

  const cells = [...multiview];
  const slots = Math.max(2, Math.min(4, cells.length + (cells.length < 4 ? 1 : 0)));
  const cols = slots <= 2 ? 1 : 2;

  return (
    <div data-nav-lock="multiview" className="fixed inset-0 z-[70] flex animate-fade-in bg-bg-deep">
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center gap-3 border-b border-bg-line px-4 py-3">
          <LayoutGrid className="h-5 w-5 text-signal" />
          <h2 className="text-sm font-bold uppercase tracking-widest">Multivision</h2>
          <span className="rounded-full bg-bg-raised px-2 py-0.5 text-[11px] text-ink-muted">{cells.length}/4</span>
          <p className="hidden text-xs text-ink-dim md:block">Solo suena la celda resaltada. Pulsa una celda para cambiar el audio.</p>
          <div className="flex-1" />
          <button onClick={() => setRail((v) => !v)} className="rounded-lg border border-bg-line px-3 py-1.5 text-xs hover:bg-bg-raised">
            {rail ? "Ocultar canales" : "Anadir canales"}
          </button>
          <button onClick={clearMultiview} className="flex items-center gap-1.5 rounded-lg bg-brand px-3 py-1.5 text-xs font-semibold text-white hover:bg-brand-hover">
            <X className="h-4 w-4" /> Salir
          </button>
        </header>

        <div
          className="grid min-h-0 flex-1 gap-2 p-2"
          style={{ gridTemplateColumns: `repeat(${cols}, minmax(0,1fr))`, gridAutoRows: "minmax(0,1fr)" }}
        >
          {cells.map((c, i) => (
            <div key={c.id} className="relative min-h-0">
              <Player
                channel={c}
                mode="cell"
                active={i === mvActive}
                onActivate={() => setMvActive(i)}
                onClose={() => removeMultiview(i)}
              />
              {i === mvActive && (
                <span className="pointer-events-none absolute bottom-2 left-2 flex items-center gap-1 rounded-full bg-signal/25 px-2 py-0.5 text-[10px] font-bold text-signal">
                  <Volume2 className="h-3 w-3" /> AUDIO
                </span>
              )}
            </div>
          ))}
          {cells.length < 4 && (
            <button
              onClick={() => setRail(true)}
              className={clsx(
                "flex min-h-[140px] flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed",
                "border-bg-line text-ink-dim hover:border-signal/60 hover:text-signal"
              )}
            >
              <LayoutGrid className="h-7 w-7" />
              <span className="text-sm font-semibold">Anadir canal</span>
              <span className="text-xs">Elige uno en el panel de la derecha</span>
            </button>
          )}
        </div>
      </div>

      {rail && (
        <aside className="hidden w-[320px] shrink-0 md:block">
          <ChannelRail title="Anadir a multivision" onPick={(c) => addMultiview(c)} onClose={() => setRail(false)} />
        </aside>
      )}
    </div>
  );
}
'@

# ========================================================= src/components/PlayerDock.tsx
Write-ProjectFile 'src/components/PlayerDock.tsx' @'
import { useEffect, useRef, useState } from "react";
import { clsx } from "clsx";
import { Player } from "./Player";
import { ChannelRail } from "./ChannelRail";
import { Multiview } from "./Multiview";
import { useStore } from "../store";

const SIZES = { s: 260, m: 360, l: 480 } as const;
const MARGIN = 16;

/**
 * El reproductor vive aqui, fuera del flujo del documento.
 * Nada de lo que se reproduce empuja o desplaza la lista de fondo.
 */
export function PlayerDock() {
  const nowPlaying = useStore((s) => s.nowPlaying);
  const setNowPlaying = useStore((s) => s.setNowPlaying);
  const viewMode = useStore((s) => s.viewMode);
  const setViewMode = useStore((s) => s.setViewMode);
  const mini = useStore((s) => s.mini);
  const queue = useStore((s) => s.queue);
  const zap = useStore((s) => s.zap);
  const zapTo = useStore((s) => s.zapTo);
  const multiview = useStore((s) => s.multiview);

  const [rail, setRail] = useState(true);
  const [drag, setDrag] = useState<{ x: number; y: number } | null>(null);
  const dragRef = useRef<{ dx: number; dy: number } | null>(null);

  const overlay = viewMode === "theater" || viewMode === "full";

  // Bloquea el scroll de fondo en teatro sin perder la posicion.
  useEffect(() => {
    if (!overlay) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = prev; };
  }, [overlay]);

  useEffect(() => { if (!overlay) setDrag(null); }, [overlay]);

  useEffect(() => {
    if (viewMode !== "full") return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape" && !document.fullscreenElement) setViewMode("theater"); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [viewMode, setViewMode]);

  if (multiview.length > 0) return <Multiview />;
  if (!nowPlaying) return null;

  const index = queue.findIndex((c) => c.id === nowPlaying.id);
  const canZap = index >= 0 && queue.length > 1;
  const close = () => { setNowPlaying(null); setViewMode("mini"); };

  const player = (
    <Player
      channel={nowPlaying}
      mode={viewMode}
      onClose={close}
      onMode={setViewMode}
      onPrev={canZap ? () => zap(-1) : undefined}
      onNext={canZap ? () => zap(1) : undefined}
      onJump={canZap ? (i) => zapTo(i) : undefined}
      position={canZap ? { index, total: queue.length } : undefined}
      railOpen={rail}
      onToggleRail={() => setRail((v) => !v)}
    />
  );

  if (overlay) {
    return (
      <div data-nav-lock="player-overlay" className="fixed inset-0 z-[60] flex animate-fade-in bg-bg-deep">
        <div className="min-w-0 flex-1">{player}</div>
        {viewMode === "theater" && rail && (
          <aside className="hidden w-[330px] shrink-0 lg:block">
            <ChannelRail onClose={() => setRail(false)} />
          </aside>
        )}
      </div>
    );
  }

  // ---- Mini flotante ----
  const w = SIZES[mini.size];
  const h = Math.round((w * 9) / 16);
  const pos = drag
    ? { left: drag.x, top: drag.y }
    : {
        left: mini.corner === "tl" || mini.corner === "bl" ? MARGIN : undefined,
        right: mini.corner === "tr" || mini.corner === "br" ? MARGIN : undefined,
        top: mini.corner === "tl" || mini.corner === "tr" ? 76 : undefined,
        bottom: mini.corner === "bl" || mini.corner === "br" ? MARGIN + 56 : undefined,
      };

  const onPointerDown = (e: React.PointerEvent) => {
    const el = e.currentTarget.parentElement as HTMLElement;
    const r = el.getBoundingClientRect();
    dragRef.current = { dx: e.clientX - r.left, dy: e.clientY - r.top };
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    setDrag({ x: r.left, y: r.top });
  };
  const onPointerMove = (e: React.PointerEvent) => {
    if (!dragRef.current) return;
    const maxX = window.innerWidth - w - 8;
    const maxY = window.innerHeight - h - 8;
    setDrag({
      x: Math.max(8, Math.min(maxX, e.clientX - dragRef.current.dx)),
      y: Math.max(8, Math.min(maxY, e.clientY - dragRef.current.dy)),
    });
  };
  const onPointerUp = (e: React.PointerEvent) => {
    dragRef.current = null;
    try { (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId); } catch {}
  };

  return (
    <div
      style={{ ...pos, width: w, height: h, opacity: mini.opacity / 100 }}
      className={clsx(
        "fixed z-50 animate-pop-in overflow-hidden rounded-xl shadow-dock transition-opacity hover:!opacity-100",
        "ring-1 ring-bg-line"
      )}
    >
      <div
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        className="absolute inset-x-0 top-0 z-10 h-6 cursor-grab active:cursor-grabbing"
        title="Arrastra para mover el reproductor"
      />
      {player}
    </div>
  );
}
'@

# ======================================================= src/components/ViewSettings.tsx
Write-ProjectFile 'src/components/ViewSettings.tsx' @'
import { useMemo } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { X, RotateCcw, SlidersHorizontal } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { ACCENTS, useStore, type Accent, type Density, type MiniSize, type Corner } from "../store";

const chip = (on: boolean) =>
  clsx(
    "rounded-lg px-2.5 py-1.5 text-xs font-semibold border transition-colors",
    on ? "border-signal bg-signal/15 text-signal" : "border-bg-line bg-bg-deep text-ink-muted hover:bg-bg-raised"
  );

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1.5">
      <p className="text-[10px] font-bold uppercase tracking-widest text-ink-dim">{label}</p>
      {children}
    </div>
  );
}

export function ViewSettings() {
  const open = useStore((s) => s.settingsOpen);
  const setOpen = useStore((s) => s.setSettingsOpen);
  const ui = useStore((s) => s.ui);
  const setUI = useStore((s) => s.setUI);
  const toggleGroup = useStore((s) => s.toggleGroup);
  const resetUI = useStore((s) => s.resetUI);
  const mini = useStore((s) => s.mini);
  const setMini = useStore((s) => s.setMini);
  const activePlaylistId = useStore((s) => s.activePlaylistId);

  const groups = useLiveQuery(async () => {
    if (!activePlaylistId) return [] as string[];
    const rows = await db.channels.where("playlistId").equals(activePlaylistId).toArray();
    return Array.from(new Set(rows.map((c) => c.group || "Sin categoria"))).sort((a, b) => a.localeCompare(b));
  }, [activePlaylistId]);

  const visibleCount = useMemo(
    () => (groups ?? []).filter((g) => !ui.hiddenGroups.includes(g)).length,
    [groups, ui.hiddenGroups]
  );

  if (!open) return null;

  return (
    <>
      <div className="fixed inset-0 z-[55] bg-black/60 backdrop-blur-sm" onClick={() => setOpen(false)} />
      <aside
        data-nav-lock="settings"
        className="fixed right-0 top-0 z-[56] flex h-full w-[330px] max-w-[92vw] animate-slide-up flex-col border-l border-bg-line bg-bg-surface"
      >
        <header className="flex items-center gap-2 border-b border-bg-line px-4 py-3">
          <SlidersHorizontal className="h-4 w-4 text-signal" />
          <h2 className="flex-1 text-sm font-bold uppercase tracking-widest">Interfaz</h2>
          <button onClick={resetUI} className="rounded-lg border border-bg-line p-1.5 hover:bg-bg-raised" title="Restablecer" aria-label="Restablecer ajustes de interfaz">
            <RotateCcw className="h-4 w-4" />
          </button>
          <button onClick={() => setOpen(false)} className="rounded-lg p-1.5 hover:bg-bg-raised" aria-label="Cerrar">
            <X className="h-4 w-4" />
          </button>
        </header>

        <div className="min-h-0 flex-1 space-y-5 overflow-y-auto p-4">
          <Row label={`Escala de la interfaz · ${Math.round(ui.scale * 100)}%`}>
            <input type="range" className="sb-range w-full" min={0.85} max={1.3} step={0.05}
              value={ui.scale} onChange={(e) => setUI({ scale: parseFloat(e.target.value) })} aria-label="Escala de la interfaz" />
          </Row>

          <Row label="Densidad de lista">
            <div className="flex gap-1.5">
              {(["compact", "normal", "comfy"] as Density[]).map((d) => (
                <button key={d} onClick={() => setUI({ density: d })} className={chip(ui.density === d)}>
                  {d === "compact" ? "Compacta" : d === "normal" ? "Normal" : "Amplia"}
                </button>
              ))}
            </div>
          </Row>

          <Row label="Columnas">
            <div className="flex gap-1.5">
              {([0, 1, 2, 3] as const).map((c) => (
                <button key={c} onClick={() => setUI({ columns: c })} className={chip(ui.columns === c)}>
                  {c === 0 ? "Auto" : c}
                </button>
              ))}
            </div>
          </Row>

          <Row label={`Tamano de poster · ${Math.round(ui.posterScale * 100)}%`}>
            <input type="range" className="sb-range w-full" min={0.75} max={1.6} step={0.05}
              value={ui.posterScale} onChange={(e) => setUI({ posterScale: parseFloat(e.target.value) })} aria-label="Tamano de poster" />
          </Row>

          <Row label="Color de acento">
            <div className="flex flex-wrap gap-1.5">
              {(Object.keys(ACCENTS) as Accent[]).map((a) => (
                <button
                  key={a}
                  onClick={() => setUI({ accent: a })}
                  className={clsx(
                    "flex items-center gap-1.5 rounded-lg border px-2 py-1.5 text-xs",
                    ui.accent === a ? "border-ink" : "border-bg-line hover:bg-bg-raised"
                  )}
                >
                  <span className="h-3 w-3 rounded-full" style={{ background: ACCENTS[a].hex }} />
                  {ACCENTS[a].label}
                </button>
              ))}
            </div>
          </Row>

          <div className="border-t border-bg-line pt-4">
            <p className="mb-3 text-[10px] font-bold uppercase tracking-widest text-signal">Reproductor flotante</p>
            <div className="space-y-4">
              <Row label="Tamano">
                <div className="flex gap-1.5">
                  {(["s", "m", "l"] as MiniSize[]).map((s) => (
                    <button key={s} onClick={() => setMini({ size: s })} className={chip(mini.size === s)}>
                      {s === "s" ? "Pequeno" : s === "m" ? "Mediano" : "Grande"}
                    </button>
                  ))}
                </div>
              </Row>
              <Row label="Esquina">
                <div className="grid grid-cols-2 gap-1.5">
                  {([["tl", "Arriba izq."], ["tr", "Arriba der."], ["bl", "Abajo izq."], ["br", "Abajo der."]] as [Corner, string][]).map(([c, label]) => (
                    <button key={c} onClick={() => setMini({ corner: c })} className={chip(mini.corner === c)}>{label}</button>
                  ))}
                </div>
              </Row>
              <Row label={`Opacidad en reposo · ${mini.opacity}%`}>
                <input type="range" className="sb-range w-full" min={35} max={100} step={5}
                  value={mini.opacity} onChange={(e) => setMini({ opacity: parseInt(e.target.value, 10) })} aria-label="Opacidad del reproductor" />
              </Row>
            </div>
          </div>

          <div className="border-t border-bg-line pt-4">
            <p className="mb-1 text-[10px] font-bold uppercase tracking-widest text-signal">
              Categorias visibles · {visibleCount}/{(groups ?? []).length}
            </p>
            <p className="mb-3 text-[11px] text-ink-dim">Desmarca lo que no quieras ver en listas ni en el rail.</p>
            <div className="space-y-1">
              {(groups ?? []).map((g) => {
                const on = !ui.hiddenGroups.includes(g);
                return (
                  <label key={g} className="flex cursor-pointer items-center gap-2 rounded-lg px-2 py-1.5 text-xs hover:bg-bg-raised">
                    <input type="checkbox" checked={on} onChange={() => toggleGroup(g)} className="h-3.5 w-3.5 accent-signal" />
                    <span className={clsx("truncate", !on && "text-ink-dim line-through")}>{g}</span>
                  </label>
                );
              })}
              {(groups ?? []).length === 0 && <p className="text-xs text-ink-dim">Carga una lista para ver categorias.</p>}
            </div>
          </div>
        </div>
      </aside>
    </>
  );
}
'@

# =========================================================== src/components/Sidebar.tsx
Write-ProjectFile 'src/components/Sidebar.tsx' @'
import { NavLink } from "react-router-dom";
import { Home, Tv, Film, Clapperboard, Star, Search, Settings, ListVideo, X } from "lucide-react";
import { clsx } from "clsx";
import { useStore } from "../store";

const items = [
  { to: "/", label: "Inicio", icon: Home },
  { to: "/live", label: "TV en vivo", icon: Tv },
  { to: "/movies", label: "Peliculas", icon: Film },
  { to: "/series", label: "Series", icon: Clapperboard },
  { to: "/favorites", label: "Favoritos", icon: Star },
  { to: "/search", label: "Buscar", icon: Search },
  { to: "/playlists", label: "Mis listas", icon: ListVideo },
  { to: "/settings", label: "Ajustes", icon: Settings },
];

export function Sidebar() {
  const sidebarOpen = useStore((s) => s.sidebarOpen);
  const setSidebarOpen = useStore((s) => s.setSidebarOpen);

  return (
    <>
      {sidebarOpen && (
        <div className="fixed inset-0 z-30 bg-black/70 backdrop-blur-sm lg:hidden" onClick={() => setSidebarOpen(false)} />
      )}
      <aside
        className={clsx(
          "fixed left-0 top-0 z-40 flex h-screen w-[220px] shrink-0 flex-col border-r border-bg-line",
          "bg-bg-surface/95 backdrop-blur-xl transition-transform duration-200",
          "lg:sticky lg:translate-x-0 lg:bg-bg-surface/60",
          sidebarOpen ? "translate-x-0" : "-translate-x-full"
        )}
      >
        <div className="flex items-center gap-2.5 border-b border-bg-line px-4 py-4">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-brand via-iris to-signal font-black shadow-glow">
            S
          </div>
          <div className="min-w-0 flex-1">
            <span className="block truncate text-base font-bold leading-none tracking-tight">StreamBox</span>
            <span className="text-[10px] uppercase tracking-[0.2em] text-ink-dim">IPTV Player</span>
          </div>
          <button onClick={() => setSidebarOpen(false)} className="rounded p-1 hover:bg-white/10 lg:hidden" aria-label="Cerrar menu">
            <X className="h-4 w-4" />
          </button>
        </div>

        <nav className="flex-1 space-y-1 overflow-y-auto p-2.5">
          {items.map((it) => (
            <NavLink
              key={it.to}
              to={it.to}
              end={it.to === "/"}
              data-focusable="true"
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                clsx(
                  "group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium",
                  isActive
                    ? "bg-gradient-to-r from-signal/20 to-transparent text-signal ring-1 ring-signal/30"
                    : "text-ink-muted hover:bg-bg-raised hover:text-ink"
                )
              }
            >
              <it.icon className="h-[18px] w-[18px]" />
              {it.label}
            </NavLink>
          ))}
        </nav>

        <div className="border-t border-bg-line p-3 text-[11px] leading-relaxed text-ink-dim">
          <p className="font-semibold text-ink-muted">Flechas para navegar</p>
          <p>Enter abre · Esc retrocede</p>
        </div>
      </aside>
    </>
  );
}
'@

# ============================================================ src/components/Layout.tsx
Write-ProjectFile 'src/components/Layout.tsx' @'
import { useEffect, useState } from "react";
import { Outlet, useNavigate } from "react-router-dom";
import { Menu, Search, SlidersHorizontal, LayoutGrid, Tv } from "lucide-react";
import { Sidebar } from "./Sidebar";
import { PlayerDock } from "./PlayerDock";
import { ViewSettings } from "./ViewSettings";
import { SeriesDetail } from "./SeriesDetail";
import { ACCENTS, useStore } from "../store";
import { useSpatialNav } from "../hooks/useSpatialNav";

function Clock() {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const t = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(t);
  }, []);
  return (
    <span className="hidden font-mono text-sm tabular-nums text-ink-muted md:inline">
      {now.toLocaleTimeString("es-ES", { hour: "2-digit", minute: "2-digit" })}
    </span>
  );
}

export function Layout() {
  const navigate = useNavigate();
  const toggleSidebar = useStore((s) => s.toggleSidebar);
  const setSettingsOpen = useStore((s) => s.setSettingsOpen);
  const settingsOpen = useStore((s) => s.settingsOpen);
  const openSeries = useStore((s) => s.openSeries);
  const ui = useStore((s) => s.ui);
  const multiview = useStore((s) => s.multiview);
  const nowPlaying = useStore((s) => s.nowPlaying);
  const setViewMode = useStore((s) => s.setViewMode);
  const addMultiview = useStore((s) => s.addMultiview);

  useSpatialNav(true);

  // Escala global real: afecta a toda la UI porque Tailwind trabaja en rem.
  useEffect(() => {
    document.documentElement.style.fontSize = `${16 * ui.scale}px`;
    return () => { document.documentElement.style.fontSize = ""; };
  }, [ui.scale]);

  // Acento vivo en variables CSS (foco, sliders, scrollbar).
  useEffect(() => {
    const a = ACCENTS[ui.accent];
    const r = document.documentElement.style;
    r.setProperty("--accent", a.hex);
    r.setProperty("--accent-soft", a.soft);
    r.setProperty("--accent-glow", `${a.hex}73`);
  }, [ui.accent]);

  return (
    <div className="relative min-h-screen">
      <div aria-hidden className="pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-bg">
        <div className="absolute -left-40 -top-40 h-[540px] w-[540px] animate-drift rounded-full bg-signal/12 blur-[140px]" />
        <div className="absolute -right-32 top-1/4 h-[460px] w-[460px] animate-drift rounded-full bg-iris/14 blur-[150px]" />
        <div className="absolute bottom-0 left-1/3 h-[420px] w-[420px] animate-drift rounded-full bg-brand/10 blur-[150px]" />
        <div className="grain absolute inset-0 opacity-[0.04] mix-blend-overlay" />
      </div>

      <div className="flex min-h-screen">
        <Sidebar />
        <div className="flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-30 flex items-center gap-2 border-b border-bg-line bg-bg/85 px-3 py-2.5 backdrop-blur-xl md:px-5">
            <button onClick={toggleSidebar} className="rounded-lg p-2 hover:bg-white/10 lg:hidden" aria-label="Abrir menu">
              <Menu className="h-5 w-5" />
            </button>

            <button
              onClick={() => navigate("/search")}
              data-focusable="true"
              className="flex min-w-0 flex-1 items-center gap-2 rounded-xl border border-bg-line bg-bg-surface px-3 py-2 text-left text-sm text-ink-dim hover:border-signal/50 md:max-w-md"
            >
              <Search className="h-4 w-4 shrink-0" />
              <span className="truncate">Buscar canales, peliculas, series...</span>
            </button>

            <div className="flex-1" />
            <Clock />

            {nowPlaying && (
              <button
                onClick={() => setViewMode("theater")}
                className="flex items-center gap-1.5 rounded-lg border border-signal/40 bg-signal/10 px-2.5 py-1.5 text-xs font-semibold text-signal hover:bg-signal/20"
                title="Abrir modo teatro"
              >
                <Tv className="h-4 w-4" />
                <span className="hidden sm:inline">Teatro</span>
              </button>
            )}

            <button
              onClick={() => { if (multiview.length === 0 && nowPlaying) addMultiview(nowPlaying); else setViewMode("theater"); }}
              className="flex items-center gap-1.5 rounded-lg border border-bg-line px-2.5 py-1.5 text-xs font-semibold hover:bg-bg-raised"
              title="Multivision (hasta 4 canales)"
            >
              <LayoutGrid className="h-4 w-4" />
              <span className="hidden sm:inline">Multivision</span>
              {multiview.length > 0 && <span className="rounded-full bg-signal/25 px-1.5 text-[10px] text-signal">{multiview.length}</span>}
            </button>

            <button
              onClick={() => setSettingsOpen(!settingsOpen)}
              className="rounded-lg border border-bg-line p-2 hover:bg-bg-raised"
              aria-label="Ajustes de interfaz"
              title="Ajustes de interfaz"
            >
              <SlidersHorizontal className="h-4 w-4" />
            </button>
          </header>

          <main className="mx-auto w-full max-w-[1600px] flex-1 p-4 pb-24 md:p-6 lg:p-8">
            <Outlet />
          </main>
        </div>
      </div>

      <PlayerDock />
      <ViewSettings />
      <div {...(openSeries ? { "data-nav-lock": "series" } : {})}>
        <SeriesDetail />
      </div>
    </div>
  );
}
'@

# ========================================================= src/pages/CategoryPage.tsx
Write-ProjectFile 'src/pages/CategoryPage.tsx' @'
import { useCallback, useDeferredValue, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useLiveQuery } from "dexie-react-hooks";
import { Search } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { ChannelGrid } from "../components/ChannelGrid";
import { ChannelCardSkeleton } from "../components/SkeletonLoader";
import type { Channel } from "../types";

interface Props {
  category: Channel["category"];
  title: string;
  placeholder: string;
  noun: string;
}

export function CategoryPage({ category, title, placeholder, noun }: Props) {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const play = useStore((s) => s.play);
  const hiddenGroups = useStore((s) => s.ui.hiddenGroups);
  const { favSet, toggle } = useFavorites();
  const [group, setGroup] = useState("Todas");
  const [query, setQuery] = useState("");
  const deferredQuery = useDeferredValue(query);

  const items = useLiveQuery(
    () =>
      activePlaylistId
        ? db.channels.where("[playlistId+category]").equals([activePlaylistId, category]).toArray()
        : Promise.resolve([] as Channel[]),
    [activePlaylistId, category]
  );

  const groups = useMemo(
    () =>
      Array.from(new Set((items ?? []).map((c) => c.group || "Sin categoria")))
        .filter((g) => !hiddenGroups.includes(g))
        .sort((a, b) => a.localeCompare(b)),
    [items, hiddenGroups]
  );
  const activeGroup = groups.includes(group) ? group : "Todas";

  const filtered = useMemo(() => {
    const q = deferredQuery.trim().toLowerCase();
    return (items ?? []).filter(
      (c) =>
        !hiddenGroups.includes(c.group || "Sin categoria") &&
        (activeGroup === "Todas" || (c.group || "Sin categoria") === activeGroup) &&
        (!q || c.name.toLowerCase().includes(q))
    );
  }, [items, activeGroup, deferredQuery, hiddenGroups]);

  const onPlay = useCallback((c: Channel) => play(c, filtered), [play, filtered]);

  if (!activePlaylistId) {
    return (
      <div className="py-20 text-center text-ink-muted">
        <p className="mb-2">No hay ninguna lista cargada.</p>
        <Link to="/playlists" className="text-signal hover:underline">Ir a Mis listas</Link>
      </div>
    );
  }

  return (
    <div className="animate-fade-in space-y-5">
      <div>
        <h1 className="text-2xl font-bold md:text-3xl">{title}</h1>
        <p className="mt-1 text-ink-muted">{items ? `${filtered.length.toLocaleString()} ${noun}` : "Cargando..."}</p>
      </div>

      <div className="flex flex-col gap-3 md:flex-row">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-dim" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={placeholder}
            className="w-full rounded-lg border border-bg-line bg-bg-surface py-2 pl-9 pr-3 focus:border-signal focus:outline-none"
          />
        </div>
        <select
          value={activeGroup}
          onChange={(e) => setGroup(e.target.value)}
          className="rounded-lg border border-bg-line bg-bg-surface px-3 py-2 focus:border-signal focus:outline-none"
        >
          <option value="Todas">Todas las categorias</option>
          {groups.map((g) => <option key={g} value={g}>{g}</option>)}
        </select>
      </div>

      {!items ? (
        <div className="grid gap-2 md:grid-cols-2">
          {Array.from({ length: 8 }).map((_, i) => <ChannelCardSkeleton key={i} />)}
        </div>
      ) : (
        <ChannelGrid
          channels={filtered}
          favSet={favSet}
          onToggleFavorite={toggle}
          onPlay={onPlay}
          emptyText={`No hay ${noun} con ese filtro.`}
        />
      )}
    </div>
  );
}
'@

# ================================================================ src/pages/Home.tsx
Write-ProjectFile 'src/pages/Home.tsx' @'
import { useMemo } from "react";
import { Link } from "react-router-dom";
import { useLiveQuery } from "dexie-react-hooks";
import { Tv, Film, ListVideo, Plus, Clapperboard, Star, Play } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { imgUrl } from "../services/proxy";
import type { Channel } from "../types";

export function Home() {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const play = useStore((s) => s.play);
  const posterScale = useStore((s) => s.ui.posterScale);
  const hiddenGroups = useStore((s) => s.ui.hiddenGroups);
  const playlists = useLiveQuery(() => db.playlists.toArray(), []);

  const data = useLiveQuery(async () => {
    if (!activePlaylistId) return null;
    const q = (cat: Channel["category"]) =>
      db.channels.where("[playlistId+category]").equals([activePlaylistId, cat]);
    const [live, movies, series, nLive, nMovies, nSeries] = await Promise.all([
      q("live").limit(24).toArray(),
      q("movies").limit(24).toArray(),
      q("series").limit(24).toArray(),
      q("live").count(),
      q("movies").count(),
      q("series").count(),
    ]);
    return { live, movies, series, nLive, nMovies, nSeries };
  }, [activePlaylistId]);

  const active = playlists?.find((p) => p.id === activePlaylistId);
  const heroLogo = useMemo(() => imgUrl(data?.live.find((c) => c.logo)?.logo), [data]);
  const vis = (list: Channel[]) => list.filter((c) => !hiddenGroups.includes(c.group || "Sin categoria"));

  if (playlists && playlists.length === 0) {
    return (
      <div className="flex animate-fade-in flex-col items-center justify-center py-24 text-center">
        <div className="mb-5 flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-brand via-iris to-signal shadow-glow">
          <ListVideo className="h-8 w-8" />
        </div>
        <h1 className="text-3xl font-bold md:text-4xl">Bienvenido a StreamBox</h1>
        <p className="mt-3 max-w-md text-ink-muted">
          Anade tu cuenta Xtream o una lista M3U. StreamBox no incluye contenido: tu traes el tuyo.
        </p>
        <Link to="/playlists" data-focusable="true"
          className="mt-6 flex items-center gap-2 rounded-lg bg-brand px-5 py-2.5 font-semibold hover:bg-brand-hover">
          <Plus className="h-4 w-4" /> Anadir mi primera lista
        </Link>
      </div>
    );
  }

  if (!data) return null;

  return (
    <div className="animate-fade-in space-y-9">
      <section className="relative overflow-hidden rounded-2xl border border-bg-line bg-bg-surface">
        {heroLogo && <img src={heroLogo} alt="" className="absolute inset-0 h-full w-full object-cover opacity-20 blur-[2px]" />}
        <div className="absolute inset-0 bg-gradient-to-r from-bg-deep via-bg-deep/85 to-transparent" />
        <div className="absolute -right-16 -top-16 h-64 w-64 rounded-full bg-signal/25 blur-[90px]" />
        <div className="relative flex min-h-[264px] flex-col justify-end p-6 md:p-10">
          <p className="text-xs font-semibold uppercase tracking-[0.22em] text-signal">{active?.name || "Lista activa"}</p>
          <h1 className="mt-2 text-3xl font-black leading-tight md:text-5xl">Tu IPTV, a un clic</h1>
          <div className="mt-3 flex flex-wrap gap-x-5 gap-y-1 text-sm text-ink-muted">
            <span><b className="text-ink">{data.nLive.toLocaleString()}</b> en vivo</span>
            <span><b className="text-gold">{data.nMovies.toLocaleString()}</b> peliculas</span>
            <span><b className="text-iris">{data.nSeries.toLocaleString()}</b> series</span>
          </div>
          <div className="mt-5 flex flex-wrap gap-2">
            <Link to="/live" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-brand px-4 py-2 font-semibold hover:bg-brand-hover">
              <Tv className="h-4 w-4" /> TV en vivo
            </Link>
            <Link to="/movies" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-white/10 px-4 py-2 font-semibold hover:bg-white/20">
              <Film className="h-4 w-4" /> Peliculas
            </Link>
            <Link to="/series" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-white/10 px-4 py-2 font-semibold hover:bg-white/20">
              <Clapperboard className="h-4 w-4" /> Series
            </Link>
            <Link to="/favorites" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-white/10 px-4 py-2 font-semibold hover:bg-white/20">
              <Star className="h-4 w-4" /> Favoritos
            </Link>
          </div>
        </div>
      </section>

      <Row title="Canales en vivo" accent="text-brand" items={vis(data.live)} onPlay={play} scale={posterScale} />
      <Row title="Peliculas" accent="text-gold" items={vis(data.movies)} onPlay={play} scale={posterScale} />
      <Row title="Series" accent="text-iris" items={vis(data.series)} onPlay={play} scale={posterScale} />
    </div>
  );
}

function Row({
  title, accent, items, onPlay, scale,
}: {
  title: string; accent: string; items: Channel[];
  onPlay: (c: Channel, list?: Channel[]) => void; scale: number;
}) {
  if (items.length === 0) return null;
  const w = Math.round(176 * scale);
  return (
    <section>
      <div className="mb-3 flex items-baseline gap-3">
        <h2 className="text-xl font-bold">{title}</h2>
        <span className={`text-xs font-semibold uppercase tracking-widest ${accent}`}>{items.length} destacados</span>
      </div>
      <div className="no-scrollbar -mx-1 flex snap-x gap-3 overflow-x-auto px-1 pb-2">
        {items.map((c) => (
          <button
            key={c.id}
            data-focusable="true"
            onClick={() => onPlay(c, items)}
            title={c.name}
            style={{ width: w }}
            className="group shrink-0 snap-start rounded-xl text-left"
          >
            <div className="relative aspect-video overflow-hidden rounded-xl border border-bg-line bg-bg-surface transition-colors group-hover:border-signal/60">
              {c.logo ? (
                <img src={imgUrl(c.logo)} alt="" loading="lazy" className="h-full w-full object-contain p-3" />
              ) : (
                <div className="flex h-full w-full items-center justify-center p-2 text-center text-xs text-ink-muted">
                  {c.name.slice(0, 30)}
                </div>
              )}
              <span className="absolute inset-0 flex items-center justify-center bg-black/55 opacity-0 transition-opacity group-hover:opacity-100">
                <Play className="h-8 w-8 text-white" fill="currentColor" />
              </span>
            </div>
            <p className="mt-2 truncate text-sm font-medium">{c.name}</p>
            <p className="truncate text-xs text-ink-dim">{c.group}</p>
          </button>
        ))}
      </div>
    </section>
  );
}
'@

Write-Host ""
Write-Host "Listo. Reinicia: Ctrl+C y luego  npm start" -ForegroundColor Green
Write-Host ""
Write-Host "Que cambia:" -ForegroundColor Cyan
Write-Host "  * El reproductor ya NO empuja la lista: vive en una capa fija aparte."
Write-Host "  * Mini flotante arrastrable (3 tamanos, 4 esquinas, opacidad adjustable)."
Write-Host "  * Modo Teatro: video grande + rail de canales con scroll independiente."
Write-Host "  * Pantalla completa y multivision hasta 4 canales (audio en la celda activa)."
Write-Host "  * Panel de imagen en vivo: brillo, contraste, saturacion, zoom, encuadre."
Write-Host "  * Grid virtualizado, densidad y columnas ajustables, categorias ocultables."
Write-Host "  * Escala de UI, color de acento, navegacion por flechas / D-pad."
Write-Host ""
Write-Host "No se ha tocado usePlayer.ts ni el proxy: la reproduccion sigue igual." -ForegroundColor Yellow
Write-Host "Subir a Git:  git add . ; git commit -m 'StreamBox interfaz estilo Zonix' ; git push origin main"