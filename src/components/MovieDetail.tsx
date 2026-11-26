import { useEffect } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Play, RotateCcw, Star, X, Loader2 } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { useStore } from "../store";
import { useMeta } from "../hooks/useMeta";
import { useFavorites } from "../hooks/useFavorites";
import { imgUrl } from "../services/proxy";

const mmss = (s: number) => {
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = Math.floor(s % 60).toString().padStart(2, "0");
  return h > 0 ? `${h}:${m.toString().padStart(2, "0")}:${sec}` : `${m}:${sec}`;
};

export function MovieDetail() {
  const openMovie = useStore((s) => s.openMovie);
  const closeMovie = useStore((s) => s.closeMovie);
  const playNow = useStore((s) => s.playNow);
  const { meta, loading } = useMeta(openMovie);
  const { favSet, toggle } = useFavorites();
  const hist = useLiveQuery(() => (openMovie ? db.history.get(openMovie.id) : undefined), [openMovie?.id]);

  useEffect(() => {
    if (!openMovie) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") closeMovie(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [openMovie?.id]);

  if (!openMovie) return null;

  const title = meta?.title || openMovie.name;
  const poster = imgUrl(meta?.poster || openMovie.logo);
  const backdrop = imgUrl(meta?.backdrop);
  const canResume = !!hist && hist.position > 30 && hist.duration > 0 && hist.position / hist.duration < 0.97;
  const isFav = favSet.has(openMovie.id);

  const chips = [meta?.year, meta?.runtime, meta?.rating ? `★ ${meta.rating}` : null].filter(Boolean) as string[];

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/75 backdrop-blur-sm sm:items-center sm:p-6" onClick={closeMovie}>
      <div
        className="relative max-h-[94vh] w-full overflow-y-auto rounded-t-2xl border border-white/10 bg-bg-soft shadow-card sm:max-w-3xl sm:rounded-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="relative h-40 bg-bg-deep sm:h-56">
          {backdrop && <img src={backdrop} alt="" className="h-full w-full object-cover opacity-60" />}
          <div className="absolute inset-0 bg-gradient-to-t from-bg-soft via-bg-soft/40 to-transparent" />
          <button
            data-focusable="true"
            onClick={closeMovie}
            className="absolute right-3 top-3 rounded-full bg-black/60 p-2 hover:bg-black"
            aria-label="Cerrar"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="relative -mt-16 flex gap-4 px-5 pb-6 sm:-mt-20">
          <div className="aspect-[2/3] w-28 shrink-0 overflow-hidden rounded-xl border border-white/10 bg-bg-card shadow-card sm:w-36">
            {poster ? (
              <img src={poster} alt="" className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full w-full items-center justify-center p-2 text-center text-xs text-ink-muted">{title}</div>
            )}
          </div>

          <div className="min-w-0 flex-1 pt-16 sm:pt-20">
            <h2 className="text-xl font-black leading-tight sm:text-3xl">{title}</h2>
            {chips.length > 0 && (
              <p className="mt-1 text-sm text-ink-muted">
                {chips.map((c, i) => (
                  <span key={i} className={c.startsWith("★") ? "font-semibold text-gold" : ""}>{i > 0 ? " · " : ""}{c}</span>
                ))}
              </p>
            )}
            {meta && meta.genres.length > 0 && (
              <div className="mt-2 flex flex-wrap gap-1.5">
                {meta.genres.slice(0, 5).map((g) => (
                  <span key={g} className="rounded-full border border-white/10 px-2.5 py-0.5 text-[11px] text-ink-muted">{g}</span>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="space-y-4 px-5 pb-6">
          <div className="flex flex-wrap gap-2">
            <button
              data-focusable="true"
              autoFocus
              onClick={() => playNow(openMovie)}
              className="flex items-center gap-2 rounded-lg bg-brand px-5 py-2.5 font-semibold hover:bg-brand-hover"
            >
              <Play className="h-5 w-5" fill="currentColor" />
              {canResume ? `Continuar desde ${mmss(hist!.position)}` : "Reproducir"}
            </button>
            {canResume && (
              <button
                data-focusable="true"
                onClick={async () => { await db.history.delete(openMovie.id); playNow(openMovie); }}
                className="flex items-center gap-2 rounded-lg bg-white/10 px-4 py-2.5 font-semibold hover:bg-white/20"
              >
                <RotateCcw className="h-4 w-4" /> Desde el principio
              </button>
            )}
            <button
              data-focusable="true"
              onClick={() => toggle(openMovie.id)}
              className="flex items-center gap-2 rounded-lg bg-white/10 px-4 py-2.5 font-semibold hover:bg-white/20"
            >
              <Star className={clsx("h-4 w-4", isFav && "fill-gold text-gold")} />
              {isFav ? "En favoritos" : "Favorito"}
            </button>
          </div>

          {loading && !meta && (
            <p className="flex items-center gap-2 text-sm text-ink-muted"><Loader2 className="h-4 w-4 animate-spin" /> Cargando información…</p>
          )}

          {meta?.overview ? (
            <p className="text-sm leading-relaxed text-ink">{meta.overview}</p>
          ) : (
            !loading && <p className="text-sm text-ink-muted">Sin sinopsis disponible. Añade tu clave de TMDB en Ajustes para completar la información.</p>
          )}

          {meta && (meta.director || meta.cast.length > 0) && (
            <dl className="space-y-1 text-sm">
              {meta.director && (
                <div className="flex gap-2"><dt className="w-20 shrink-0 text-ink-muted">Dirección</dt><dd>{meta.director}</dd></div>
              )}
              {meta.cast.length > 0 && (
                <div className="flex gap-2"><dt className="w-20 shrink-0 text-ink-muted">Reparto</dt><dd>{meta.cast.join(", ")}</dd></div>
              )}
            </dl>
          )}

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
