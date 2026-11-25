import { useDeferredValue, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Search as SearchIcon } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { ChannelGrid } from "../components/ChannelGrid";

export function SearchPage() {
  const { activePlaylistId, setNowPlaying } = useStore();
  const { favSet, toggle } = useFavorites();
  const [query, setQuery] = useState("");
  const q = useDeferredValue(query).trim().toLowerCase();

  const results = useLiveQuery(async () => {
    if (!activePlaylistId || !q) return [];
    return db.channels
      .where("playlistId")
      .equals(activePlaylistId)
      .filter((c) => c.name.toLowerCase().includes(q))
      .limit(300)
      .toArray();
  }, [activePlaylistId, q]);

  return (
    <div className="space-y-5 animate-fade-in">
      <h1 className="text-2xl md:text-3xl font-bold">Buscar</h1>

      <div className="relative">
        <SearchIcon className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-ink-muted" />
        <input
          autoFocus
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Escribe para buscar en tu lista..."
          className="w-full pl-11 pr-4 py-3 rounded-xl bg-bg-card border border-white/10 focus:border-brand focus:outline-none text-lg"
        />
      </div>

      {q && <p className="text-sm text-ink-muted">{(results ?? []).length} resultados</p>}

      {q && (
        <ChannelGrid channels={results ?? []} favSet={favSet} onToggleFavorite={toggle} onPlay={setNowPlaying} />
      )}
    </div>
  );
}
