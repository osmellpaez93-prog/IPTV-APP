import { useDeferredValue, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useLiveQuery } from "dexie-react-hooks";
import { Search } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { ChannelGrid } from "../components/ChannelGrid";
import { PosterGrid } from "../components/PosterGrid";
import { ChannelCardSkeleton } from "../components/SkeletonLoader";
import type { Channel } from "../types";

interface Props {
  category: Channel["category"];
  title: string;
  placeholder: string;
  noun: string;
}

export function CategoryPage({ category, title, placeholder, noun }: Props) {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const play = useStore((s) => s.play);
  const { favSet, toggle } = useFavorites();
  const [group, setGroup] = useState("Todas");
  const [query, setQuery] = useState("");
  const deferredQuery = useDeferredValue(query);

  const items = useLiveQuery(
    () =>
      activePlaylistId
        ? db.channels.where("[playlistId+category]").equals([activePlaylistId, category]).toArray()
        : Promise.resolve([] as Channel[]),
    [activePlaylistId, category]
  );

  const groups = useMemo(
    () => Array.from(new Set((items ?? []).map((c) => c.group || "Sin categoría"))).sort((a, b) => a.localeCompare(b)),
    [items]
  );
  const activeGroup = groups.includes(group) ? group : "Todas";

  const filtered = useMemo(() => {
    const q = deferredQuery.trim().toLowerCase();
    return (items ?? []).filter(
      (c) =>
        (activeGroup === "Todas" || (c.group || "Sin categoría") === activeGroup) &&
        (!q || c.name.toLowerCase().includes(q))
    );
  }, [items, activeGroup, deferredQuery]);

  if (!activePlaylistId) {
    return (
      <div className="py-20 text-center text-ink-muted">
        <p className="mb-2">No hay ninguna lista cargada.</p>
        <Link to="/playlists" className="text-brand hover:underline">Ir a Mis listas</Link>
      </div>
    );
  }

  const poster = category === "movies" || category === "series";
  const onPlay = (c: Channel) => play(c, filtered);

  return (
    <div className="animate-fade-in space-y-5">
      <div>
        <h1 className="text-2xl font-bold md:text-3xl">{title}</h1>
        <p className="mt-1 text-ink-muted">{items ? `${filtered.length.toLocaleString()} ${noun}` : "Cargando…"}</p>
      </div>

      <div className="flex flex-col gap-3 md:flex-row">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-muted" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={placeholder}
            className="w-full rounded-lg border border-white/10 bg-bg-card py-2 pl-9 pr-3 focus:border-brand focus:outline-none"
          />
        </div>
        <select
          value={activeGroup}
          onChange={(e) => setGroup(e.target.value)}
          className="rounded-lg border border-white/10 bg-bg-card px-3 py-2 focus:border-brand focus:outline-none"
        >
          <option value="Todas">Todas las categorías</option>
          {groups.map((g) => (<option key={g} value={g}>{g}</option>))}
        </select>
      </div>

      {!items ? (
        <div className="grid gap-2 md:grid-cols-2">{Array.from({ length: 8 }).map((_, i) => <ChannelCardSkeleton key={i} />)}</div>
      ) : poster ? (
        <PosterGrid channels={filtered} favSet={favSet} onToggleFavorite={toggle} onPlay={onPlay} emptyText={`No hay ${noun} con ese filtro.`} />
      ) : (
        <ChannelGrid channels={filtered} favSet={favSet} onToggleFavorite={toggle} onPlay={onPlay} emptyText={`No hay ${noun} con ese filtro.`} />
      )}
    </div>
  );
}
