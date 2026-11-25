import { Play, X } from "lucide-react";
import { useContinueWatching, useRemoveResume } from "../hooks/useHistory";
import { useStore } from "../store";
import { imgUrl } from "../services/proxy";

function left(min: number) {
  const m = Math.max(1, Math.round(min));
  if (m < 60) return `${m} min restantes`;
  return `${Math.floor(m / 60)} h ${m % 60} min restantes`;
}

export function ContinueWatching() {
  const items = useContinueWatching();
  const remove = useRemoveResume();
  const setNowPlaying = useStore((s) => s.setNowPlaying);
  const setActivePlaylistId = useStore((s) => s.setActivePlaylistId);

  if (items.length === 0) return null;

  return (
    <section className="animate-slide-up">
      <div className="mb-3 flex items-baseline gap-3">
        <h2 className="text-xl font-bold">Continuar viendo</h2>
        <span className="text-xs font-semibold uppercase tracking-widest text-aqua">Retoma donde lo dejaste</span>
      </div>

      <div className="no-scrollbar -mx-1 flex snap-x gap-3 overflow-x-auto px-1 pb-2">
        {items.map(({ channel, history, percent }) => {
          const poster = imgUrl(channel.logo);
          return (
            <div key={channel.id} className="group relative w-[168px] shrink-0 snap-start">
              <button
                data-focusable="true"
                onClick={() => {
                  if (channel.playlistId) setActivePlaylistId(channel.playlistId);
                  setNowPlaying(channel);
                }}
                className="block w-full overflow-hidden rounded-xl border border-white/5 bg-bg-card text-left hover:border-aqua/50"
              >
                <div className="relative aspect-video w-full overflow-hidden bg-bg-deep">
                  {poster ? (
                    <img src={poster} alt="" loading="lazy" className="h-full w-full object-contain p-3" />
                  ) : (
                    <span className="flex h-full w-full items-center justify-center px-3 text-center text-xs text-ink-dim">{channel.name.slice(0, 40)}</span>
                  )}
                  <span className="absolute inset-0 flex items-center justify-center bg-black/55 opacity-0 transition-opacity group-hover:opacity-100">
                    <Play className="h-8 w-8 text-white" fill="currentColor" />
                  </span>
                  <span className="absolute inset-x-0 bottom-0 h-1 bg-black/70">
                    <span className="block h-full bg-gradient-to-r from-aqua to-iris" style={{ width: `${percent}%` }} />
                  </span>
                </div>
                <div className="p-2.5">
                  <p className="truncate text-sm font-semibold">{channel.name}</p>
                  <p className="mt-0.5 text-[11px] text-ink-muted">{left((history.duration - history.position) / 60)}</p>
                </div>
              </button>

              <button
                onClick={() => remove(channel.id)}
                aria-label={`Quitar ${channel.name} de continuar viendo`}
                className="absolute right-1.5 top-1.5 rounded-full bg-black/70 p-1.5 opacity-0 transition-opacity hover:bg-danger focus-visible:opacity-100 group-hover:opacity-100"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          );
        })}
      </div>
    </section>
  );
}
