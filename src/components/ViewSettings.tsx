import { useMemo } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { X, RotateCcw, SlidersHorizontal } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { ACCENTS, useStore, type Accent, type Density, type MiniSize, type Corner } from "../store";

const chip = (on: boolean) =>
  clsx(
    "rounded-lg px-2.5 py-1.5 text-xs font-semibold border transition-colors",
    on ? "border-signal bg-signal/15 text-signal" : "border-bg-line bg-bg-deep text-ink-muted hover:bg-bg-raised"
  );

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1.5">
      <p className="text-[10px] font-bold uppercase tracking-widest text-ink-dim">{label}</p>
      {children}
    </div>
  );
}

export function ViewSettings() {
  const open = useStore((s) => s.settingsOpen);
  const setOpen = useStore((s) => s.setSettingsOpen);
  const ui = useStore((s) => s.ui);
  const setUI = useStore((s) => s.setUI);
  const toggleGroup = useStore((s) => s.toggleGroup);
  const resetUI = useStore((s) => s.resetUI);
  const mini = useStore((s) => s.mini);
  const setMini = useStore((s) => s.setMini);
  const activePlaylistId = useStore((s) => s.activePlaylistId);

  const groups = useLiveQuery(async () => {
    if (!activePlaylistId) return [] as string[];
    const rows = await db.channels.where("playlistId").equals(activePlaylistId).toArray();
    return Array.from(new Set(rows.map((c) => c.group || "Sin categoria"))).sort((a, b) => a.localeCompare(b));
  }, [activePlaylistId]);

  const visibleCount = useMemo(
    () => (groups ?? []).filter((g) => !ui.hiddenGroups.includes(g)).length,
    [groups, ui.hiddenGroups]
  );

  if (!open) return null;

  return (
    <>
      <div className="fixed inset-0 z-[55] bg-black/60 backdrop-blur-sm" onClick={() => setOpen(false)} />
      <aside
        data-nav-lock="settings"
        className="fixed right-0 top-0 z-[56] flex h-full w-[330px] max-w-[92vw] animate-slide-up flex-col border-l border-bg-line bg-bg-surface"
      >
        <header className="flex items-center gap-2 border-b border-bg-line px-4 py-3">
          <SlidersHorizontal className="h-4 w-4 text-signal" />
          <h2 className="flex-1 text-sm font-bold uppercase tracking-widest">Interfaz</h2>
          <button onClick={resetUI} className="rounded-lg border border-bg-line p-1.5 hover:bg-bg-raised" title="Restablecer" aria-label="Restablecer ajustes de interfaz">
            <RotateCcw className="h-4 w-4" />
          </button>
          <button onClick={() => setOpen(false)} className="rounded-lg p-1.5 hover:bg-bg-raised" aria-label="Cerrar">
            <X className="h-4 w-4" />
          </button>
        </header>

        <div className="min-h-0 flex-1 space-y-5 overflow-y-auto p-4">
          <Row label={`Escala de la interfaz Â· ${Math.round(ui.scale * 100)}%`}>
            <input type="range" className="sb-range w-full" min={0.85} max={1.3} step={0.05}
              value={ui.scale} onChange={(e) => setUI({ scale: parseFloat(e.target.value) })} aria-label="Escala de la interfaz" />
          </Row>

          <Row label="Densidad de lista">
            <div className="flex gap-1.5">
              {(["compact", "normal", "comfy"] as Density[]).map((d) => (
                <button key={d} onClick={() => setUI({ density: d })} className={chip(ui.density === d)}>
                  {d === "compact" ? "Compacta" : d === "normal" ? "Normal" : "Amplia"}
                </button>
              ))}
            </div>
          </Row>

          <Row label="Columnas">
            <div className="flex gap-1.5">
              {([0, 1, 2, 3] as const).map((c) => (
                <button key={c} onClick={() => setUI({ columns: c })} className={chip(ui.columns === c)}>
                  {c === 0 ? "Auto" : c}
                </button>
              ))}
            </div>
          </Row>

          <Row label={`Tamano de poster Â· ${Math.round(ui.posterScale * 100)}%`}>
            <input type="range" className="sb-range w-full" min={0.75} max={1.6} step={0.05}
              value={ui.posterScale} onChange={(e) => setUI({ posterScale: parseFloat(e.target.value) })} aria-label="Tamano de poster" />
          </Row>

          <Row label="Color de acento">
            <div className="flex flex-wrap gap-1.5">
              {(Object.keys(ACCENTS) as Accent[]).map((a) => (
                <button
                  key={a}
                  onClick={() => setUI({ accent: a })}
                  className={clsx(
                    "flex items-center gap-1.5 rounded-lg border px-2 py-1.5 text-xs",
                    ui.accent === a ? "border-ink" : "border-bg-line hover:bg-bg-raised"
                  )}
                >
                  <span className="h-3 w-3 rounded-full" style={{ background: ACCENTS[a].hex }} />
                  {ACCENTS[a].label}
                </button>
              ))}
            </div>
          </Row>

          <div className="border-t border-bg-line pt-4">
            <p className="mb-3 text-[10px] font-bold uppercase tracking-widest text-signal">Reproductor flotante</p>
            <div className="space-y-4">
              <Row label="Tamano">
                <div className="flex gap-1.5">
                  {(["s", "m", "l"] as MiniSize[]).map((s) => (
                    <button key={s} onClick={() => setMini({ size: s })} className={chip(mini.size === s)}>
                      {s === "s" ? "Pequeno" : s === "m" ? "Mediano" : "Grande"}
                    </button>
                  ))}
                </div>
              </Row>
              <Row label="Esquina">
                <div className="grid grid-cols-2 gap-1.5">
                  {([["tl", "Arriba izq."], ["tr", "Arriba der."], ["bl", "Abajo izq."], ["br", "Abajo der."]] as [Corner, string][]).map(([c, label]) => (
                    <button key={c} onClick={() => setMini({ corner: c })} className={chip(mini.corner === c)}>{label}</button>
                  ))}
                </div>
              </Row>
              <Row label={`Opacidad en reposo Â· ${mini.opacity}%`}>
                <input type="range" className="sb-range w-full" min={35} max={100} step={5}
                  value={mini.opacity} onChange={(e) => setMini({ opacity: parseInt(e.target.value, 10) })} aria-label="Opacidad del reproductor" />
              </Row>
            </div>
          </div>

          <div className="border-t border-bg-line pt-4">
            <p className="mb-1 text-[10px] font-bold uppercase tracking-widest text-signal">
              Categorias visibles Â· {visibleCount}/{(groups ?? []).length}
            </p>
            <p className="mb-3 text-[11px] text-ink-dim">Desmarca lo que no quieras ver en listas ni en el rail.</p>
            <div className="space-y-1">
              {(groups ?? []).map((g) => {
                const on = !ui.hiddenGroups.includes(g);
                return (
                  <label key={g} className="flex cursor-pointer items-center gap-2 rounded-lg px-2 py-1.5 text-xs hover:bg-bg-raised">
                    <input type="checkbox" checked={on} onChange={() => toggleGroup(g)} className="h-3.5 w-3.5 accent-signal" />
                    <span className={clsx("truncate", !on && "text-ink-dim line-through")}>{g}</span>
                  </label>
                );
              })}
              {(groups ?? []).length === 0 && <p className="text-xs text-ink-dim">Carga una lista para ver categorias.</p>}
            </div>
          </div>
        </div>
      </aside>
    </>
  );
}
