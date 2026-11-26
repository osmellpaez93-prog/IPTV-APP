import { useEffect, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Play, X, Loader2 } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { useStore } from "../store";
import { useMeta } from "../hooks/useMeta";
import { getSeriesInfo, episodeUrl, type SeriesInfo, type Episode } from "../services/xtream/client";
import { imgUrl } from "../services/proxy";

export function SeriesDetail() {
  const openSeries = useStore((s) => s.openSeries);
  const closeSeries = useStore((s) => s.closeSeries);
  const setNowPlaying = useStore((s) => s.setNowPlaying);
  const { meta } = useMeta(openSeries);
  const playlist = useLiveQuery(
    () => (openSeries ? db.playlists.get(openSeries.playlistId) : undefined),
    [openSeries?.playlistId]
  );
  const [info, setInfo] = useState<SeriesInfo | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [season, setSeason] = useState<number | null>(null);

  useEffect(() => {
    if (!openSeries || !playlist) return;
    let cancelled = false;
    setLoading(true);
    setError(null);
    setInfo(null);
    getSeriesInfo(playlist, openSeries.seriesId!)
      .then((r) => {
        if (cancelled) return;
        setInfo(r);
        const first = Object.keys(r.seasons).map(Number).sort((a, b) => a - b)[0];
        setSeason(first ?? null);
      })
      .catch((e) => { if (!cancelled) setError(e?.message || "No se pudo cargar la serie."); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [openSeries?.id, playlist?.id]);

  useEffect(() => {
    if (!openSeries) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") closeSeries(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [openSeries?.id]);

  if (!openSeries) return null;

  const seasons = info ? Object.keys(info.seasons).map(Number).sort((a, b) => a - b) : [];
  const episodes: Episode[] = info && season != null ? info.seasons[season] ?? [] : [];
  const title = meta?.title || openSeries.name;
  const poster = imgUrl(meta?.poster || info?.cover || openSeries.logo);
  const backdrop = imgUrl(meta?.backdrop);
  const overview = meta?.overview || info?.plot || openSeries.plot;
  const chips = [meta?.year, meta?.rating ? `★ ${meta.rating}` : openSeries.rating ? `★ ${openSeries.rating}` : null].filter(Boolean) as string[];

  const play = (ep: Episode) => {
    if (!playlist) return;
    setNowPlaying({
      id: `${playlist.id}:e${ep.id}`,
      playlistId: playlist.id,
      name: `${openSeries.name} · T${ep.season}E${ep.num} ${ep.title}`,
      logo: ep.image || openSeries.logo,
      group: openSeries.name,
      url: episodeUrl(playlist, ep),
      category: "series",
      streamType: "series",
    });
    closeSeries();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/75 backdrop-blur-sm sm:items-center sm:p-6" onClick={closeSeries}>
      <div
        className="relative max-h-[94vh] w-full overflow-y-auto rounded-t-2xl border border-white/10 bg-bg-soft shadow-card sm:max-w-3xl sm:rounded-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="relative h-36 bg-bg-deep sm:h-48">
          {backdrop && <img src={backdrop} alt="" className="h-full w-full object-cover opacity-60" />}
          <div className="absolute inset-0 bg-gradient-to-t from-bg-soft via-bg-soft/40 to-transparent" />
          <button
            data-focusable="true"
            onClick={closeSeries}
            className="absolute right-3 top-3 rounded-full bg-black/60 p-2 hover:bg-black"
            aria-label="Cerrar"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="relative -mt-14 flex gap-4 px-5 sm:-mt-16">
          <div className="aspect-[2/3] w-24 shrink-0 overflow-hidden rounded-xl border border-white/10 bg-bg-card shadow-card sm:w-32">
            {poster ? <img src={poster} alt="" className="h-full w-full object-cover" /> : (
              <div className="flex h-full w-full items-center justify-center p-2 text-center text-xs text-ink-muted">{title}</div>
            )}
          </div>
          <div className="min-w-0 flex-1 pt-14 sm:pt-16">
            <h2 className="text-xl font-black leading-tight sm:text-2xl">{title}</h2>
            {chips.length > 0 && (
              <p className="mt-1 text-sm text-ink-muted">
                {chips.map((c, i) => (
                  <span key={i} className={c.startsWith("★") ? "font-semibold text-gold" : ""}>{i > 0 ? " · " : ""}{c}</span>
                ))}
              </p>
            )}
            {meta && meta.genres.length > 0 && (
              <div className="mt-2 flex flex-wrap gap-1.5">
                {meta.genres.slice(0, 4).map((g) => (
                  <span key={g} className="rounded-full border border-white/10 px-2.5 py-0.5 text-[11px] text-ink-muted">{g}</span>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="space-y-3 px-5 pb-6 pt-4">
          {overview && <p className="line-clamp-5 text-sm leading-relaxed text-ink-muted">{overview}</p>}

          {loading && (
            <div className="flex items-center justify-center gap-2 py-6 text-ink-muted">
              <Loader2 className="h-5 w-5 animate-spin" /> Cargando episodios…
            </div>
          )}
          {error && <p className="py-4 text-sm text-brand">{error}</p>}
          {info && seasons.length === 0 && <p className="py-4 text-sm text-ink-muted">Esta serie no tiene episodios disponibles.</p>}

          {seasons.length > 0 && (
            <div className="no-scrollbar flex gap-2 overflow-x-auto pb-1">
              {seasons.map((n) => (
                <button
                  key={n}
                  data-focusable="true"
                  onClick={() => setSeason(n)}
                  className={clsx(
                    "shrink-0 rounded-lg px-3 py-1.5 text-sm font-semibold",
                    season === n ? "bg-brand text-white" : "bg-bg-card hover:bg-bg-hover"
                  )}
                >
                  Temporada {n}
                </button>
              ))}
            </div>
          )}

          <div className="space-y-1">
            {episodes.map((ep, i) => (
              <button
                key={ep.id}
                data-focusable="true"
                autoFocus={i === 0}
                onClick={() => play(ep)}
                className="flex w-full items-center gap-3 rounded-lg bg-bg-card p-3 text-left hover:bg-bg-hover"
              >
                <span className="w-8 shrink-0 text-center text-sm text-ink-muted">{ep.num}</span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate font-medium">{ep.title}</span>
                  {ep.duration && <span className="block text-xs text-ink-muted">{ep.duration}</span>}
                </span>
                <Play className="h-4 w-4 shrink-0 text-brand" fill="currentColor" />
              </button>
            ))}
          </div>

          {meta?.source === "tmdb" && (
            <p className="border-t border-white/5 pt-3 text-[10px] leading-relaxed text-ink-dim">
              Información de TMDB. Esta aplicación usa la API de TMDB pero no está avalada ni certificada por TMDB.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
