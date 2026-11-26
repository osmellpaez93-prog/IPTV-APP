import { useMemo } from "react";
import { Link } from "react-router-dom";
import { useLiveQuery } from "dexie-react-hooks";
import { Tv, Film, ListVideo, Plus, Clapperboard, Star, Play } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { imgUrl } from "../services/proxy";
import type { Channel } from "../types";

export function Home() {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const play = useStore((s) => s.play);
  const posterScale = useStore((s) => s.ui.posterScale);
  const hiddenGroups = useStore((s) => s.ui.hiddenGroups);
  const playlists = useLiveQuery(() => db.playlists.toArray(), []);

  const data = useLiveQuery(async () => {
    if (!activePlaylistId) return null;
    const q = (cat: Channel["category"]) =>
      db.channels.where("[playlistId+category]").equals([activePlaylistId, cat]);
    const [live, movies, series, nLive, nMovies, nSeries] = await Promise.all([
      q("live").limit(24).toArray(),
      q("movies").limit(24).toArray(),
      q("series").limit(24).toArray(),
      q("live").count(),
      q("movies").count(),
      q("series").count(),
    ]);
    return { live, movies, series, nLive, nMovies, nSeries };
  }, [activePlaylistId]);

  const active = playlists?.find((p) => p.id === activePlaylistId);
  const heroLogo = useMemo(() => imgUrl(data?.live.find((c) => c.logo)?.logo), [data]);
  const vis = (list: Channel[]) => list.filter((c) => !hiddenGroups.includes(c.group || "Sin categoria"));

  if (playlists && playlists.length === 0) {
    return (
      <div className="flex animate-fade-in flex-col items-center justify-center py-24 text-center">
        <div className="mb-5 flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-brand via-iris to-signal shadow-glow">
          <ListVideo className="h-8 w-8" />
        </div>
        <h1 className="text-3xl font-bold md:text-4xl">Bienvenido a StreamBox</h1>
        <p className="mt-3 max-w-md text-ink-muted">
          Anade tu cuenta Xtream o una lista M3U. StreamBox no incluye contenido: tu traes el tuyo.
        </p>
        <Link to="/playlists" data-focusable="true"
          className="mt-6 flex items-center gap-2 rounded-lg bg-brand px-5 py-2.5 font-semibold hover:bg-brand-hover">
          <Plus className="h-4 w-4" /> Anadir mi primera lista
        </Link>
      </div>
    );
  }

  if (!data) return null;

  return (
    <div className="animate-fade-in space-y-9">
      <section className="relative overflow-hidden rounded-2xl border border-bg-line bg-bg-surface">
        {heroLogo && <img src={heroLogo} alt="" className="absolute inset-0 h-full w-full object-cover opacity-20 blur-[2px]" />}
        <div className="absolute inset-0 bg-gradient-to-r from-bg-deep via-bg-deep/85 to-transparent" />
        <div className="absolute -right-16 -top-16 h-64 w-64 rounded-full bg-signal/25 blur-[90px]" />
        <div className="relative flex min-h-[264px] flex-col justify-end p-6 md:p-10">
          <p className="text-xs font-semibold uppercase tracking-[0.22em] text-signal">{active?.name || "Lista activa"}</p>
          <h1 className="mt-2 text-3xl font-black leading-tight md:text-5xl">Tu IPTV, a un clic</h1>
          <div className="mt-3 flex flex-wrap gap-x-5 gap-y-1 text-sm text-ink-muted">
            <span><b className="text-ink">{data.nLive.toLocaleString()}</b> en vivo</span>
            <span><b className="text-gold">{data.nMovies.toLocaleString()}</b> peliculas</span>
            <span><b className="text-iris">{data.nSeries.toLocaleString()}</b> series</span>
          </div>
          <div className="mt-5 flex flex-wrap gap-2">
            <Link to="/live" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-brand px-4 py-2 font-semibold hover:bg-brand-hover">
              <Tv className="h-4 w-4" /> TV en vivo
            </Link>
            <Link to="/movies" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-white/10 px-4 py-2 font-semibold hover:bg-white/20">
              <Film className="h-4 w-4" /> Peliculas
            </Link>
            <Link to="/series" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-white/10 px-4 py-2 font-semibold hover:bg-white/20">
              <Clapperboard className="h-4 w-4" /> Series
            </Link>
            <Link to="/favorites" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-white/10 px-4 py-2 font-semibold hover:bg-white/20">
              <Star className="h-4 w-4" /> Favoritos
            </Link>
          </div>
        </div>
      </section>

      <Row title="Canales en vivo" accent="text-brand" items={vis(data.live)} onPlay={play} scale={posterScale} />
      <Row title="Peliculas" accent="text-gold" items={vis(data.movies)} onPlay={play} scale={posterScale} />
      <Row title="Series" accent="text-iris" items={vis(data.series)} onPlay={play} scale={posterScale} />
    </div>
  );
}

function Row({
  title, accent, items, onPlay, scale,
}: {
  title: string; accent: string; items: Channel[];
  onPlay: (c: Channel, list?: Channel[]) => void; scale: number;
}) {
  if (items.length === 0) return null;
  const w = Math.round(176 * scale);
  return (
    <section>
      <div className="mb-3 flex items-baseline gap-3">
        <h2 className="text-xl font-bold">{title}</h2>
        <span className={`text-xs font-semibold uppercase tracking-widest ${accent}`}>{items.length} destacados</span>
      </div>
      <div className="no-scrollbar -mx-1 flex snap-x gap-3 overflow-x-auto px-1 pb-2">
        {items.map((c) => (
          <button
            key={c.id}
            data-focusable="true"
            onClick={() => onPlay(c, items)}
            title={c.name}
            style={{ width: w }}
            className="group shrink-0 snap-start rounded-xl text-left"
          >
            <div className="relative aspect-video overflow-hidden rounded-xl border border-bg-line bg-bg-surface transition-colors group-hover:border-signal/60">
              {c.logo ? (
                <img src={imgUrl(c.logo)} alt="" loading="lazy" className="h-full w-full object-contain p-3" />
              ) : (
                <div className="flex h-full w-full items-center justify-center p-2 text-center text-xs text-ink-muted">
                  {c.name.slice(0, 30)}
                </div>
              )}
              <span className="absolute inset-0 flex items-center justify-center bg-black/55 opacity-0 transition-opacity group-hover:opacity-100">
                <Play className="h-8 w-8 text-white" fill="currentColor" />
              </span>
            </div>
            <p className="mt-2 truncate text-sm font-medium">{c.name}</p>
            <p className="truncate text-xs text-ink-dim">{c.group}</p>
          </button>
        ))}
      </div>
    </section>
  );
}
