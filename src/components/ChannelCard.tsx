import { memo, useState } from "react";
import { clsx } from "clsx";
import { Star, Play } from "lucide-react";
import type { Channel } from "../types";
import { imgUrl } from "../services/proxy";
import { useEpg } from "../hooks/useEpg";

interface Props {
  channel: Channel;
  isFavorite: boolean;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
  index?: number;
}

const TONE: Record<Channel["category"], string> = {
  live: "text-brand", movies: "text-gold", series: "text-iris", other: "text-aqua",
};

function CardBase({ channel, isFavorite, onToggleFavorite, onPlay, index }: Props) {
  const [imgError, setImgError] = useState(false);
  const logo = imgUrl(channel.logo);
  // Solo canales en vivo; espera 400 ms para no pedir la guía mientras se hace scroll rápido
  const { current, now } = useEpg(channel.category === "live" ? channel : null, 400);
  const pct = current ? Math.min(100, Math.max(0, ((now - current.start) / (current.end - current.start)) * 100)) : 0;

  return (
    <div
      data-focusable="true" tabIndex={0} role="button" title={channel.name}
      aria-label={`Reproducir ${channel.name}`}
      onClick={() => onPlay(channel)}
      onKeyDown={(e) => {
        if (e.target !== e.currentTarget) return;
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onPlay(channel); }
      }}
      className="group relative flex h-[72px] cursor-pointer items-center gap-3 overflow-hidden rounded-xl border border-white/5 bg-bg-card px-3 hover:border-brand/40 hover:bg-bg-hover"
    >
      <div className="relative h-12 w-12 shrink-0 overflow-hidden rounded-lg bg-bg-deep ring-1 ring-white/5">
        {logo && !imgError ? (
          <img src={logo} alt="" loading="lazy" decoding="async" onError={() => setImgError(true)} className="h-full w-full object-contain p-1" />
        ) : (
          <span className="flex h-full w-full items-center justify-center text-[11px] font-bold text-ink-dim">
            {channel.name.replace(/[^\p{L}\p{N}]/gu, "").slice(0, 2).toUpperCase() || "TV"}
          </span>
        )}
        <span className="absolute inset-0 flex items-center justify-center bg-black/60 opacity-0 transition-opacity group-hover:opacity-100">
          <Play className="h-5 w-5 text-white" fill="currentColor" />
        </span>
      </div>

      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold leading-tight">{channel.name}</p>
        <p className="mt-0.5 truncate text-xs text-ink-muted">
          {index != null && <span className={clsx("font-mono", TONE[channel.category])}>{index + 1} · </span>}
          {current ? <span className="text-ink">{current.title}</span> : channel.group || "Sin categoría"}
        </p>
      </div>

      <button
        onClick={(e) => { e.stopPropagation(); onToggleFavorite(channel.id); }}
        className="rounded-full p-2 hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-brand"
        aria-label={isFavorite ? "Quitar de favoritos" : "Añadir a favoritos"}
      >
        <Star className={clsx("h-5 w-5", isFavorite ? "fill-gold text-gold" : "text-ink-dim")} />
      </button>

      {current && (
        <span className="absolute inset-x-0 bottom-0 h-[3px] bg-white/5">
          <span className="block h-full bg-brand/80" style={{ width: `${pct}%` }} />
        </span>
      )}
    </div>
  );
}

export const ChannelCard = memo(CardBase);
