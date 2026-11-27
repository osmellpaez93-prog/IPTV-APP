import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Channel } from "../types";

export type ViewMode = "mini" | "theater" | "full" | "inline";
export type MiniSize = "s" | "m" | "l";
export type Corner = "tl" | "tr" | "bl" | "br";
export type Density = "compact" | "normal" | "comfy";
export type Aspect = "contain" | "cover" | "fill";
export type Accent = "signal" | "brand" | "gold" | "iris" | "lime";

export interface MiniPrefs { size: MiniSize; corner: Corner; opacity: number }
export interface UIPrefs {
  scale: number;
  density: Density;
  columns: 0 | 1 | 2 | 3;
  posterScale: number;
  accent: Accent;
  hiddenGroups: string[];
}
export interface VideoPrefs { brightness: number; contrast: number; saturate: number; zoom: number; aspect: Aspect }

export const DEFAULT_UI: UIPrefs = { scale: 1, density: "normal", columns: 0, posterScale: 1, accent: "signal", hiddenGroups: [] };
export const DEFAULT_VIDEO: VideoPrefs = { brightness: 100, contrast: 100, saturate: 100, zoom: 100, aspect: "contain" };
export const DEFAULT_MINI: MiniPrefs = { size: "m", corner: "br", opacity: 100 };

export const ACCENTS: Record<Accent, { hex: string; soft: string; label: string }> = {
  signal: { hex: "#22d3ee", soft: "#7ee7f7", label: "Cian" },
  brand: { hex: "#e50914", soft: "#ff6b70", label: "Rojo" },
  gold: { hex: "#ffb020", soft: "#ffd27a", label: "Ambar" },
  iris: { hex: "#8b5cf6", soft: "#b79bff", label: "Violeta" },
  lime: { hex: "#a3e635", soft: "#d0f58a", label: "Lima" },
};

export const ROW_HEIGHT: Record<Density, number> = { compact: 56, normal: 72, comfy: 92 };

const THEATER: ViewMode = "theater";
const MINI: ViewMode = "mini";

interface UIState {
  sidebarOpen: boolean;
  setSidebarOpen: (v: boolean) => void;
  toggleSidebar: () => void;

  activePlaylistId: string | null;
  setActivePlaylistId: (id: string | null) => void;

  nowPlaying: Channel | null;
  queue: Channel[];
  /** Series -> detalle de serie, peliculas -> ficha, resto -> reproduce. */
  setNowPlaying: (c: Channel | null) => void;
  play: (c: Channel, list?: Channel[]) => void;
  /** Reproduce directamente (boton Reproducir de la ficha, continuar viendo, panel de canales). */
  playNow: (c: Channel, list?: Channel[]) => void;
  setQueue: (list: Channel[]) => void;
  /** Reproduce dentro de la miniatura de la guia (modo inline). */
  playInline: (c: Channel, list?: Channel[]) => void;
  inlineSlot: HTMLElement | null;
  setInlineSlot: (el: HTMLElement | null) => void;
  zap: (delta: number) => void;
  zapTo: (index: number) => void;

  openSeries: Channel | null;
  closeSeries: () => void;
  openMovie: Channel | null;
  closeMovie: () => void;

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

      // Regla de vista: si no habia nada sonando, abre en TEATRO; si ya habia algo, respeta el modo actual.
      setNowPlaying: (c) =>
        set((s) => {
          if (!c) return { nowPlaying: null, viewMode: MINI };
          if (c.seriesId) return { openSeries: c };
          if (c.category === "movies") return { openMovie: c };
          const inQueue = s.queue.some((x) => x.id === c.id);
          return { nowPlaying: c, queue: inQueue ? s.queue : [c], viewMode: s.nowPlaying ? s.viewMode : THEATER };
        }),

      play: (c, list) =>
        set((s) => {
          if (c.seriesId) return { openSeries: c };
          if (c.category === "movies") return { openMovie: c };
          return {
            nowPlaying: c,
            queue: list && list.length ? list : [c],
            viewMode: s.nowPlaying ? s.viewMode : THEATER,
          };
        }),

      playNow: (c, list) =>
        set((s) => ({
          nowPlaying: c,
          queue: list && list.length ? list : [c],
          openMovie: null,
          openSeries: null,
          viewMode: s.nowPlaying ? s.viewMode : THEATER,
        })),

      playInline: (c, list) =>
        set({ nowPlaying: c, queue: list && list.length ? list : [c], viewMode: "inline" as ViewMode }),
      inlineSlot: null,
      setInlineSlot: (el) => set({ inlineSlot: el }),
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
      openMovie: null,
      closeMovie: () => set({ openMovie: null }),

      viewMode: MINI,
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
      partialize: (s) => ({ activePlaylistId: s.activePlaylistId, ui: s.ui, mini: s.mini, video: s.video }),
    }
  )
);
