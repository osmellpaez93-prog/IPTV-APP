import { useEffect, useState } from "react";
import { X, LayoutGrid, Volume2 } from "lucide-react";
import { clsx } from "clsx";
import { Player } from "./Player";
import { ChannelRail } from "./ChannelRail";
import { useStore } from "../store";

export function Multiview() {
  const multiview = useStore((s) => s.multiview);
  const mvActive = useStore((s) => s.mvActive);
  const setMvActive = useStore((s) => s.setMvActive);
  const removeMultiview = useStore((s) => s.removeMultiview);
  const clearMultiview = useStore((s) => s.clearMultiview);
  const addMultiview = useStore((s) => s.addMultiview);
  const [rail, setRail] = useState(true);

  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = prev; };
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") clearMultiview(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [clearMultiview]);

  const cells = [...multiview];
  const slots = Math.max(2, Math.min(4, cells.length + (cells.length < 4 ? 1 : 0)));
  const cols = slots <= 2 ? 1 : 2;

  return (
    <div data-nav-lock="multiview" className="fixed inset-0 z-[70] flex animate-fade-in bg-bg-deep">
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center gap-3 border-b border-bg-line px-4 py-3">
          <LayoutGrid className="h-5 w-5 text-signal" />
          <h2 className="text-sm font-bold uppercase tracking-widest">Multivision</h2>
          <span className="rounded-full bg-bg-raised px-2 py-0.5 text-[11px] text-ink-muted">{cells.length}/4</span>
          <p className="hidden text-xs text-ink-dim md:block">Solo suena la celda resaltada. Pulsa una celda para cambiar el audio.</p>
          <div className="flex-1" />
          <button onClick={() => setRail((v) => !v)} className="rounded-lg border border-bg-line px-3 py-1.5 text-xs hover:bg-bg-raised">
            {rail ? "Ocultar canales" : "Anadir canales"}
          </button>
          <button onClick={clearMultiview} className="flex items-center gap-1.5 rounded-lg bg-brand px-3 py-1.5 text-xs font-semibold text-white hover:bg-brand-hover">
            <X className="h-4 w-4" /> Salir
          </button>
        </header>

        <div
          className="grid min-h-0 flex-1 gap-2 p-2"
          style={{ gridTemplateColumns: `repeat(${cols}, minmax(0,1fr))`, gridAutoRows: "minmax(0,1fr)" }}
        >
          {cells.map((c, i) => (
            <div key={c.id} className="relative min-h-0">
              <Player
                channel={c}
                mode="cell"
                active={i === mvActive}
                onActivate={() => setMvActive(i)}
                onClose={() => removeMultiview(i)}
              />
              {i === mvActive && (
                <span className="pointer-events-none absolute bottom-2 left-2 flex items-center gap-1 rounded-full bg-signal/25 px-2 py-0.5 text-[10px] font-bold text-signal">
                  <Volume2 className="h-3 w-3" /> AUDIO
                </span>
              )}
            </div>
          ))}
          {cells.length < 4 && (
            <button
              onClick={() => setRail(true)}
              className={clsx(
                "flex min-h-[140px] flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed",
                "border-bg-line text-ink-dim hover:border-signal/60 hover:text-signal"
              )}
            >
              <LayoutGrid className="h-7 w-7" />
              <span className="text-sm font-semibold">Anadir canal</span>
              <span className="text-xs">Elige uno en el panel de la derecha</span>
            </button>
          )}
        </div>
      </div>

      {rail && (
        <aside className="hidden w-[320px] shrink-0 md:block">
          <ChannelRail title="Anadir a multivision" onPick={(c) => addMultiview(c)} onClose={() => setRail(false)} />
        </aside>
      )}
    </div>
  );
}
