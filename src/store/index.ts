import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Channel } from "../types";

interface UIState {
  sidebarOpen: boolean;
  setSidebarOpen: (v: boolean) => void;
  toggleSidebar: () => void;

  activePlaylistId: string | null;
  setActivePlaylistId: (id: string | null) => void;

  nowPlaying: Channel | null;
  /** Cola de zapping: la lista filtrada desde la que se lanzó el canal. */
  queue: Channel[];

  /** Abre el elemento: series -> detalle de serie, películas -> ficha, resto -> reproduce. */
  setNowPlaying: (c: Channel | null) => void;
  play: (c: Channel, list?: Channel[]) => void;
  /** Reproduce directamente (botón Reproducir de la ficha, continuar viendo). */
  playNow: (c: Channel, list?: Channel[]) => void;
  zap: (delta: number) => void;
  zapTo: (index: number) => void;

  openSeries: Channel | null;
  closeSeries: () => void;
  openMovie: Channel | null;
  closeMovie: () => void;
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
          if (!c) return { nowPlaying: null };
          if (c.seriesId) return { openSeries: c };
          if (c.category === "movies") return { openMovie: c };
          const inQueue = s.queue.some((x) => x.id === c.id);
          return { nowPlaying: c, queue: inQueue ? s.queue : [c] };
        }),

      play: (c, list) =>
        set(
          c.seriesId
            ? { openSeries: c }
            : c.category === "movies"
              ? { openMovie: c }
              : { nowPlaying: c, queue: list && list.length ? list : [c] }
        ),

      playNow: (c, list) =>
        set({ nowPlaying: c, queue: list && list.length ? list : [c], openMovie: null, openSeries: null }),

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
    }),
    {
      name: "streambox-ui",
      partialize: (s) => ({ activePlaylistId: s.activePlaylistId }),
    }
  )
);
