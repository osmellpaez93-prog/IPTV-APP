import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { ChannelCard } from "./ChannelCard";
import { ROW_HEIGHT, useStore } from "../store";
import type { Channel } from "../types";

const GAP = 8;
const OVERSCAN = 6;

interface Props {
  channels: Channel[];
  favSet: Set<string>;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
  emptyText?: string;
}

/** Grid virtualizado sin dependencias: solo monta las filas visibles. */
export function ChannelGrid({
  channels, favSet, onToggleFavorite, onPlay, emptyText = "No se encontraron resultados.",
}: Props) {
  const wrapRef = useRef<HTMLDivElement | null>(null);
  const rafRef = useRef<number | null>(null);
  const density = useStore((s) => s.ui.density);
  const colPref = useStore((s) => s.ui.columns);
  const nowPlaying = useStore((s) => s.nowPlaying);
  const [autoCols, setAutoCols] = useState(2);
  const [range, setRange] = useState({ start: 0, end: 24 });

  const stride = ROW_HEIGHT[density] + GAP;
  const cols = colPref || autoCols;
  const rows = Math.ceil(channels.length / cols);

  const recompute = useCallback(() => {
    const el = wrapRef.current;
    if (!el) return;
    const top = -el.getBoundingClientRect().top;
    const vh = window.innerHeight || 800;
    const total = Math.ceil(channels.length / cols);
    const start = Math.max(0, Math.floor(top / stride) - OVERSCAN);
    const end = Math.min(total, Math.ceil((top + vh) / stride) + OVERSCAN);
    setRange((r) => (r.start === start && r.end === end ? r : { start, end }));
  }, [channels.length, cols, stride]);

  useLayoutEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const measure = () => {
      const w = el.clientWidth;
      setAutoCols(w >= 1180 ? 3 : w >= 700 ? 2 : 1);
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

  const slice = channels.slice(range.start * cols, range.end * cols);

  return (
    <div ref={wrapRef} style={{ height: Math.max(0, rows * stride - GAP), position: "relative" }}>
      <div
        style={{
          position: "absolute", top: range.start * stride, left: 0, right: 0,
          display: "grid", gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`, gap: GAP,
        }}
      >
        {slice.map((c, i) => (
          <ChannelCard
            key={c.id}
            channel={c}
            index={range.start * cols + i}
            playing={nowPlaying?.id === c.id}
            isFavorite={favSet.has(c.id)}
            onToggleFavorite={onToggleFavorite}
            onPlay={onPlay}
          />
        ))}
      </div>
    </div>
  );
}
