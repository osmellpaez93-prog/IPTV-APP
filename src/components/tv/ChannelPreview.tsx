import { useEffect, useState } from "react";
import { Play, Star, CalendarClock, Maximize2 } from "lucide-react";
import { clsx } from "clsx";
import { imgUrl } from "../../services/proxy";
import { getProgrammes, nowNext, hhmm, type Programme } from "../../services/epg/guide";
import { useStore } from "../../store";
import type { Channel } from "../../types";

interface Props {
  channel: Channel | null;
  isFav: boolean;
  onFav: (id: string) => void;
  /** Un clic: reproduce en esta miniatura. */
  onStart: (c: Channel) => void;
  /** Segundo clic o botón: amplía a modo teatro. */
  onExpand: (c: Channel) => void;
}

/**
 * Miniatura superior de la guía. El reproductor se "enchufa" aquí (PlayerDock lo
 * dibuja dentro de este hueco) para poder moverte por la guía sin perder el canal.
 */
export function ChannelPreview({ channel, isFav, onFav, onStart, onExpand }: Props) {
  const nowPlaying = useStore((s) => s.nowPlaying);
  const viewMode = useStore((s) => s.viewMode);
  const setInlineSlot = useStore((s) => s.setInlineSlot);

  const [items, setItems] = useState<Programme[]>([]);
  const [tick, setTick] = useState(Date.now());
  const [imgBad, setImgBad] = useState(false);

  useEffect(() => {
    setImgBad(false);
    setItems([]);
    if (!channel) return;
    let alive = true;
    getProgrammes(channel, 6).then((r) => { if (alive) setItems(r); });
    return () => { alive = false; };
  }, [channel?.id]);

  useEffect(() => {
    const t = window.setInterval(() => setTick(Date.now()), 30000);
    return () => window.clearInterval(t);
  }, []);

  const inline = !!nowPlaying && viewMode === "inline";
  const sameChannel = !!channel && !!nowPlaying && nowPlaying.id === channel.id;
  const { now, next } = nowNext(items, tick);
  const pct = now ? Math.min(100, Math.max(0, ((tick - now.start) / (now.end - now.start)) * 100)) : 0;
  const logo = imgUrl(channel?.logo);

  return (
    <div className="flex h-[172px] shrink-0 items-stretch gap-4 border-b border-[#22304a] bg-[#0d1320] p-3">
      {/* Hueco de vídeo */}
      <div className="relative aspect-video h-full shrink-0 overflow-hidden rounded-lg border border-[#22304a] bg-black">
        <div ref={setInlineSlot} className="absolute inset-0" />

        {!inline && (
          <button
            data-sbfocus="1"
            disabled={!channel}
            onClick={() => channel && onStart(channel)}
            className="group absolute inset-0"
            aria-label={channel ? `Reproducir ${channel.name}` : "Sin canal"}
          >
            {logo && !imgBad ? (
              <img src={logo} alt="" onError={() => setImgBad(true)} className="h-full w-full object-contain p-4 opacity-80" />
            ) : (
              <span className="flex h-full w-full items-center justify-center bg-gradient-to-br from-[#141d2e] to-[#070a12] px-3 text-center text-xs text-[#5d6d88]">
                {channel ? channel.name.slice(0, 26) : "Elige un canal"}
              </span>
            )}
            {channel && (
              <span className="absolute inset-0 flex items-center justify-center bg-black/45 opacity-0 transition-opacity group-hover:opacity-100">
                <span className="flex h-12 w-12 items-center justify-center rounded-full bg-[#4c8dff]">
                  <Play className="h-5 w-5 text-white" fill="currentColor" />
                </span>
              </span>
            )}
          </button>
        )}

        {inline && channel && (
          <button
            onClick={() => onExpand(nowPlaying!)}
            className="absolute bottom-2 right-2 z-30 flex items-center gap-1 rounded-md bg-black/70 px-2 py-1 text-[11px] font-semibold text-white hover:bg-[#4c8dff]"
            title="Ampliar (modo teatro)"
            aria-label="Ampliar reproductor"
          >
            <Maximize2 className="h-3.5 w-3.5" /> Ampliar
          </button>
        )}
      </div>

      {/* Información del canal seleccionado */}
      <div className="flex min-w-0 flex-1 flex-col justify-center gap-1">
        {!channel ? (
          <p className="text-sm text-[#5d6d88]">Selecciona un canal de la guía</p>
        ) : (
          <>
            <div className="flex items-start gap-2">
              <h3 className="min-w-0 flex-1 truncate text-lg font-bold">{channel.name}</h3>
              <button
                onClick={() => onFav(channel.id)}
                className="rounded-lg p-1.5 hover:bg-[#141d2e]"
                aria-label={isFav ? "Quitar de favoritos" : "Añadir a favoritos"}
              >
                <Star className={clsx("h-4 w-4", isFav ? "fill-[#ffb020] text-[#ffb020]" : "text-[#5d6d88]")} />
              </button>
            </div>
            <p className="truncate text-xs text-[#5d6d88]">
              {channel.group}
              {" · "}
              {sameChannel && inline ? "Clic de nuevo para ampliar" : "Clic para ver aquí · doble clic para ampliar"}
            </p>

            {inline && nowPlaying && !sameChannel && (
              <p className="truncate text-xs text-[#38bdf8]">Reproduciendo: {nowPlaying.name}</p>
            )}

            {now ? (
              <div className="mt-1 space-y-1">
                <div className="flex items-baseline gap-2">
                  <span className="flex items-center gap-1 rounded bg-[#ff2d55]/15 px-1.5 py-0.5 text-[10px] font-bold uppercase text-[#ff2d55]">
                    <span className="sb-pulse h-1.5 w-1.5 rounded-full bg-[#ff2d55]" /> Ahora
                  </span>
                  <span className="min-w-0 flex-1 truncate text-sm font-semibold">{now.title}</span>
                  <span className="sb-tnum shrink-0 text-xs text-[#93a3bd]">{hhmm(now.start)} - {hhmm(now.end)}</span>
                </div>
                <div className="h-1 w-full overflow-hidden rounded-full bg-[#22304a]">
                  <div className="h-full rounded-full bg-gradient-to-r from-[#4c8dff] to-[#38bdf8]" style={{ width: `${pct}%` }} />
                </div>
                {next && (
                  <p className="truncate text-xs text-[#93a3bd]">
                    <span className="text-[#5d6d88]">A continuación {hhmm(next.start)}:</span> {next.title}
                  </p>
                )}
              </div>
            ) : (
              <p className="mt-1 flex items-center gap-1.5 text-xs text-[#5d6d88]">
                <CalendarClock className="h-3.5 w-3.5" /> Sin guía para este canal
              </p>
            )}
          </>
        )}
      </div>
    </div>
  );
}
