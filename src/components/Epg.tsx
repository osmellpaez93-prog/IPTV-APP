import { X, Loader2, CalendarClock } from "lucide-react";
import { useEpg } from "../hooks/useEpg";
import type { Channel } from "../types";

const hhmm = (ms: number) => new Date(ms).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

/** Línea "Ahora / Después" para la cabecera del reproductor. */
export function NowNext({ channel }: { channel: Channel }) {
  const { current, next } = useEpg(channel);
  if (channel.category !== "live" || !current) return null;
  return (
    <p className="truncate text-xs">
      <span className="font-bold text-brand">AHORA</span> {current.title}{" "}
      <span className="text-ink-muted">{hhmm(current.start)}–{hhmm(current.end)}</span>
      {next && <span className="text-ink-muted"> · Después: {next.title}</span>}
    </p>
  );
}

export function EpgMenuButton({ channel, onClick, className }: { channel: Channel; onClick: () => void; className?: string }) {
  if (channel.category !== "live") return null;
  return (
    <button onClick={onClick} className={className}>
      Guía de programación…
    </button>
  );
}

/** Panel con la programación de las próximas horas del canal. */
export function EpgPanel({ channel, onClose }: { channel: Channel; onClose: () => void }) {
  const { items, now, loading } = useEpg(channel);
  const list = (items ?? []).filter((i) => i.end > now);

  return (
    <div className="absolute inset-0 z-20 overflow-y-auto bg-black/85 p-3 sm:p-5">
      <div className="mx-auto max-w-xl space-y-3">
        <div className="flex items-center gap-2">
          <CalendarClock className="h-5 w-5 text-brand" />
          <h3 className="flex-1 truncate font-semibold">Guía · {channel.name}</h3>
          <button onClick={onClose} className="rounded-full p-2 hover:bg-white/10" aria-label="Cerrar guía">
            <X className="h-5 w-5" />
          </button>
        </div>

        {loading && (
          <p className="flex items-center gap-2 text-sm text-ink-muted">
            <Loader2 className="h-4 w-4 animate-spin" /> Cargando programación…
          </p>
        )}
        {!loading && list.length === 0 && (
          <p className="rounded-lg bg-bg-card p-3 text-sm text-ink-muted">
            Este canal no tiene guía de programación disponible (depende de tu proveedor).
          </p>
        )}

        <div className="space-y-2">
          {list.map((p) => {
            const isNow = p.start <= now;
            const pct = Math.min(100, Math.max(0, ((now - p.start) / (p.end - p.start)) * 100));
            return (
              <div key={p.start} className={`rounded-lg p-3 ${isNow ? "border border-brand/40 bg-brand/10" : "bg-bg-card"}`}>
                <div className="flex items-baseline gap-2">
                  <span className="font-mono text-xs text-ink-muted">{hhmm(p.start)}–{hhmm(p.end)}</span>
                  {isNow && <span className="text-[10px] font-bold uppercase tracking-wider text-brand">Ahora</span>}
                </div>
                <p className="mt-0.5 text-sm font-semibold">{p.title}</p>
                {p.description && <p className="mt-1 line-clamp-3 text-xs text-ink-muted">{p.description}</p>}
                {isNow && (
                  <div className="mt-2 h-1 overflow-hidden rounded-full bg-white/10">
                    <div className="h-full rounded-full bg-brand" style={{ width: `${pct}%` }} />
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
