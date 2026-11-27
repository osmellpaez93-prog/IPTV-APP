import { useMemo } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Search, Star, History, Tv } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../../db";
import { useFavorites } from "../../hooks/useFavorites";
import type { Channel } from "../../types";

export type CatKey = string; // "__all" | "__fav" | "__recent" | nombre de grupo

interface Props {
  channels: Channel[];
  value: CatKey;
  onChange: (k: CatKey) => void;
  query: string;
  onQuery: (v: string) => void;
}

export function CategoryColumn({ channels, value, onChange, query, onQuery }: Props) {
  const { favSet } = useFavorites();
  const recent = useLiveQuery(async () => {
    const rows = await db.history.orderBy("updatedAt").reverse().limit(60).toArray();
    return new Set(rows.map((r) => r.id));
  }, []);

  const groups = useMemo(() => {
    const m = new Map<string, number>();
    for (const c of channels) {
      const g = c.group || "Sin categoria";
      m.set(g, (m.get(g) ?? 0) + 1);
    }
    return Array.from(m.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [channels]);

  const favCount = useMemo(() => channels.filter((c) => favSet.has(c.id)).length, [channels, favSet]);
  const recentCount = useMemo(
    () => (recent ? channels.filter((c) => recent.has(c.id)).length : 0),
    [channels, recent]
  );

  const Item = ({ k, label, count, icon: Icon }: { k: CatKey; label: string; count: number; icon?: any }) => {
    const on = value === k;
    return (
      <button
        data-sbfocus="1"
        onClick={() => onChange(k)}
        title={label}
        className={clsx(
          "flex w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-[13px]",
          on ? "sb-row-on font-semibold text-white" : "text-[#93a3bd] hover:bg-[#141d2e] hover:text-white"
        )}
      >
        {Icon && <Icon className="h-3.5 w-3.5 shrink-0 opacity-80" />}
        <span className="min-w-0 flex-1 truncate">{label}</span>
        <span className={clsx("sb-tnum shrink-0 text-[11px]", on ? "text-[#4c8dff]" : "text-[#5d6d88]")}>
          {count.toLocaleString()}
        </span>
      </button>
    );
  };

  return (
    <div className="flex h-full min-h-0 w-full flex-col border-r border-[#22304a] bg-[#0d1320]">
      <div className="border-b border-[#22304a] p-3">
        <div className="mb-2 flex items-center gap-2">
          <Tv className="h-4 w-4 text-[#4c8dff]" />
          <h2 className="text-sm font-bold uppercase tracking-[0.18em]">TV</h2>
        </div>
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-[#5d6d88]" />
          <input
            value={query}
            onChange={(e) => onQuery(e.target.value)}
            placeholder="Buscar canal..."
            className="w-full rounded-lg border border-[#22304a] bg-[#070a12] py-1.5 pl-8 pr-2 text-[13px] placeholder:text-[#5d6d88] focus:border-[#4c8dff] focus:outline-none"
          />
        </div>
      </div>

      <div className="sb-scroll min-h-0 flex-1 space-y-0.5 overflow-y-auto p-2">
        <Item k="__fav" label="Favoritos" count={favCount} icon={Star} />
        <Item k="__recent" label="Vistos recientemente" count={recentCount} icon={History} />
        <Item k="__all" label="Todos los canales" count={channels.length} icon={Tv} />
        <div className="my-2 border-t border-[#22304a]" />
        {groups.map(([g, n]) => (
          <Item key={g} k={g} label={g} count={n} />
        ))}
        {groups.length === 0 && <p className="px-2 py-6 text-center text-xs text-[#5d6d88]">Sin categorias.</p>}
      </div>
    </div>
  );
}
