import { useLiveQuery } from "dexie-react-hooks";
import { Star } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { ChannelGrid } from "../components/ChannelGrid";
import type { Channel } from "../types";

export function Favorites() {
  const { setNowPlaying } = useStore();
  const { favSet, toggle } = useFavorites();
  const ids = Array.from(favSet);

  const channels = useLiveQuery(async () => {
    const rows = await db.channels.bulkGet(ids);
    return rows.filter(Boolean) as Channel[];
  }, [ids.join("|")]);

  return (
    <div className="space-y-5 animate-fade-in">
      <div>
        <h1 className="text-2xl md:text-3xl font-bold flex items-center gap-2">
          <Star className="w-6 h-6 text-brand fill-brand" /> Favoritos
        </h1>
        <p className="text-ink-muted mt-1">{(channels ?? []).length} elementos</p>
      </div>

      <ChannelGrid
        channels={channels ?? []}
        favSet={favSet}
        onToggleFavorite={toggle}
        onPlay={setNowPlaying}
        emptyText="Aún no tienes favoritos. Pulsa la estrella en cualquier canal."
      />
    </div>
  );
}
