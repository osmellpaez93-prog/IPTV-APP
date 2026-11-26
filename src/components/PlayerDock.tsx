import { useEffect, useRef, useState } from "react";
import { clsx } from "clsx";
import { Player } from "./Player";
import { ChannelRail } from "./ChannelRail";
import { Multiview } from "./Multiview";
import { useStore } from "../store";

const SIZES = { s: 260, m: 360, l: 480 } as const;
const MARGIN = 16;

/**
 * El reproductor vive aqui, fuera del flujo del documento.
 * Nada de lo que se reproduce empuja o desplaza la lista de fondo.
 */
export function PlayerDock() {
  const nowPlaying = useStore((s) => s.nowPlaying);
  const setNowPlaying = useStore((s) => s.setNowPlaying);
  const viewMode = useStore((s) => s.viewMode);
  const setViewMode = useStore((s) => s.setViewMode);
  const mini = useStore((s) => s.mini);
  const queue = useStore((s) => s.queue);
  const zap = useStore((s) => s.zap);
  const zapTo = useStore((s) => s.zapTo);
  const multiview = useStore((s) => s.multiview);

  const [rail, setRail] = useState(true);
  const [drag, setDrag] = useState<{ x: number; y: number } | null>(null);
  const dragRef = useRef<{ dx: number; dy: number } | null>(null);

  const overlay = viewMode === "theater" || viewMode === "full";

  // Bloquea el scroll de fondo en teatro sin perder la posicion.
  useEffect(() => {
    if (!overlay) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = prev; };
  }, [overlay]);

  useEffect(() => { if (!overlay) setDrag(null); }, [overlay]);

  useEffect(() => {
    if (viewMode !== "full") return;
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape" && !document.fullscreenElement) setViewMode("theater"); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [viewMode, setViewMode]);

  if (multiview.length > 0) return <Multiview />;
  if (!nowPlaying) return null;

  const index = queue.findIndex((c) => c.id === nowPlaying.id);
  const canZap = index >= 0 && queue.length > 1;
  const close = () => { setNowPlaying(null); setViewMode("mini"); };

  const player = (
    <Player
      channel={nowPlaying}
      mode={viewMode}
      onClose={close}
      onMode={setViewMode}
      onPrev={canZap ? () => zap(-1) : undefined}
      onNext={canZap ? () => zap(1) : undefined}
      onJump={canZap ? (i) => zapTo(i) : undefined}
      position={canZap ? { index, total: queue.length } : undefined}
      railOpen={rail}
      onToggleRail={() => setRail((v) => !v)}
    />
  );

  if (overlay) {
    return (
      <div data-nav-lock="player-overlay" className="fixed inset-0 z-[60] flex animate-fade-in bg-bg-deep">
        <div className="min-w-0 flex-1">{player}</div>
        {viewMode === "theater" && rail && (
          <aside className="hidden w-[330px] shrink-0 lg:block">
            <ChannelRail onClose={() => setRail(false)} />
          </aside>
        )}
      </div>
    );
  }

  // ---- Mini flotante ----
  const w = SIZES[mini.size];
  const h = Math.round((w * 9) / 16);
  const pos = drag
    ? { left: drag.x, top: drag.y }
    : {
        left: mini.corner === "tl" || mini.corner === "bl" ? MARGIN : undefined,
        right: mini.corner === "tr" || mini.corner === "br" ? MARGIN : undefined,
        top: mini.corner === "tl" || mini.corner === "tr" ? 76 : undefined,
        bottom: mini.corner === "bl" || mini.corner === "br" ? MARGIN + 56 : undefined,
      };

  const onPointerDown = (e: React.PointerEvent) => {
    const el = e.currentTarget.parentElement as HTMLElement;
    const r = el.getBoundingClientRect();
    dragRef.current = { dx: e.clientX - r.left, dy: e.clientY - r.top };
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    setDrag({ x: r.left, y: r.top });
  };
  const onPointerMove = (e: React.PointerEvent) => {
    if (!dragRef.current) return;
    const maxX = window.innerWidth - w - 8;
    const maxY = window.innerHeight - h - 8;
    setDrag({
      x: Math.max(8, Math.min(maxX, e.clientX - dragRef.current.dx)),
      y: Math.max(8, Math.min(maxY, e.clientY - dragRef.current.dy)),
    });
  };
  const onPointerUp = (e: React.PointerEvent) => {
    dragRef.current = null;
    try { (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId); } catch {}
  };

  return (
    <div
      style={{ ...pos, width: w, height: h, opacity: mini.opacity / 100 }}
      className={clsx(
        "fixed z-50 animate-pop-in overflow-hidden rounded-xl shadow-dock transition-opacity hover:!opacity-100",
        "ring-1 ring-bg-line"
      )}
    >
      <div
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        className="absolute inset-x-0 top-0 z-10 h-6 cursor-grab active:cursor-grabbing"
        title="Arrastra para mover el reproductor"
      />
      {player}
    </div>
  );
}
