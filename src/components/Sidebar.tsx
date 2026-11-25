import { NavLink } from "react-router-dom";
import { Home, Tv, Film, Clapperboard, Star, Search, Settings, ListVideo, X } from "lucide-react";
import { clsx } from "clsx";
import { useStore } from "../store";

const items = [
  { to: "/", label: "Inicio", icon: Home },
  { to: "/live", label: "TV en vivo", icon: Tv },
  { to: "/movies", label: "Películas", icon: Film },
  { to: "/series", label: "Series", icon: Clapperboard },
  { to: "/favorites", label: "Favoritos", icon: Star },
  { to: "/search", label: "Buscar", icon: Search },
  { to: "/playlists", label: "Mis listas", icon: ListVideo },
  { to: "/settings", label: "Ajustes", icon: Settings },
];

export function Sidebar() {
  const { sidebarOpen, setSidebarOpen } = useStore();

  return (
    <>
      {sidebarOpen && <div className="lg:hidden fixed inset-0 bg-black/60 z-30" onClick={() => setSidebarOpen(false)} />}

      <aside
        className={clsx(
          "fixed lg:sticky top-0 left-0 h-screen w-64 bg-bg-soft border-r border-white/5 z-40 shrink-0",
          "flex flex-col transition-transform duration-200",
          sidebarOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0"
        )}
      >
        <div className="flex items-center justify-between p-5 border-b border-white/5">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-brand flex items-center justify-center font-bold">S</div>
            <span className="font-bold text-lg tracking-tight">StreamBox</span>
          </div>
          <button onClick={() => setSidebarOpen(false)} className="lg:hidden p-1 rounded hover:bg-white/10" aria-label="Cerrar menú">
            <X className="w-5 h-5" />
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto p-3 space-y-1">
          {items.map((it) => (
            <NavLink
              key={it.to}
              to={it.to}
              end={it.to === "/"}
              data-focusable="true"
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                clsx(
                  "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors",
                  isActive ? "bg-brand/15 text-brand" : "text-ink-muted hover:bg-bg-hover hover:text-ink"
                )
              }
            >
              <it.icon className="w-5 h-5" />
              {it.label}
            </NavLink>
          ))}
        </nav>

        <div className="p-4 text-xs text-ink-dim border-t border-white/5">v0.1 · Fase 1</div>
      </aside>
    </>
  );
}
