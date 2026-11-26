import { memo, useState } from "react";
import { clsx } from "clsx";
import { Star, Play, LayoutGrid } from "lucide-react";
import type { Channel } from "../types";
import { imgUrl } from "../services/proxy";
import { ROW_HEIGHT, useStore } from "../store";

interface Props {
  channel: Channel;
  isFavorite: boolean;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
  index?: number;
  playing?: boolean;
}

const TONE: Record<Channel["category"], string> = {
  live: "text-brand",
  movies: "text-gold",
  series: "text-iris",
  other: "text-signal",
};

function CardBase({ channel, isFavorite, onToggleFavorite, onPlay, index, playing }: Props) {
  const [imgError, setImgError] = useState(false);
  const density = useStore((s) => s.ui.density);
  const addMultiview = useStore((s) => s.addMultiview);
  const logo = imgUrl(channel.logo);
  const h = ROW_HEIGHT[density];
  const thumb = density === "compact" ? 36 : density === "comfy" ? 60 : 48;

  return (
    <div
      data-focusable="true"
      tabIndex={0}
      role="button"
      title={channel.name}
      aria-label={`Reproducir ${channel.name}`}
      onClick={() => onPlay(channel)}
      onKeyDown={(e) => {
        if (e.target !== e.currentTarget) return;
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onPlay(channel); }
      }}
      style={{ height: h }}
      className={clsx(
        "group relative flex items-center gap-3 rounded-xl border px-3 cursor-pointer",
        playing
          ? "border-signal/60 bg-signal/10"
          : "border-white/5 bg-bg-surface hover:border-signal/40 hover:bg-bg-raised"
      )}
    >
      <div
        style={{ width: thumb, height: thumb }}
        className="relative shrink-0 overflow-hidden rounded-lg bg-bg-deep ring-1 ring-white/5"
      >
        {logo && !imgError ? (
          <img src={logo} alt="" loading="lazy" decoding="async"
            onError={() => setImgError(true)} className="h-full w-full object-contain p-1" />
        ) : (
          <span className="flex h-full w-full items-center justify-center text-[11px] font-bold text-ink-dim">
            {channel.name.replace(/[^\p{L}\p{N}]/gu, "").slice(0, 2).toUpperCase() || "TV"}
          </span>
        )}
        <span className="absolute inset-0 flex items-center justify-center bg-black/60 opacity-0 transition-opacity group-hover:opacity-100">
          <Play className="h-4 w-4 text-white" fill="currentColor" />
        </span>
      </div>

      <div className="min-w-0 flex-1">
        <p className={clsx("truncate font-semibold leading-tight", density === "compact" ? "text-[13px]" : "text-sm")}>
          {channel.name}
        </p>
        {density !== "compact" && (
          <p className="mt-0.5 truncate text-xs text-ink-muted">
            {index != null && <span className={clsx("font-mono", TONE[channel.category])}>{index + 1} Â· </span>}
            {channel.group || "Sin categoria"}
          </p>
        )}
      </div>

      {playing && (
        <span className="hidden items-center gap-1 rounded-full bg-brand/20 px-2 py-0.5 text-[10px] font-bold text-brand sm:flex">
          <span className="h-1.5 w-1.5 animate-live-dot rounded-full bg-brand" /> AL AIRE
        </span>
      )}

      {channel.category === "live" && (
        <button
          onClick={(e) => { e.stopPropagation(); addMultiview(channel); }}
          className="hidden rounded-full p-2 text-ink-dim hover:bg-white/10 hover:text-signal sm:block"
          aria-label="Anadir a multivision"
          title="Anadir a multivision"
        >
          <LayoutGrid className="h-4 w-4" />
        </button>
      )}

      <button
        onClick={(e) => { e.stopPropagation(); onToggleFavorite(channel.id); }}
        className="rounded-full p-2 hover:bg-white/10"
        aria-label={isFavorite ? "Quitar de favoritos" : "Anadir a favoritos"}
      >
        <Star className={clsx("h-5 w-5", isFavorite ? "fill-gold text-gold" : "text-ink-dim")} />
      </button>
    </div>
  );
}

export const ChannelCard = memo(CardBase);
