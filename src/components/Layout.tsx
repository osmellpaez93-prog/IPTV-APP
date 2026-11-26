import { Outlet } from "react-router-dom";
import { Menu } from "lucide-react";
import { Sidebar } from "./Sidebar";
import { BottomNav } from "./BottomNav";
import { Player } from "./Player";
import { SeriesDetail } from "./SeriesDetail";
import { MovieDetail } from "./MovieDetail";
import { useStore } from "../store";
import { useSpatialNav } from "../hooks/useSpatialNav";

export function Layout() {
  const toggleSidebar = useStore((s) => s.toggleSidebar);
  const nowPlaying = useStore((s) => s.nowPlaying);
  const setNowPlaying = useStore((s) => s.setNowPlaying);
  const queue = useStore((s) => s.queue);
  const zap = useStore((s) => s.zap);
  const zapTo = useStore((s) => s.zapTo);
  const openSeries = useStore((s) => s.openSeries);
  const openMovie = useStore((s) => s.openMovie);

  useSpatialNav(true);

  const index = nowPlaying ? queue.findIndex((c) => c.id === nowPlaying.id) : -1;
  const canZap = index >= 0 && queue.length > 1;

  return (
    <div className="relative min-h-screen">
      {/* Fondo con profundidad: mesh + grano, estatico y barato */}
      <div aria-hidden className="pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-bg">
        <div className="absolute -left-40 -top-40 h-[520px] w-[520px] animate-drift rounded-full bg-brand/20 blur-[130px]" />
        <div className="absolute -right-32 top-1/4 h-[460px] w-[460px] animate-drift rounded-full bg-iris/15 blur-[140px]" />
        <div className="absolute bottom-0 left-1/3 h-[420px] w-[420px] animate-drift rounded-full bg-aqua/10 blur-[150px]" />
        <div className="grain absolute inset-0 opacity-[0.035] mix-blend-overlay" />
      </div>

      <div className="flex min-h-screen">
        <Sidebar />
        <div className="flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-20 flex items-center gap-3 border-b border-white/5 bg-bg/85 px-4 py-3 backdrop-blur-xl lg:hidden">
            <button onClick={toggleSidebar} className="rounded-lg p-2 hover:bg-white/10" aria-label="Abrir menu"><Menu className="h-5 w-5" /></button>
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-md bg-brand text-sm font-bold">S</div>
              <span className="font-semibold">StreamBox</span>
            </div>
          </header>

          <main className="mx-auto w-full max-w-[1600px] flex-1 p-4 pb-28 md:p-6 lg:p-8 lg:pb-10">
            {nowPlaying && (
              <div className="sticky top-[53px] z-10 mb-4 bg-bg/95 pb-3 backdrop-blur lg:top-0">
                <div className="max-w-5xl">
                  <Player
                    channel={nowPlaying}
                    onClose={() => setNowPlaying(null)}
                    onPrev={canZap ? () => zap(-1) : undefined}
                    onNext={canZap ? () => zap(1) : undefined}
                    onJump={canZap ? (i) => zapTo(i) : undefined}
                    position={canZap ? { index, total: queue.length } : undefined}
                  />
                </div>
              </div>
            )}
            <Outlet />
          </main>
        </div>
      </div>

      <BottomNav />

      <div {...(openSeries || openMovie ? { "data-nav-lock": "modal" } : {})}>
        <SeriesDetail />
        <MovieDetail />
      </div>
    </div>
  );
}
