import { useEffect, useState } from "react";
import { Play, Star, CalendarClock } from "lucide-react";
import { clsx } from "clsx";
import { imgUrl } from "../../services/proxy";
import { getProgrammes, nowNext, hhmm, type Programme } from "../../services/epg/guide";
import type { Channel } from "../../types";

interface Props {
  channel: Channel | null;
  isFav: boolean;
  onFav: (id: string) => void;
  onPlay: (c: Channel) => void;
}

export function ChannelPreview({ channel, isFav, onFav, onPlay }: Props) {
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

  if (!channel) {
    return (
      <div className="flex h-[132px] items-center justify-center border-b border-[#22304a] bg-[#0d1320] text-sm text-[#5d6d88]">
        Selecciona un canal de la guia
      </div>
    );
  }

  const { now, next } = nowNext(items, tick);
  const pct = now ? Math.min(100, Math.max(0, ((tick - now.start) / (now.end - now.start)) * 100)) : 0;
  const logo = imgUrl(channel.logo);

  return (
    <div className="flex h-[132px] shrink-0 items-stretch gap-4 border-b border-[#22304a] bg-[#0d1320] p-3">
      <button
        data-sbfocus="1"
        onClick={() => onPlay(channel)}
        className="group relative aspect-video h-full shrink-0 overflow-hidden rounded-lg border border-[#22304a] bg-black"
        aria-label={`Reproducir ${channel.name}`}
      >
        {logo && !imgBad ? (
          <img src={logo} alt="" onError={() => setImgBad(true)} className="h-full w-full object-contain p-3 opacity-80" />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-[#141d2e] to-[#070a12] text-xs text-[#5d6d88]">
            {channel.name.slice(0, 22)}
          </div>
        )}
        <span className="absolute inset-0 flex items-center justify-center bg-black/55 opacity-0 transition-opacity group-hover:opacity-100">
          <span className="flex h-11 w-11 items-center justify-center rounded-full bg-[#4c8dff]">
            <Play className="h-5 w-5 text-white" fill="currentColor" />
          </span>
        </span>
      </button>

      <div className="flex min-w-0 flex-1 flex-col justify-center gap-1">
        <div className="flex items-start gap-2">
          <h3 className="min-w-0 flex-1 truncate text-lg font-bold">{channel.name}</h3>
          <button
            onClick={() => onFav(channel.id)}
            className="rounded-lg p-1.5 hover:bg-[#141d2e]"
            aria-label={isFav ? "Quitar de favoritos" : "Anadir a favoritos"}
          >
            <Star className={clsx("h-4 w-4", isFav ? "fill-[#ffb020] text-[#ffb020]" : "text-[#5d6d88]")} />
          </button>
        </div>
        <p className="truncate text-xs text-[#5d6d88]">{channel.group}</p>

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
                <span className="text-[#5d6d88]">A continuacion {hhmm(next.start)}:</span> {next.title}
              </p>
            )}
          </div>
        ) : (
          <p className="mt-1 flex items-center gap-1.5 text-xs text-[#5d6d88]">
            <CalendarClock className="h-3.5 w-3.5" /> Sin guia para este canal
          </p>
        )}
      </div>
    </div>
  );
}
