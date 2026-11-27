import { useDeferredValue, useEffect, useMemo, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { List, CalendarClock, ZoomIn, ZoomOut, Locate } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { CategoryColumn, type CatKey } from "../components/tv/CategoryColumn";
import { ChannelPreview } from "../components/tv/ChannelPreview";
import { EpgTimeline } from "../components/tv/EpgTimeline";
import { CategoryPage } from "./CategoryPage";
import type { Channel } from "../types";
import "../styles/streambox-ui.css";

const MINUTES = 360;

export function TvGuide() {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const setNowPlaying = useStore((s) => s.setNowPlaying);
  const { favSet, toggle } = useFavorites();

  const [mode, setMode] = useState<"guide" | "list">("guide");
  const [cat, setCat] = useState<CatKey>("__all");
  const [query, setQuery] = useState("");
  const q = useDeferredValue(query);
  const [pxPerMin, setPxPerMin] = useState(6);
  const [selected, setSelected] = useState<Channel | null>(null);
  const [startMs, setStartMs] = useState(() => {
    const d = new Date();
    d.setMinutes(d.getMinutes() < 30 ? 0 : 30, 0, 0);
    return d.getTime() - 30 * 60000;
  });

  const recent = useLiveQuery(async () => {
    const rows = await db.history.orderBy("updatedAt").reverse().limit(60).toArray();
    return new Set(rows.map((r) => r.id));
  }, []);

  const all = useLiveQuery(
    () =>
      activePlaylistId
        ? db.channels.where("[playlistId+category]").equals([activePlaylistId, "live"]).toArray()
        : Promise.resolve([] as Channel[]),
    [activePlaylistId]
  );

  const groups = useMemo(
    () => Array.from(new Set((all ?? []).map((c) => c.group || "Sin categoria"))).sort((a, b) => a.localeCompare(b)),
    [all]
  );

  const visible = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (all ?? []).filter((c) => {
      const g = c.group || "Sin categoria";
      if (cat === "__fav" && !favSet.has(c.id)) return false;
      if (cat === "__recent" && !(recent?.has(c.id))) return false;
      if (cat !== "__all" && cat !== "__fav" && cat !== "__recent" && g !== cat) return false;
      if (needle && !c.name.toLowerCase().includes(needle)) return false;
      return true;
    });
  }, [all, cat, q, favSet, recent]);

  useEffect(() => {
    if (visible.length === 0) { setSelected(null); return; }
    if (!selected || !visible.some((c) => c.id === selected.id)) setSelected(visible[0]);
  }, [visible]); // eslint-disable-line react-hooks/exhaustive-deps

  if (mode === "list") {
    return (
      <div className="sb-scope">
        <button
          onClick={() => setMode("guide")}
          className="mb-4 flex items-center gap-2 rounded-lg border border-[#22304a] bg-[#0d1320] px-3 py-1.5 text-sm hover:bg-[#141d2e]"
        >
          <CalendarClock className="h-4 w-4 text-[#4c8dff]" /> Volver a la guia
        </button>
        <CategoryPage category="live" title="TV en vivo" placeholder="Buscar canal..." noun="canales" />
      </div>
    );
  }

  if (!activePlaylistId) {
    return <div className="py-20 text-center text-[#93a3bd]">Carga una lista en Mis listas para ver la guia.</div>;
  }

  const jumpNow = () => {
    const d = new Date();
    d.setMinutes(d.getMinutes() < 30 ? 0 : 30, 0, 0);
    setStartMs(d.getTime() - 30 * 60000);
  };

  return (
    <div className="sb-scope sb-in flex h-[calc(100vh-11rem)] min-h-[520px] overflow-hidden rounded-xl border border-[#22304a] bg-[#070a12]">
      <aside className="hidden w-[262px] shrink-0 lg:block">
        <CategoryColumn channels={all ?? []} value={cat} onChange={setCat} query={query} onQuery={setQuery} />
      </aside>

      <section className="flex min-w-0 flex-1 flex-col">
        <ChannelPreview channel={selected} isFav={!!selected && favSet.has(selected.id)} onFav={toggle} onPlay={setNowPlaying} />

        <div className="flex shrink-0 flex-wrap items-center gap-2 border-b border-[#22304a] bg-[#0d1320] px-3 py-2">
          <select
            value={cat}
            onChange={(e) => setCat(e.target.value)}
            className="max-w-[220px] rounded-lg border border-[#22304a] bg-[#070a12] px-2 py-1.5 text-xs focus:border-[#4c8dff] focus:outline-none lg:hidden"
          >
            <option value="__all">Todos ({(all ?? []).length})</option>
            <option value="__fav">Favoritos</option>
            <option value="__recent">Recientes</option>
            {groups.map((g) => <option key={g} value={g}>{g}</option>)}
          </select>

          <span className="sb-tnum rounded-full bg-[#141d2e] px-2.5 py-1 text-[11px] font-semibold text-[#93a3bd]">
            {visible.length.toLocaleString()} canales
          </span>

          <div className="flex-1" />

          <button onClick={jumpNow} className="flex items-center gap-1.5 rounded-lg border border-[#22304a] px-2.5 py-1.5 text-xs hover:bg-[#141d2e]">
            <Locate className="h-3.5 w-3.5 text-[#38bdf8]" /> Ahora
          </button>
          <div className="flex items-center gap-1 rounded-lg border border-[#22304a] px-1 py-0.5">
            <button onClick={() => setPxPerMin((v) => Math.max(3, v - 1.5))} className="rounded p-1 hover:bg-[#141d2e]" aria-label="Alejar">
              <ZoomOut className="h-3.5 w-3.5" />
            </button>
            <span className="sb-tnum w-8 text-center text-[11px] text-[#93a3bd]">{pxPerMin.toFixed(1)}</span>
            <button onClick={() => setPxPerMin((v) => Math.min(16, v + 1.5))} className="rounded p-1 hover:bg-[#141d2e]" aria-label="Acercar">
              <ZoomIn className="h-3.5 w-3.5" />
            </button>
          </div>
          <button
            onClick={() => setMode("list")}
            className={clsx("flex items-center gap-1.5 rounded-lg border border-[#22304a] px-2.5 py-1.5 text-xs hover:bg-[#141d2e]")}
          >
            <List className="h-3.5 w-3.5" /> Lista
          </button>
        </div>

        <EpgTimeline
          channels={visible}
          selectedId={selected?.id ?? null}
          onSelect={setSelected}
          onPlay={setNowPlaying}
          pxPerMin={pxPerMin}
          startMs={startMs}
          minutes={MINUTES}
        />
      </section>
    </div>
  );
}
