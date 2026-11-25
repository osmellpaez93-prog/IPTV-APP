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
      {sidebarOpen && <div className="fixed inset-0 z-30 bg-black/70 backdrop-blur-sm lg:hidden" onClick={() => setSidebarOpen(false)} />}
      <aside className={clsx(
        "fixed left-0 top-0 z-40 flex h-screen w-64 shrink-0 flex-col border-r border-white/5 bg-bg-soft/95 backdrop-blur-xl transition-transform duration-200 lg:sticky lg:translate-x-0 lg:bg-bg-soft/70",
        sidebarOpen ? "translate-x-0" : "-translate-x-full"
      )}>
        <div className="flex items-center justify-between border-b border-white/5 p-5">
          <div className="flex items-center gap-2.5">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-brand to-iris font-black shadow-card">S</div>
            <div>
              <span className="block text-lg font-bold leading-none tracking-tight">StreamBox</span>
              <span className="text-[10px] uppercase tracking-[0.18em] text-ink-dim">Tu IPTV</span>
            </div>
          </div>
          <button onClick={() => setSidebarOpen(false)} className="rounded p-1 hover:bg-white/10 lg:hidden" aria-label="Cerrar menu"><X className="h-5 w-5" /></button>
        </div>

        <nav className="flex-1 space-y-1 overflow-y-auto p-3">
          {items.map((it) => (
            <NavLink key={it.to} to={it.to} end={it.to === "/"} data-focusable="true" onClick={() => setSidebarOpen(false)}
              className={({ isActive }) => clsx(
                "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium",
                isActive ? "bg-brand/15 text-brand" : "text-ink-muted hover:bg-bg-hover hover:text-ink"
              )}
            >
              <it.icon className="h-5 w-5" /> {it.label}
            </NavLink>
          ))}
        </nav>

        <div className="border-t border-white/5 p-4 text-[11px] leading-relaxed text-ink-dim">
          <p className="font-semibold text-ink-muted">StreamBox v0.4</p>
          <p>Flechas para navegar · Enter abre</p>
        </div>
      </aside>
    </>
  );
}
