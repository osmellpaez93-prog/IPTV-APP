import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { Play } from "lucide-react";
import { clsx } from "clsx";
import { imgUrl } from "../../services/proxy";
import { getProgrammes, hhmm, type Programme } from "../../services/epg/guide";
import type { Channel } from "../../types";

const LEFT = 296;
const ROW = 54;
const OVERSCAN = 6;
const NO_INFO = "Sin informacion";

interface Props {
  channels: Channel[];
  selectedId: string | null;
  onSelect: (c: Channel) => void;
  onPick?: (c: Channel) => void;
  onPlay: (c: Channel) => void;
  pxPerMin: number;
  startMs: number;
  minutes: number;
}

interface Block { left: number; width: number; p: Programme | null }

export function EpgTimeline({ channels, selectedId, onSelect, onPick, onPlay, pxPerMin, startMs, minutes }: Props) {
  const scRef = useRef<HTMLDivElement | null>(null);
  const rafRef = useRef<number | null>(null);
  const [range, setRange] = useState({ s: 0, e: 24 });
  const [data, setData] = useState<Record<string, Programme[]>>({});
  const [now, setNow] = useState(Date.now());
  const width = minutes * pxPerMin;

  const recompute = useCallback(() => {
    const el = scRef.current;
    if (!el) return;
    const s = Math.max(0, Math.floor((el.scrollTop - 40) / ROW) - OVERSCAN);
    const e = Math.min(channels.length, Math.ceil((el.scrollTop + el.clientHeight) / ROW) + OVERSCAN);
    setRange((r) => (r.s === s && r.e === e ? r : { s, e }));
  }, [channels.length]);

  useLayoutEffect(() => { recompute(); }, [recompute]);

  useEffect(() => {
    const el = scRef.current;
    if (!el) return;
    const onScroll = () => {
      if (rafRef.current != null) return;
      rafRef.current = window.requestAnimationFrame(() => { rafRef.current = null; recompute(); });
    };
    el.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      el.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      if (rafRef.current != null) window.cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    };
  }, [recompute]);

  useEffect(() => {
    const t = window.setInterval(() => setNow(Date.now()), 30000);
    return () => window.clearInterval(t);
  }, []);

  // Carga EPG solo de las filas visibles (el servicio deduplica y cachea)
  useEffect(() => {
    let alive = true;
    const slice = channels.slice(range.s, range.e);
    for (const ch of slice) {
      getProgrammes(ch).then((items) => {
        if (!alive) return;
        setData((d) => (d[ch.id] === items ? d : { ...d, [ch.id]: items }));
      });
    }
    return () => { alive = false; };
  }, [range.s, range.e, channels]);

  // Al montar, coloca la linea de "ahora" a la vista
  useEffect(() => {
    const el = scRef.current;
    if (!el) return;
    const x = ((Date.now() - startMs) / 60000) * pxPerMin;
    el.scrollLeft = Math.max(0, x - 140);
  }, [startMs, pxPerMin]);

  // Mantiene visible la fila seleccionada con teclado
  useEffect(() => {
    const el = scRef.current;
    if (!el || !selectedId) return;
    const i = channels.findIndex((c) => c.id === selectedId);
    if (i < 0) return;
    const top = i * ROW + 40;
    if (top < el.scrollTop + 40 || top + ROW > el.scrollTop + el.clientHeight) {
      el.scrollTop = Math.max(0, top - el.clientHeight / 2);
    }
  }, [selectedId, channels]);

  const marks: number[] = [];
  for (let m = 0; m <= minutes; m += 30) marks.push(m);

  const nowX = ((now - startMs) / 60000) * pxPerMin;
  const rows = channels.slice(range.s, range.e);
  const dateLabel = new Date(startMs).toLocaleDateString("es-ES", { weekday: "short", day: "2-digit", month: "short" });

  const blocksFor = (items: Programme[] | undefined): Block[] => {
    if (!items || items.length === 0) {
      const out: Block[] = [];
      for (let m = 0; m < minutes; m += 30) out.push({ left: m * pxPerMin, width: 30 * pxPerMin, p: null });
      return out;
    }
    const out: Block[] = [];
    for (const p of items) {
      const a = Math.max(0, ((p.start - startMs) / 60000) * pxPerMin);
      const b = Math.min(width, ((p.end - startMs) / 60000) * pxPerMin);
      if (b - a > 1) out.push({ left: a, width: b - a, p });
    }
    if (out.length === 0) out.push({ left: 0, width, p: null });
    return out;
  };

  const onKey = (e: React.KeyboardEvent) => {
    const i = channels.findIndex((c) => c.id === selectedId);
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      const n = e.key === "ArrowDown" ? Math.min(channels.length - 1, i + 1) : Math.max(0, i - 1);
      if (channels[n]) onSelect(channels[n]);
    } else if (e.key === "Enter" && i >= 0) {
      e.preventDefault();
      (onPick ?? onPlay)(channels[i]);
    } else if (e.key === "ArrowRight" || e.key === "ArrowLeft") {
      e.preventDefault();
      scRef.current?.scrollBy({ left: (e.key === "ArrowRight" ? 1 : -1) * 30 * pxPerMin, behavior: "smooth" });
    }
  };

  return (
    <div
      ref={scRef}
      tabIndex={0}
      onKeyDown={onKey}
      className="sb-scroll relative min-h-0 flex-1 overflow-auto bg-[#070a12] outline-none"
    >
      <div style={{ width: LEFT + width, position: "relative" }}>
        {/* Regla de horas */}
        <div className="sticky top-0 z-30 flex h-10 border-b border-[#22304a] bg-[#0d1320]">
          <div className="sticky left-0 z-40 flex h-10 shrink-0 items-center border-r border-[#22304a] bg-[#0d1320] px-3 text-[13px] font-bold capitalize" style={{ width: LEFT }}>
            {dateLabel} <span className="sb-tnum ml-2 text-[#4c8dff]">{hhmm(now)}</span>
          </div>
          <div className="relative h-10" style={{ width }}>
            {marks.map((m) => (
              <div key={m} className="absolute top-0 flex h-10 items-center" style={{ left: m * pxPerMin }}>
                <span className="sb-tnum pl-1.5 text-[11px] text-[#93a3bd]">{hhmm(startMs + m * 60000)}</span>
                <span className="absolute left-0 top-6 h-4 w-px bg-[#22304a]" />
              </div>
            ))}
            {nowX >= 0 && nowX <= width && (
              <div className="absolute top-0 z-10 h-10" style={{ left: nowX }}>
                <span className="absolute -left-1 top-6 h-2 w-2 rounded-full bg-[#38bdf8]" />
              </div>
            )}
          </div>
        </div>

        {/* Cuerpo virtualizado */}
        <div style={{ height: channels.length * ROW, position: "relative" }}>
          <div style={{ position: "absolute", top: range.s * ROW, left: 0, width: LEFT + width }}>
            {rows.map((ch, i) => {
              const n = range.s + i;
              const on = ch.id === selectedId;
              const logo = imgUrl(ch.logo);
              const blocks = blocksFor(data[ch.id]);
              return (
                <div key={ch.id} className="flex border-b border-[#141d2e]" style={{ height: ROW }}>
                  <div
                    onClick={() => (onPick ?? onSelect)(ch)}
                    onDoubleClick={() => onPlay(ch)}
                    className={clsx(
                      "group sticky left-0 z-20 flex shrink-0 cursor-pointer items-center gap-2 border-r border-[#22304a] px-2",
                      on ? "sb-row-on" : "bg-[#0d1320] hover:bg-[#141d2e]"
                    )}
                    style={{ width: LEFT }}
                  >
                    <span className="sb-tnum w-8 shrink-0 text-right text-[11px] text-[#5d6d88]">{n + 1}</span>
                    <span className="flex h-7 w-10 shrink-0 items-center justify-center overflow-hidden rounded bg-[#070a12] ring-1 ring-[#22304a]">
                      {logo ? (
                        <img src={logo} alt="" loading="lazy" className="h-full w-full object-contain p-0.5" />
                      ) : (
                        <span className="text-[9px] font-bold text-[#5d6d88]">{ch.name.slice(0, 2).toUpperCase()}</span>
                      )}
                    </span>
                    <span className={clsx("min-w-0 flex-1 truncate text-[13px]", on ? "font-bold text-white" : "font-medium")}>
                      {ch.name}
                    </span>
                    <button
                      onClick={(e) => { e.stopPropagation(); onPlay(ch); }}
                      className="shrink-0 rounded p-1 opacity-0 transition-opacity hover:bg-white/10 group-hover:opacity-100"
                      aria-label={`Reproducir ${ch.name}`}
                    >
                      <Play className="h-3.5 w-3.5 text-[#4c8dff]" fill="currentColor" />
                    </button>
                  </div>

                  <div className="relative" style={{ width }} onClick={() => onSelect(ch)}>
                    {blocks.map((b, k) => {
                      const live = b.p && b.p.start <= now && b.p.end > now;
                      return (
                        <div
                          key={k}
                          title={b.p ? `${hhmm(b.p.start)} - ${hhmm(b.p.end)}  ${b.p.title}` : NO_INFO}
                          className={clsx(
                            "absolute top-1 bottom-1 overflow-hidden rounded-md border px-2 py-1",
                            live
                              ? "border-[#4c8dff]/60 bg-[#4c8dff]/12"
                              : b.p
                                ? "border-[#22304a] bg-[#101828]"
                                : "border-[#1a2438] bg-[#0b111d]"
                          )}
                          style={{ left: b.left + 2, width: Math.max(0, b.width - 4) }}
                        >
                          <p className={clsx("truncate text-[12px] leading-tight", b.p ? "text-[#eef3fb]" : "text-[#5d6d88]")}>
                            {b.p ? b.p.title : NO_INFO}
                          </p>
                          {b.p && b.width > 110 && (
                            <p className="sb-tnum truncate text-[10px] text-[#5d6d88]">{hhmm(b.p.start)} - {hhmm(b.p.end)}</p>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>

          {/* Linea de ahora */}
          {nowX >= 0 && nowX <= width && (
            <div
              className="pointer-events-none absolute top-0 z-10 w-px bg-[#38bdf8]"
              style={{ left: LEFT + nowX, height: channels.length * ROW, boxShadow: "0 0 10px rgba(56,189,248,.8)" }}
            />
          )}
        </div>
      </div>

      {channels.length === 0 && (
        <p className="py-16 text-center text-sm text-[#5d6d88]">No hay canales con ese filtro.</p>
      )}
    </div>
  );
}
