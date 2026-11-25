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
  // Si el elemento es una serie (seriesId), abre su detalle en lugar de reproducir
  setNowPlaying: (c: Channel | null) => void;

  openSeries: Channel | null;
  closeSeries: () => void;
}

export const useStore = create<UIState>()(
  persist(
    (set) => ({
      sidebarOpen: false,
      setSidebarOpen: (v) => set({ sidebarOpen: v }),
      toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),

      activePlaylistId: null,
      setActivePlaylistId: (id) => set({ activePlaylistId: id }),

      nowPlaying: null,
      setNowPlaying: (c) => set(c && c.seriesId ? { openSeries: c } : { nowPlaying: c }),

      openSeries: null,
      closeSeries: () => set({ openSeries: null }),
    }),
    {
      name: "streambox-ui",
      partialize: (s) => ({ activePlaylistId: s.activePlaylistId }),
    }
  )
);
