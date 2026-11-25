import { Outlet } from "react-router-dom";
import { Menu } from "lucide-react";
import { Sidebar } from "./Sidebar";
import { Player } from "./Player";
import { SeriesDetail } from "./SeriesDetail";
import { useStore } from "../store";

export function Layout() {
  const { toggleSidebar, nowPlaying, setNowPlaying } = useStore();

  return (
    <div className="min-h-screen flex">
      <Sidebar />
      <div className="flex-1 min-w-0 flex flex-col">
        <header className="lg:hidden sticky top-0 z-20 bg-bg/80 backdrop-blur border-b border-white/5 px-4 py-3 flex items-center gap-3">
          <button onClick={toggleSidebar} className="p-2 rounded-lg hover:bg-white/10" aria-label="Abrir menú">
            <Menu className="w-5 h-5" />
          </button>
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-md bg-brand flex items-center justify-center font-bold text-sm">S</div>
            <span className="font-semibold">StreamBox</span>
          </div>
        </header>

        <main className="flex-1 p-4 md:p-6 lg:p-8 max-w-[1600px] w-full mx-auto">
          {/* Un unico reproductor global: no se reinicia al cambiar de pagina */}
          {nowPlaying && (
            <div className="sticky top-[53px] lg:top-0 z-10 bg-bg pb-4 mb-2">
              <div className="max-w-4xl">
                <Player channel={nowPlaying} onClose={() => setNowPlaying(null)} />
              </div>
            </div>
          )}
          <Outlet />
        </main>
      </div>
      <SeriesDetail />
    </div>
  );
}
