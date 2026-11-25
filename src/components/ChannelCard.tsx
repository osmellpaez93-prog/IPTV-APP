import { useState } from "react";
import { clsx } from "clsx";
import { Star, Play } from "lucide-react";
import type { Channel } from "../types";
import { imgUrl } from "../services/proxy";

interface Props {
  channel: Channel;
  isFavorite: boolean;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
}

export function ChannelCard({ channel, isFavorite, onToggleFavorite, onPlay }: Props) {
  const [imgError, setImgError] = useState(false);
  const logo = imgUrl(channel.logo);

  return (
    <div
      data-focusable="true"
      tabIndex={0}
      role="button"
      onClick={() => onPlay(channel)}
      onKeyDown={(e) => {
        if (e.target !== e.currentTarget) return;
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onPlay(channel);
        }
      }}
      className="group relative flex items-center gap-3 p-3 rounded-xl bg-bg-card hover:bg-bg-hover cursor-pointer transition-colors animate-fade-in"
    >
      <div className="relative w-12 h-12 rounded-lg bg-bg-soft overflow-hidden shrink-0 flex items-center justify-center">
        {logo && !imgError ? (
          <img src={logo} alt="" loading="lazy" onError={() => setImgError(true)} className="w-full h-full object-contain" />
        ) : (
          <span className="text-ink-muted text-xs font-semibold">{channel.name.slice(0, 2).toUpperCase()}</span>
        )}
        <div className="absolute inset-0 flex items-center justify-center bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity">
          <Play className="w-5 h-5 text-white" fill="white" />
        </div>
      </div>

      <div className="flex-1 min-w-0">
        <p className="font-semibold truncate">{channel.name}</p>
        <p className="text-xs text-ink-muted truncate">{channel.group}</p>
      </div>

      <button
        onClick={(e) => {
          e.stopPropagation();
          onToggleFavorite(channel.id);
        }}
        className="p-2 rounded-full hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-brand"
        aria-label={isFavorite ? "Quitar de favoritos" : "Añadir a favoritos"}
      >
        <Star className={clsx("w-5 h-5", isFavorite ? "text-brand fill-brand" : "text-ink-muted")} />
      </button>
    </div>
  );
}
