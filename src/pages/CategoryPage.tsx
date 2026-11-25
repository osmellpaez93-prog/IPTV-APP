import { useDeferredValue, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useLiveQuery } from "dexie-react-hooks";
import { Search } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { ChannelGrid } from "../components/ChannelGrid";
import { ChannelCardSkeleton } from "../components/SkeletonLoader";
import type { Channel } from "../types";

interface Props {
  category: Channel["category"];
  title: string;
  placeholder: string;
  noun: string;
}

export function CategoryPage({ category, title, placeholder, noun }: Props) {
  const { activePlaylistId, setNowPlaying } = useStore();
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
      <div className="text-center py-20 text-ink-muted">
        <p className="mb-2">No hay ninguna lista cargada.</p>
        <Link to="/playlists" className="text-brand hover:underline">Ir a Mis listas</Link>
      </div>
    );
  }

  return (
    <div className="space-y-5 animate-fade-in">
      <div>
        <h1 className="text-2xl md:text-3xl font-bold">{title}</h1>
        <p className="text-ink-muted mt-1">{items ? `${filtered.length.toLocaleString()} ${noun}` : "Cargando..."}</p>
      </div>

      <div className="flex flex-col md:flex-row gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-muted" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={placeholder}
            className="w-full pl-9 pr-3 py-2 rounded-lg bg-bg-card border border-white/10 focus:border-brand focus:outline-none"
          />
        </div>
        <select
          value={activeGroup}
          onChange={(e) => setGroup(e.target.value)}
          className="px-3 py-2 rounded-lg bg-bg-card border border-white/10 focus:border-brand focus:outline-none"
        >
          <option value="Todas">Todas las categorías</option>
          {groups.map((g) => (
            <option key={g} value={g}>{g}</option>
          ))}
        </select>
      </div>

      {!items ? (
        <div className="grid md:grid-cols-2 gap-2">
          {Array.from({ length: 8 }).map((_, i) => <ChannelCardSkeleton key={i} />)}
        </div>
      ) : (
        <ChannelGrid
          channels={filtered}
          favSet={favSet}
          onToggleFavorite={toggle}
          onPlay={setNowPlaying}
          emptyText={`No hay ${noun} en esta lista.`}
        />
      )}
    </div>
  );
}
