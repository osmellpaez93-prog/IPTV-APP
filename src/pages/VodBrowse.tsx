import { useDeferredValue, useMemo, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Search, LayoutGrid, Rows3, Star } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { PosterRow } from "../components/vod/PosterRow";
import { Poster } from "../components/vod/Poster";
import { HeroSpotlight } from "../components/vod/HeroSpotlight";
import { CategoryPage } from "./CategoryPage";
import type { Channel } from "../types";
import "../styles/streambox-ui.css";

interface Props { kind: "movies" | "series" }

export function VodBrowse({ kind }: Props) {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const setNowPlaying = useStore((s) => s.setNowPlaying);
  const { favSet, toggle } = useFavorites();

  const [view, setView] = useState<"rows" | "grid" | "list">("rows");
  const [group, setGroup] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const q = useDeferredValue(query);

  const items = useLiveQuery(
    () =>
      activePlaylistId
        ? db.channels.where("[playlistId+category]").equals([activePlaylistId, kind]).toArray()
        : Promise.resolve([] as Channel[]),
    [activePlaylistId, kind]
  );

  const hist = useLiveQuery(async () => {
    const rows = await db.history.orderBy("updatedAt").reverse().limit(80).toArray();
    return rows.filter((r) => r.duration > 0 && r.position > 30 && r.position / r.duration < 0.97);
  }, []);

  const resume = useMemo(() => {
    if (!hist || !items) return [] as Array<{ ch: Channel; pct: number }>;
    const byId = new Map(items.map((c) => [c.id, c]));
    const out: Array<{ ch: Channel; pct: number }> = [];
    for (const h of hist) {
      const ch = byId.get(h.id);
      if (ch) out.push({ ch, pct: (h.position / h.duration) * 100 });
      if (out.length >= 18) break;
    }
    return out;
  }, [hist, items]);

  const pctMap = useMemo(() => new Map(resume.map((r) => [r.ch.id, r.pct])), [resume]);

  const groups = useMemo(() => {
    const m = new Map<string, Channel[]>();
    for (const c of items ?? []) {
      const g = c.group || "Sin categoria";
      const arr = m.get(g);
      if (arr) arr.push(c); else m.set(g, [c]);
    }
    return Array.from(m.entries()).sort((a, b) => b[1].length - a[1].length);
  }, [items]);

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (items ?? []).filter(
      (c) => (!group || (c.group || "Sin categoria") === group) && (!needle || c.name.toLowerCase().includes(needle))
    );
  }, [items, group, q]);

  const hero = useMemo(() => {
    const pool = (items ?? []).filter((c) => c.logo);
    if (pool.length === 0) return null;
    return pool[Math.floor(Math.random() * Math.min(pool.length, 60))];
  }, [items]);

  const title = kind === "movies" ? "Peliculas" : "Series";
  const noun = kind === "movies" ? "peliculas" : "series";

  if (view === "list") {
    return (
      <div className="sb-scope">
        <button onClick={() => setView("rows")} className="mb-4 flex items-center gap-2 rounded-lg border border-[#22304a] bg-[#0d1320] px-3 py-1.5 text-sm hover:bg-[#141d2e]">
          <Rows3 className="h-4 w-4 text-[#4c8dff]" /> Volver a portadas
        </button>
        <CategoryPage category={kind} title={title} placeholder={`Buscar ${noun}...`} noun={noun} />
      </div>
    );
  }

  if (!activePlaylistId) {
    return <div className="py-20 text-center text-[#93a3bd]">Carga una lista en Mis listas para ver el catalogo.</div>;
  }

  const searching = q.trim().length > 0 || !!group;

  return (
    <div className="sb-scope sb-in space-y-7">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="text-2xl font-black tracking-tight md:text-3xl">{title}</h1>
        <span className="sb-tnum rounded-full bg-[#141d2e] px-2.5 py-1 text-[11px] font-semibold text-[#93a3bd]">
          {(items ?? []).length.toLocaleString()}
        </span>
        <div className="flex-1" />
        <div className="relative w-full max-w-xs">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[#5d6d88]" />
          <input
            value={query}
            onChange={(e) => { setQuery(e.target.value); setGroup(null); }}
            placeholder={`Buscar ${noun}...`}
            className="w-full rounded-lg border border-[#22304a] bg-[#0d1320] py-2 pl-9 pr-3 text-sm placeholder:text-[#5d6d88] focus:border-[#4c8dff] focus:outline-none"
          />
        </div>
        <div className="flex overflow-hidden rounded-lg border border-[#22304a]">
          {([["rows", Rows3], ["grid", LayoutGrid]] as const).map(([k, Icon]) => (
            <button
              key={k}
              onClick={() => { setView(k); setGroup(null); }}
              className={clsx("p-2", view === k ? "bg-[#4c8dff]/20 text-[#4c8dff]" : "hover:bg-[#141d2e]")}
              aria-label={k === "rows" ? "Carruseles" : "Rejilla"}
            >
              <Icon className="h-4 w-4" />
            </button>
          ))}
          <button onClick={() => setView("list")} className="p-2 hover:bg-[#141d2e]" aria-label="Lista clasica">
            <Star className="h-4 w-4" />
          </button>
        </div>
      </div>

      {!searching && view === "rows" && hero && (
        <HeroSpotlight item={hero} kind={kind} fav={favSet.has(hero.id)} onFav={toggle} onOpen={setNowPlaying} />
      )}

      {!searching && resume.length > 0 && (
        <PosterRow
          title="Continuar viendo"
          accent="#38bdf8"
          items={resume.map((r) => r.ch)}
          onOpen={setNowPlaying}
          favSet={favSet}
          onFav={toggle}
          progressOf={(id) => pctMap.get(id)}
          width={230}
        />
      )}

      {!searching && view === "rows" && groups.slice(0, 14).map(([g, list]) => (
        <PosterRow
          key={g}
          title={g}
          items={list.slice(0, 24)}
          onOpen={setNowPlaying}
          favSet={favSet}
          onFav={toggle}
          progressOf={(id) => pctMap.get(id)}
          onSeeAll={() => { setGroup(g); setView("grid"); }}
        />
      ))}

      {(searching || view === "grid") && (
        <>
          {group && (
            <div className="flex items-center gap-3">
              <h2 className="text-lg font-bold">{group}</h2>
              <button onClick={() => { setGroup(null); setView("rows"); }} className="text-xs text-[#93a3bd] hover:text-white">
                Volver
              </button>
            </div>
          )}
          <p className="sb-tnum text-sm text-[#93a3bd]">{filtered.length.toLocaleString()} resultados</p>
          <div className="flex flex-wrap gap-4">
            {filtered.slice(0, 240).map((it) => (
              <Poster key={it.id} item={it} onOpen={setNowPlaying} width={158} fav={favSet.has(it.id)} onFav={toggle} progress={pctMap.get(it.id)} />
            ))}
          </div>
          {filtered.length === 0 && <p className="py-14 text-center text-[#5d6d88]">Sin resultados.</p>}
          {filtered.length > 240 && (
            <p className="text-center text-xs text-[#5d6d88]">Mostrando 240. Afina la busqueda para ver mas.</p>
          )}
        </>
      )}
    </div>
  );
}
