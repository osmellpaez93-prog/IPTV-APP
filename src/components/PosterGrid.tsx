import { memo, useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { Play, Star } from "lucide-react";
import { clsx } from "clsx";
import type { Channel } from "../types";
import { imgUrl } from "../services/proxy";

const GAP = 14;
const MIN_W = 148;
const TITLE_H = 56;
const OVERSCAN = 2;

interface Props {
  channels: Channel[];
  favSet: Set<string>;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
  emptyText?: string;
}

interface CardProps {
  channel: Channel;
  isFavorite: boolean;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
}

const PosterCard = memo(function PosterCard({ channel, isFavorite, onToggleFavorite, onPlay }: CardProps) {
  const [err, setErr] = useState(false);
  const src = imgUrl(channel.logo);
  const n = Number(channel.rating);
  const rating = isFinite(n) && n > 0 ? n.toFixed(1) : null;

  return (
    <div
      data-focusable="true" tabIndex={0} role="button" title={channel.name}
      aria-label={`Abrir ${channel.name}`}
      onClick={() => onPlay(channel)}
      onKeyDown={(e) => {
        if (e.target !== e.currentTarget) return;
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onPlay(channel); }
      }}
      className="group relative cursor-pointer rounded-xl"
    >
      <div className="relative aspect-[2/3] overflow-hidden rounded-xl border border-white/5 bg-bg-card shadow-card">
        {src && !err ? (
          <img src={src} alt="" loading="lazy" decoding="async" onError={() => setErr(true)} className="h-full w-full object-cover" />
        ) : (
          <div className="flex h-full w-full items-center justify-center bg-gradient-to-br from-bg-card to-bg-deep p-3 text-center text-sm font-semibold text-ink-muted">
            {channel.name}
          </div>
        )}
        <span className="absolute inset-0 flex items-center justify-center bg-black/55 opacity-0 transition-opacity group-hover:opacity-100">
          <Play className="h-10 w-10 text-white" fill="currentColor" />
        </span>
        {rating && (
          <span className="absolute left-2 top-2 rounded-md bg-black/70 px-1.5 py-0.5 text-[11px] font-bold text-gold">★ {rating}</span>
        )}
        <button
          onClick={(e) => { e.stopPropagation(); onToggleFavorite(channel.id); }}
          aria-label={isFavorite ? "Quitar de favoritos" : "Añadir a favoritos"}
          className={clsx(
            "absolute right-1.5 top-1.5 rounded-full bg-black/70 p-1.5 transition-opacity hover:bg-black focus-visible:opacity-100 group-hover:opacity-100",
            isFavorite ? "opacity-100" : "opacity-0"
          )}
        >
          <Star className={clsx("h-4 w-4", isFavorite ? "fill-gold text-gold" : "text-white")} />
        </button>
      </div>
      <div className="px-0.5 pt-2" style={{ height: TITLE_H }}>
        <p className="line-clamp-2 text-sm font-semibold leading-tight">{channel.name}</p>
        <p className="mt-0.5 truncate text-xs text-ink-muted">{channel.group || "Sin categoría"}</p>
      </div>
    </div>
  );
});

/** Rejilla de carátulas virtualizada (solo monta las filas visibles). */
export function PosterGrid({ channels, favSet, onToggleFavorite, onPlay, emptyText = "No se encontraron resultados." }: Props) {
  const wrapRef = useRef<HTMLDivElement | null>(null);
  const rafRef = useRef<number | null>(null);
  const [dims, setDims] = useState({ cols: 3, colW: 150 });
  const [range, setRange] = useState({ start: 0, end: 6 });

  const rowH = dims.colW * 1.5 + TITLE_H;
  const stride = rowH + GAP;
  const rows = Math.ceil(channels.length / dims.cols);

  const recompute = useCallback(() => {
    const el = wrapRef.current;
    if (!el) return;
    const top = -el.getBoundingClientRect().top;
    const vh = window.innerHeight || 800;
    const total = Math.ceil(channels.length / dims.cols);
    const start = Math.max(0, Math.floor(top / stride) - OVERSCAN);
    const end = Math.min(total, Math.ceil((top + vh) / stride) + OVERSCAN);
    setRange((r) => (r.start === start && r.end === end ? r : { start, end }));
  }, [channels.length, dims.cols, stride]);

  useLayoutEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const measure = () => {
      const w = el.clientWidth;
      if (w <= 0) return;
      const cols = Math.max(2, Math.floor((w + GAP) / (MIN_W + GAP)));
      const colW = (w - GAP * (cols - 1)) / cols;
      setDims((d) => (d.cols === cols && Math.abs(d.colW - colW) < 0.5 ? d : { cols, colW }));
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    const schedule = () => {
      if (rafRef.current != null) return;
      rafRef.current = window.requestAnimationFrame(() => { rafRef.current = null; recompute(); });
    };
    schedule();
    window.addEventListener("scroll", schedule, { passive: true });
    window.addEventListener("resize", schedule);
    return () => {
      window.removeEventListener("scroll", schedule);
      window.removeEventListener("resize", schedule);
      if (rafRef.current != null) window.cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    };
  }, [recompute]);

  if (channels.length === 0) return <p className="py-14 text-center text-ink-muted">{emptyText}</p>;

  const slice = channels.slice(range.start * dims.cols, range.end * dims.cols);

  return (
    <div ref={wrapRef} style={{ height: Math.max(0, rows * stride - GAP), position: "relative" }} aria-label={`${channels.length} elementos`}>
      <div style={{
        position: "absolute", top: range.start * stride, left: 0, right: 0,
        display: "grid", gridTemplateColumns: `repeat(${dims.cols}, minmax(0, 1fr))`, gap: GAP,
      }}>
        {slice.map((c) => (
          <PosterCard key={c.id} channel={c} isFavorite={favSet.has(c.id)} onToggleFavorite={onToggleFavorite} onPlay={onPlay} />
        ))}
      </div>
    </div>
  );
}
