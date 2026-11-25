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
  setNowPlaying: (c: Channel | null) => void;
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
      setNowPlaying: (c) => set({ nowPlaying: c }),
    }),
    {
      name: "streambox-ui",
      // Solo se recuerda la lista activa
      partialize: (s) => ({ activePlaylistId: s.activePlaylistId }),
    }
  )
);
