import { NavLink } from "react-router-dom";
import { Home, Tv, Film, Clapperboard, Search } from "lucide-react";
import { clsx } from "clsx";

const items = [
  { to: "/", label: "Inicio", icon: Home },
  { to: "/live", label: "TV", icon: Tv },
  { to: "/movies", label: "Pelis", icon: Film },
  { to: "/series", label: "Series", icon: Clapperboard },
  { to: "/search", label: "Buscar", icon: Search },
];

export function BottomNav() {
  return (
    <nav className="safe-bottom fixed inset-x-0 bottom-0 z-30 border-t border-white/10 bg-bg-deep/95 backdrop-blur-xl lg:hidden">
      <ul className="mx-auto flex max-w-lg items-stretch justify-between px-1 pt-1">
        {items.map((it) => (
          <li key={it.to} className="flex-1">
            <NavLink to={it.to} end={it.to === "/"}
              className={({ isActive }) => clsx(
                "flex flex-col items-center gap-1 rounded-lg px-1 py-2 text-[10px] font-semibold transition-colors",
                isActive ? "text-brand" : "text-ink-dim hover:text-ink"
              )}
            >
              {({ isActive }) => (
                <>
                  <span className={clsx("flex h-7 w-12 items-center justify-center rounded-full transition-colors", isActive && "bg-brand/15")}>
                    <it.icon className="h-[18px] w-[18px]" />
                  </span>
                  {it.label}
                </>
              )}
            </NavLink>
          </li>
        ))}
      </ul>
    </nav>
  );
}
