import { memo, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Search, X } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { useStore } from "../store";
import { imgUrl } from "../services/proxy";
import type { Channel } from "../types";

const ROW = 60;
const OVERSCAN = 8;

interface Props {
  onClose?: () => void;
  onPick?: (c: Channel) => void;
  title?: string;
}

/** Panel de canales con scroll propio: nunca mueve la pagina de fondo. */
function RailBase({ onClose, onPick, title = "Canales" }: Props) {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const nowPlaying = useStore((s) => s.nowPlaying);
  const playNow = useStore((s) => s.playNow);
  const setQueue = useStore((s) => s.setQueue);
  const hiddenGroups = useStore((s) => s.ui.hiddenGroups);
  const category = nowPlaying?.category ?? "live";

  const [q, setQ] = useState("");
  const [group, setGroup] = useState("Todas");
  const [range, setRange] = useState({ start: 0, end: 20 });
  const scrollRef = useRef<HTMLDivElement | null>(null);

  const items = useLiveQuery(
    () =>
      activePlaylistId
        ? db.channels.where("[playlistId+category]").equals([activePlaylistId, category]).toArray()
        : Promise.resolve([] as Channel[]),
    [activePlaylistId, category]
  );

  const groups = useMemo(
    () => Array.from(new Set((items ?? []).map((c) => c.group || "Sin categoria"))).sort((a, b) => a.localeCompare(b)),
    [items]
  );
  const activeGroup = groups.includes(group) ? group : "Todas";

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (items ?? []).filter(
      (c) =>
        !hiddenGroups.includes(c.group || "Sin categoria") &&
        (activeGroup === "Todas" || (c.group || "Sin categoria") === activeGroup) &&
        (!needle || c.name.toLowerCase().includes(needle))
    );
  }, [items, activeGroup, q, hiddenGroups]);

  useEffect(() => { if (filtered.length) setQueue(filtered); }, [filtered, setQueue]);

  const recompute = useCallback(() => {
    const el = scrollRef.current;
    if (!el) return;
    const start = Math.max(0, Math.floor(el.scrollTop / ROW) - OVERSCAN);
    const end = Math.min(Math.ceil(filtered.length), Math.ceil((el.scrollTop + el.clientHeight) / ROW) + OVERSCAN);
    setRange((r) => (r.start === start && r.end === end ? r : { start, end }));
  }, [filtered.length]);

  useEffect(() => {
    recompute();
    const el = scrollRef.current;
    if (el) el.scrollTop = 0;
  }, [recompute]);

  // Centra el canal que esta sonando al abrir el rail.
  useEffect(() => {
    const el = scrollRef.current;
    if (!el || !nowPlaying) return;
    const i = filtered.findIndex((c) => c.id === nowPlaying.id);
    if (i > 0) {
      el.scrollTop = Math.max(0, i * ROW - el.clientHeight / 2);
      recompute();
    }
  }, [nowPlaying?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  const choose = (c: Channel) => { if (onPick) onPick(c); else playNow(c, filtered); };
  const slice = filtered.slice(range.start, range.end);

  return (
    <div className="flex h-full min-h-0 flex-col border-l border-bg-line bg-bg-surface/95">
      <div className="flex items-center gap-2 border-b border-bg-line px-3 py-3">
        <h3 className="flex-1 text-sm font-bold uppercase tracking-widest text-signal">{title}</h3>
        <span className="rounded-full bg-bg-raised px-2 py-0.5 text-[11px] font-semibold text-ink-muted">
          {filtered.length.toLocaleString()}
        </span>
        {onClose && (
          <button onClick={onClose} className="rounded-lg p-1.5 hover:bg-white/10" aria-label="Cerrar panel">
            <X className="h-4 w-4" />
          </button>
        )}
      </div>

      <div className="space-y-2 border-b border-bg-line px-3 py-2">
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-ink-dim" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Filtrar canales..."
            className="w-full rounded-lg border border-bg-line bg-bg-deep py-1.5 pl-8 pr-2 text-sm focus:border-signal focus:outline-none"
          />
        </div>
        <select
          value={activeGroup}
          onChange={(e) => setGroup(e.target.value)}
          className="w-full rounded-lg border border-bg-line bg-bg-deep px-2 py-1.5 text-xs focus:border-signal focus:outline-none"
        >
          <option value="Todas">Todas las categorias</option>
          {groups.map((g) => <option key={g} value={g}>{g}</option>)}
        </select>
      </div>

      <div ref={scrollRef} onScroll={recompute} className="min-h-0 flex-1 overflow-y-auto px-2 py-2">
        {filtered.length === 0 ? (
          <p className="py-8 text-center text-xs text-ink-dim">Sin resultados.</p>
        ) : (
          <div style={{ height: filtered.length * ROW, position: "relative" }}>
            <div style={{ position: "absolute", top: range.start * ROW, left: 0, right: 0 }}>
              {slice.map((c, i) => {
                const n = range.start + i;
                const on = nowPlaying?.id === c.id;
                const logo = imgUrl(c.logo);
                return (
                  <button
                    key={c.id}
                    data-focusable="true"
                    onClick={() => choose(c)}
                    style={{ height: ROW }}
                    className={clsx(
                      "flex w-full items-center gap-2.5 rounded-lg px-2 text-left",
                      on ? "bg-signal/15 ring-1 ring-signal/50" : "hover:bg-bg-raised"
                    )}
                  >
                    <span className="w-8 shrink-0 text-right font-mono text-[11px] text-ink-dim">{n + 1}</span>
                    <span className="h-9 w-9 shrink-0 overflow-hidden rounded-md bg-bg-deep ring-1 ring-white/5">
                      {logo ? (
                        <img src={logo} alt="" loading="lazy" className="h-full w-full object-contain p-0.5" />
                      ) : (
                        <span className="flex h-full w-full items-center justify-center text-[10px] font-bold text-ink-dim">
                          {c.name.slice(0, 2).toUpperCase()}
                        </span>
                      )}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className={clsx("block truncate text-[13px] font-semibold", on && "text-signal")}>{c.name}</span>
                      <span className="block truncate text-[11px] text-ink-dim">{c.group}</span>
                    </span>
                    {on && <span className="h-1.5 w-1.5 shrink-0 animate-live-dot rounded-full bg-brand" />}
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export const ChannelRail = memo(RailBase);
