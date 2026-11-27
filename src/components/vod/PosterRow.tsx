import { useRef, useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { Poster } from "./Poster";
import type { Channel } from "../../types";

interface Props {
  title: string;
  accent?: string;
  items: Channel[];
  onOpen: (c: Channel) => void;
  width?: number;
  favSet?: Set<string>;
  onFav?: (id: string) => void;
  progressOf?: (id: string) => number | undefined;
  onSeeAll?: () => void;
}

export function PosterRow({ title, accent = "#4c8dff", items, onOpen, width = 158, favSet, onFav, progressOf, onSeeAll }: Props) {
  const ref = useRef<HTMLDivElement | null>(null);
  const [hover, setHover] = useState(false);
  if (items.length === 0) return null;

  const step = () => Math.max(320, (ref.current?.clientWidth ?? 600) - 120);
  const go = (dir: number) => ref.current?.scrollBy({ left: dir * step(), behavior: "smooth" });

  return (
    <section className="sb-in" onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}>
      <div className="mb-2.5 flex items-baseline gap-3 px-1">
        <h2 className="text-lg font-bold tracking-tight">{title}</h2>
        <span className="sb-tnum text-[11px] font-semibold uppercase tracking-widest" style={{ color: accent }}>
          {items.length}
        </span>
        <div className="flex-1" />
        {onSeeAll && (
          <button onClick={onSeeAll} className="text-xs font-semibold text-[#93a3bd] hover:text-white">
            Ver todo
          </button>
        )}
      </div>

      <div className="relative">
        <div ref={ref} className="sb-noscroll flex gap-3 overflow-x-auto px-1 pb-3 pt-1">
          {items.map((it) => (
            <Poster
              key={it.id}
              item={it}
              onOpen={onOpen}
              width={width}
              fav={favSet?.has(it.id)}
              onFav={onFav}
              progress={progressOf?.(it.id)}
            />
          ))}
        </div>

        {hover && items.length > 3 && (
          <>
            <button
              onClick={() => go(-1)}
              className="absolute left-0 top-0 z-30 flex h-[calc(100%-3rem)] w-10 items-center justify-center rounded-l-xl sb-fade-l"
              aria-label="Anterior"
            >
              <ChevronLeft className="h-7 w-7 text-white drop-shadow" />
            </button>
            <button
              onClick={() => go(1)}
              className="absolute right-0 top-0 z-30 flex h-[calc(100%-3rem)] w-10 items-center justify-center rounded-r-xl sb-fade-r"
              aria-label="Siguiente"
            >
              <ChevronRight className="h-7 w-7 text-white drop-shadow" />
            </button>
          </>
        )}
      </div>
    </section>
  );
}
