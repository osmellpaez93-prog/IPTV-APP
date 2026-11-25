import { useMemo } from "react";
import { Link } from "react-router-dom";
import { useLiveQuery } from "dexie-react-hooks";
import { Tv, Film, ListVideo, Plus, Clapperboard } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { imgUrl } from "../services/proxy";
import type { Channel } from "../types";

export function Home() {
  const { activePlaylistId, setNowPlaying } = useStore();
  const playlists = useLiveQuery(() => db.playlists.toArray(), []);

  const data = useLiveQuery(async () => {
    if (!activePlaylistId) return null;
    const q = (cat: Channel["category"]) =>
      db.channels.where("[playlistId+category]").equals([activePlaylistId, cat]);
    const [live, movies, series, nLive, nMovies, nSeries] = await Promise.all([
      q("live").limit(20).toArray(),
      q("movies").limit(20).toArray(),
      q("series").limit(20).toArray(),
      q("live").count(),
      q("movies").count(),
      q("series").count(),
    ]);
    return { live, movies, series, nLive, nMovies, nSeries };
  }, [activePlaylistId]);

  const active = playlists?.find((p) => p.id === activePlaylistId);
  const heroLogo = useMemo(() => imgUrl(data?.live.find((c) => c.logo)?.logo), [data]);

  if (playlists && playlists.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-24 text-center animate-fade-in">
        <div className="w-16 h-16 rounded-2xl bg-brand/15 flex items-center justify-center mb-4">
          <ListVideo className="w-8 h-8 text-brand" />
        </div>
        <h1 className="text-3xl font-bold">Bienvenido a StreamBox</h1>
        <p className="text-ink-muted mt-2 max-w-md">
          Empieza añadiendo tu lista M3U/M3U8. StreamBox no incluye contenido: tú traes el tuyo.
        </p>
        <Link to="/playlists" className="mt-6 px-5 py-2.5 rounded-lg bg-brand hover:bg-brand-hover font-semibold flex items-center gap-2">
          <Plus className="w-4 h-4" /> Añadir mi primera lista
        </Link>
      </div>
    );
  }

  if (!data) return null;

  return (
    <div className="space-y-8 animate-fade-in">
      <section className="relative rounded-2xl overflow-hidden bg-bg-card border border-white/5" style={{ minHeight: 260 }}>
        {heroLogo && <img src={heroLogo} alt="" className="absolute inset-0 w-full h-full object-cover opacity-20" />}
        <div className="absolute inset-0 bg-gradient-to-r from-bg via-bg/70 to-transparent" />
        <div className="relative p-6 md:p-10 flex flex-col justify-end min-h-[260px]">
          <p className="text-xs uppercase tracking-widest text-brand font-semibold">{active?.name || "Lista activa"}</p>
          <h1 className="text-3xl md:text-5xl font-bold mt-2">Tu IPTV, a un clic</h1>
          <p className="text-ink-muted mt-2 max-w-xl">
            {data.nLive.toLocaleString()} en vivo · {data.nMovies.toLocaleString()} películas · {data.nSeries.toLocaleString()} series
          </p>
          <div className="flex flex-wrap gap-2 mt-4">
            <Link to="/live" className="px-4 py-2 rounded-lg bg-brand hover:bg-brand-hover font-semibold flex items-center gap-2">
              <Tv className="w-4 h-4" /> TV en vivo
            </Link>
            <Link to="/movies" className="px-4 py-2 rounded-lg bg-bg-soft hover:bg-bg-hover font-semibold flex items-center gap-2">
              <Film className="w-4 h-4" /> Películas
            </Link>
            <Link to="/series" className="px-4 py-2 rounded-lg bg-bg-soft hover:bg-bg-hover font-semibold flex items-center gap-2">
              <Clapperboard className="w-4 h-4" /> Series
            </Link>
          </div>
        </div>
      </section>

      <Row title="Canales en vivo" items={data.live} onPlay={setNowPlaying} />
      <Row title="Películas" items={data.movies} onPlay={setNowPlaying} />
      <Row title="Series" items={data.series} onPlay={setNowPlaying} />
    </div>
  );
}

function Row({ title, items, onPlay }: { title: string; items: Channel[]; onPlay: (c: Channel) => void }) {
  if (items.length === 0) return null;
  return (
    <section>
      <h2 className="text-xl font-bold mb-3">{title}</h2>
      <div className="flex gap-3 overflow-x-auto pb-3 -mx-1 px-1 snap-x">
        {items.map((c) => (
          <button
            key={c.id}
            data-focusable="true"
            onClick={() => onPlay(c)}
            className="shrink-0 w-40 snap-start group text-left rounded-lg"
          >
            <div className="aspect-video rounded-lg bg-bg-card overflow-hidden border border-white/5 group-hover:border-brand/50 transition-colors">
              {c.logo ? (
                <img src={imgUrl(c.logo)} alt="" loading="lazy" className="w-full h-full object-contain p-2" />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-ink-muted text-xs p-2 text-center">
                  {c.name.slice(0, 30)}
                </div>
              )}
            </div>
            <p className="mt-2 text-sm font-medium truncate">{c.name}</p>
            <p className="text-xs text-ink-muted truncate">{c.group}</p>
          </button>
        ))}
      </div>
    </section>
  );
}
