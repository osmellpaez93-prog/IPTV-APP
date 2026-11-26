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
