import { useDeferredValue, useEffect, useMemo, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { List, CalendarClock, ZoomIn, ZoomOut, Locate, PanelLeftClose, PanelLeftOpen } from "lucide-react";
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

function halfHourStart() {
  const d = new Date();
  d.setMinutes(d.getMinutes() < 30 ? 0 : 30, 0, 0);
  return d.getTime() - 30 * 60000;
}

export function TvGuide() {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const nowPlaying = useStore((s) => s.nowPlaying);
  const setViewMode = useStore((s) => s.setViewMode);
  const playInline = useStore((s) => s.playInline);
  const { favSet, toggle } = useFavorites();

  const [mode, setMode] = useState<"guide" | "list">("guide");
  const [cat, setCat] = useState<CatKey>("__all");
  const [showCats, setShowCats] = useState(() => window.innerWidth >= 1500);
  const [query, setQuery] = useState("");
  const q = useDeferredValue(query);
  const [pxPerMin, setPxPerMin] = useState(6);
  const [selected, setSelected] = useState<Channel | null>(null);
  const [startMs, setStartMs] = useState(halfHourStart);

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
    () => Array.from(new Set((all ?? []).map((c) => c.group || "Sin categoría"))).sort((a, b) => a.localeCompare(b)),
    [all]
  );

  const visible = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (all ?? []).filter((c) => {
      const g = c.group || "Sin categoría";
      if (cat === "__fav" && !favSet.has(c.id)) return false;
      if (cat === "__recent" && !recent?.has(c.id)) return false;
      if (cat !== "__all" && cat !== "__fav" && cat !== "__recent" && g !== cat && c.group !== cat) return false;
      if (needle && !c.name.toLowerCase().includes(needle)) return false;
      return true;
    });
  }, [all, cat, q, favSet, recent]);

  useEffect(() => {
    if (visible.length === 0) { setSelected(null); return; }
    if (!selected || !visible.some((c) => c.id === selected.id)) setSelected(visible[0]);
  }, [visible]); // eslint-disable-line react-hooks/exhaustive-deps

  // Un clic: reproduce en la miniatura. Si ya está sonando ese canal: lo amplía.
  const pick = (c: Channel) => {
    setSelected(c);
    if (nowPlaying?.id === c.id) { setViewMode("theater"); return; }
    playInline(c, visible);
  };
  // Doble clic / botón de la fila / "Ampliar": modo teatro.
  const enlarge = (c: Channel) => {
    setSelected(c);
    if (nowPlaying?.id !== c.id) playInline(c, visible);
    setViewMode("theater");
  };

  if (mode === "list") {
    return (
      <div className="sb-scope">
        <button
          onClick={() => setMode("guide")}
          className="mb-4 flex items-center gap-2 rounded-lg border border-[#22304a] bg-[#0d1320] px-3 py-1.5 text-sm hover:bg-[#141d2e]"
        >
          <CalendarClock className="h-4 w-4 text-[#4c8dff]" /> Volver a la guía
        </button>
        <CategoryPage category="live" title="TV en vivo" placeholder="Buscar canal..." noun="canales" />
      </div>
    );
  }

  if (!activePlaylistId) {
    return <div className="py-20 text-center text-[#93a3bd]">Carga una lista en Mis listas para ver la guía.</div>;
  }

  return (
    <div className="sb-scope sb-in flex h-[calc(100vh-7rem)] min-h-[520px] overflow-hidden rounded-xl border border-[#22304a] bg-[#070a12]">
      {showCats && (
        <aside className="hidden w-[250px] shrink-0 lg:block">
          <CategoryColumn channels={all ?? []} value={cat} onChange={setCat} query={query} onQuery={setQuery} />
        </aside>
      )}

      <section className="flex min-w-0 flex-1 flex-col">
        <ChannelPreview
          channel={selected}
          isFav={!!selected && favSet.has(selected.id)}
          onFav={toggle}
          onStart={pick}
          onExpand={enlarge}
        />

        <div className="flex shrink-0 flex-wrap items-center gap-2 border-b border-[#22304a] bg-[#0d1320] px-3 py-2">
          <button
            onClick={() => setShowCats((v) => !v)}
            className="hidden items-center gap-1.5 rounded-lg border border-[#22304a] px-2.5 py-1.5 text-xs hover:bg-[#141d2e] lg:flex"
            title="Mostrar u ocultar categorías"
          >
            {showCats ? <PanelLeftClose className="h-3.5 w-3.5" /> : <PanelLeftOpen className="h-3.5 w-3.5" />}
            Categorías
          </button>

          <select
            value={cat}
            onChange={(e) => setCat(e.target.value)}
            className={`max-w-[220px] rounded-lg border border-[#22304a] bg-[#070a12] px-2 py-1.5 text-xs focus:border-[#4c8dff] focus:outline-none ${showCats ? "lg:hidden" : ""}`}
          >
            <option value="__all">Todos ({(all ?? []).length})</option>
            <option value="__fav">Favoritos</option>
            <option value="__recent">Recientes</option>
            {groups.map((g) => <option key={g} value={g}>{g}</option>)}
          </select>

          {!showCats && (
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Buscar canal..."
              className="w-40 rounded-lg border border-[#22304a] bg-[#070a12] px-2 py-1.5 text-xs focus:border-[#4c8dff] focus:outline-none"
            />
          )}

          <span className="sb-tnum rounded-full bg-[#141d2e] px-2.5 py-1 text-[11px] font-semibold text-[#93a3bd]">
            {visible.length.toLocaleString()} canales
          </span>

          <div className="flex-1" />

          <button
            onClick={() => setStartMs(halfHourStart())}
            className="flex items-center gap-1.5 rounded-lg border border-[#22304a] px-2.5 py-1.5 text-xs hover:bg-[#141d2e]"
          >
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
            className="flex items-center gap-1.5 rounded-lg border border-[#22304a] px-2.5 py-1.5 text-xs hover:bg-[#141d2e]"
          >
            <List className="h-3.5 w-3.5" /> Lista
          </button>
        </div>

        <EpgTimeline
          channels={visible}
          selectedId={selected?.id ?? null}
          onSelect={setSelected}
          onPick={pick}
          onPlay={enlarge}
          pxPerMin={pxPerMin}
          startMs={startMs}
          minutes={MINUTES}
        />
      </section>
    </div>
  );
}
