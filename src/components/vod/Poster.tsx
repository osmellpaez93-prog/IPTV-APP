import { memo, useState } from "react";
import { Play, Star, Check } from "lucide-react";
import { clsx } from "clsx";
import { imgUrl } from "../../services/proxy";
import type { Channel } from "../../types";

interface Props {
  item: Channel;
  onOpen: (c: Channel) => void;
  width: number;
  progress?: number;
  fav?: boolean;
  onFav?: (id: string) => void;
}

function Base({ item, onOpen, width, progress, fav, onFav }: Props) {
  const [bad, setBad] = useState(false);
  const src = imgUrl(item.logo);
  return (
    <div className="shrink-0" style={{ width }}>
      <button
        data-sbfocus="1"
        onClick={() => onOpen(item)}
        title={item.name}
        className="sb-poster group relative block w-full overflow-hidden rounded-xl border border-[#22304a] bg-[#0d1320] text-left"
      >
        <div className="relative aspect-[2/3] w-full overflow-hidden bg-gradient-to-br from-[#141d2e] to-[#070a12]">
          {src && !bad ? (
            <img src={src} alt="" loading="lazy" decoding="async" onError={() => setBad(true)} className="h-full w-full object-cover" />
          ) : (
            <div className="flex h-full w-full items-center justify-center p-3 text-center text-xs font-semibold text-[#5d6d88]">
              {item.name.slice(0, 46)}
            </div>
          )}

          <div className="absolute inset-0 bg-gradient-to-t from-[#070a12] via-transparent to-transparent opacity-0 transition-opacity group-hover:opacity-100" />
          <div className="absolute inset-0 flex items-center justify-center opacity-0 transition-opacity group-hover:opacity-100">
            <span className="flex h-12 w-12 items-center justify-center rounded-full bg-white/95 shadow-lg">
              <Play className="h-5 w-5 text-black" fill="currentColor" />
            </span>
          </div>

          {item.rating && (
            <span className="sb-tnum absolute left-2 top-2 flex items-center gap-1 rounded-md bg-black/75 px-1.5 py-0.5 text-[10px] font-bold text-[#ffb020]">
              <Star className="h-2.5 w-2.5" fill="currentColor" /> {item.rating}
            </span>
          )}
          {fav && (
            <span className="absolute right-2 top-2 flex h-5 w-5 items-center justify-center rounded-full bg-[#4c8dff]">
              <Check className="h-3 w-3 text-white" />
            </span>
          )}
          {progress != null && progress > 0 && (
            <span className="absolute inset-x-0 bottom-0 h-1 bg-black/70">
              <span className="block h-full bg-gradient-to-r from-[#4c8dff] to-[#38bdf8]" style={{ width: `${Math.min(100, progress)}%` }} />
            </span>
          )}
        </div>
      </button>

      <div className="mt-2 flex items-start gap-1">
        <p className="min-w-0 flex-1 truncate text-[13px] font-medium">{item.name}</p>
        {onFav && (
          <button onClick={() => onFav(item.id)} className="shrink-0 rounded p-0.5 hover:bg-white/10" aria-label="Favorito">
            <Star className={clsx("h-3.5 w-3.5", fav ? "fill-[#ffb020] text-[#ffb020]" : "text-[#5d6d88]")} />
          </button>
        )}
      </div>
      <p className="truncate text-[11px] text-[#5d6d88]">{item.group}</p>
    </div>
  );
}

export const Poster = memo(Base);
