import { memo, useState } from "react";
import { clsx } from "clsx";
import { Star, Play } from "lucide-react";
import type { Channel } from "../types";
import { imgUrl } from "../services/proxy";

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

  return (
    <div
      data-focusable="true" tabIndex={0} role="button" title={channel.name}
      aria-label={`Reproducir ${channel.name}`}
      onClick={() => onPlay(channel)}
      onKeyDown={(e) => {
        if (e.target !== e.currentTarget) return;
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onPlay(channel); }
      }}
      className="group relative flex h-[72px] items-center gap-3 rounded-xl border border-white/5 bg-bg-card px-3 hover:border-brand/40 hover:bg-bg-hover cursor-pointer"
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
          {channel.group || "Sin categoria"}
        </p>
      </div>

      <button
        onClick={(e) => { e.stopPropagation(); onToggleFavorite(channel.id); }}
        className="rounded-full p-2 hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-brand"
        aria-label={isFavorite ? "Quitar de favoritos" : "Anadir a favoritos"}
      >
        <Star className={clsx("h-5 w-5", isFavorite ? "fill-gold text-gold" : "text-ink-dim")} />
      </button>
    </div>
  );
}

export const ChannelCard = memo(CardBase);
