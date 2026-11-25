import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { ChannelCard } from "./ChannelCard";
import type { Channel } from "../types";

const ROW_H = 72;
const GAP = 8;
const STRIDE = ROW_H + GAP;
const OVERSCAN = 6;

interface Props {
  channels: Channel[];
  favSet: Set<string>;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
  emptyText?: string;
}

/**
 * Grid virtualizado sin dependencias: solo monta las filas visibles.
 * Soporta 100.000+ entradas manteniendo el scroll natural de la pagina.
 */
export function ChannelGrid({
  channels, favSet, onToggleFavorite, onPlay, emptyText = "No se encontraron resultados.",
}: Props) {
  const wrapRef = useRef<HTMLDivElement | null>(null);
  const rafRef = useRef<number | null>(null);
  const [cols, setCols] = useState(2);
  const [range, setRange] = useState({ start: 0, end: 24 });

  const rows = Math.ceil(channels.length / cols);

  const recompute = useCallback(() => {
    const el = wrapRef.current;
    if (!el) return;
    const top = -el.getBoundingClientRect().top;
    const vh = window.innerHeight || 800;
    const total = Math.ceil(channels.length / cols);
    const start = Math.max(0, Math.floor(top / STRIDE) - OVERSCAN);
    const end = Math.min(total, Math.ceil((top + vh) / STRIDE) + OVERSCAN);
    setRange((r) => (r.start === start && r.end === end ? r : { start, end }));
  }, [channels.length, cols]);

  useLayoutEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const measure = () => {
      const w = el.clientWidth;
      setCols(w >= 1180 ? 3 : w >= 700 ? 2 : 1);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  useEffect(() => {
    const schedule = () => {
      if (rafRef.current != null) return;
      rafRef.current = window.requestAnimationFrame(() => {
        rafRef.current = null;
        recompute();
      });
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

  if (channels.length === 0) {
    return <p className="py-14 text-center text-ink-muted">{emptyText}</p>;
  }

  const slice = channels.slice(range.start * cols, range.end * cols);

  return (
    <div ref={wrapRef} style={{ height: Math.max(0, rows * STRIDE - GAP), position: "relative" }} aria-label={`${channels.length} elementos`}>
      <div style={{
        position: "absolute", top: range.start * STRIDE, left: 0, right: 0,
        display: "grid", gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: GAP,
      }}>
        {slice.map((c, i) => (
          <ChannelCard key={c.id} channel={c} index={range.start * cols + i}
            isFavorite={favSet.has(c.id)} onToggleFavorite={onToggleFavorite} onPlay={onPlay} />
        ))}
      </div>
    </div>
  );
}
