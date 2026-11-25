import { useEffect, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Play, X, Loader2 } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { useStore } from "../store";
import { getSeriesInfo, episodeUrl, type SeriesInfo, type Episode } from "../services/xtream/client";
import { imgUrl } from "../services/proxy";

export function SeriesDetail() {
  const { openSeries, closeSeries, setNowPlaying } = useStore();
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
      .catch((e) => {
        if (!cancelled) setError(e?.message || "No se pudo cargar la serie.");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [openSeries?.id, playlist?.id]);

  useEffect(() => {
    if (!openSeries) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeSeries();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [openSeries?.id]);

  if (!openSeries) return null;

  const seasons = info ? Object.keys(info.seasons).map(Number).sort((a, b) => a - b) : [];
  const episodes: Episode[] = info && season != null ? info.seasons[season] ?? [] : [];
  const cover = imgUrl(info?.cover || openSeries.logo);

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
    <div className="fixed inset-0 z-50 bg-black/70 flex items-end sm:items-center justify-center p-0 sm:p-6" onClick={closeSeries}>
      <div
        className="bg-bg-soft w-full sm:max-w-3xl max-h-[92vh] overflow-y-auto rounded-t-2xl sm:rounded-2xl border border-white/10"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex gap-4 p-5">
          {cover && <img src={cover} alt="" className="w-24 sm:w-32 aspect-[2/3] object-cover rounded-lg bg-bg-card shrink-0" />}
          <div className="flex-1 min-w-0">
            <div className="flex items-start gap-2">
              <h2 className="text-xl sm:text-2xl font-bold flex-1">{openSeries.name}</h2>
              <button onClick={closeSeries} className="p-2 rounded-full hover:bg-white/10" aria-label="Cerrar">
                <X className="w-5 h-5" />
              </button>
            </div>
            {openSeries.rating && <p className="text-xs text-brand font-semibold mt-1">★ {openSeries.rating}</p>}
            <p className="text-sm text-ink-muted mt-2 line-clamp-5">{info?.plot || openSeries.plot || ""}</p>
          </div>
        </div>

        <div className="px-5 pb-5 space-y-3">
          {loading && (
            <div className="flex items-center gap-2 text-ink-muted py-6 justify-center">
              <Loader2 className="w-5 h-5 animate-spin" /> Cargando episodios...
            </div>
          )}
          {error && <p className="text-brand text-sm py-4">{error}</p>}
          {info && seasons.length === 0 && <p className="text-ink-muted text-sm py-4">Esta serie no tiene episodios disponibles.</p>}

          {seasons.length > 0 && (
            <div className="flex gap-2 overflow-x-auto pb-1">
              {seasons.map((n) => (
                <button
                  key={n}
                  onClick={() => setSeason(n)}
                  className={clsx(
                    "px-3 py-1.5 rounded-lg text-sm font-semibold shrink-0 focus-visible:ring-2 focus-visible:ring-brand",
                    season === n ? "bg-brand text-white" : "bg-bg-card hover:bg-bg-hover"
                  )}
                >
                  Temporada {n}
                </button>
              ))}
            </div>
          )}

          <div className="space-y-1">
            {episodes.map((ep) => (
              <button
                key={ep.id}
                data-focusable="true"
                onClick={() => play(ep)}
                className="w-full flex items-center gap-3 p-3 rounded-lg bg-bg-card hover:bg-bg-hover text-left"
              >
                <span className="w-8 text-center text-ink-muted text-sm shrink-0">{ep.num}</span>
                <span className="flex-1 min-w-0">
                  <span className="block font-medium truncate">{ep.title}</span>
                  {ep.duration && <span className="block text-xs text-ink-muted">{ep.duration}</span>}
                </span>
                <Play className="w-4 h-4 text-brand shrink-0" fill="currentColor" />
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
