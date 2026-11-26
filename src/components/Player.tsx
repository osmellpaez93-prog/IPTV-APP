import { useEffect, useRef, useState } from "react";
import {
  Play, Pause, Volume2, VolumeX, Maximize, Minimize, SkipBack, SkipForward,
  X, Loader2, AlertTriangle, ChevronLeft, ChevronRight, Subtitles,
  PanelRightClose, PanelRightOpen, RotateCcw, PictureInPicture2, Gauge,
} from "lucide-react";
import { clsx } from "clsx";
import { usePlayer } from "../hooks/usePlayer";
import { SubtitleDialog } from "./SubtitleDialog";
import { NowNext, EpgPanel, EpgMenuButton } from "./Epg";
import { useStore } from "../store";
import type { Channel } from "../types";

export type PlayerMode = "mini" | "theater" | "full" | "cell";

interface Props {
  channel: Channel;
  mode: PlayerMode;
  onClose: () => void;
  onMode?: (m: "mini" | "theater" | "full") => void;
  onPrev?: () => void;
  onNext?: () => void;
  onJump?: (index: number) => void;
  position?: { index: number; total: number };
  silent?: boolean;
  railOpen?: boolean;
  onToggleRail?: () => void;
  onActivate?: () => void;
  active?: boolean;
}

const fmt = (s: number) => {
  if (!isFinite(s) || s < 0) return "0:00";
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = Math.floor(s % 60).toString().padStart(2, "0");
  return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
};

const selCls =
  "rounded-md border border-bg-line bg-bg-deep px-2 py-1 text-xs text-ink focus:border-signal focus:outline-none";

function Knob({
  label, value, min, max, step = 1, unit = "%", onChange,
}: { label: string; value: number; min: number; max: number; step?: number; unit?: string; onChange: (v: number) => void }) {
  return (
    <label className="flex min-w-[124px] flex-1 flex-col gap-1">
      <span className="flex items-baseline justify-between text-[10px] uppercase tracking-wider text-ink-dim">
        {label}
        <span className="font-mono text-signal">{value}{unit}</span>
      </span>
      <input
        type="range" className="sb-range w-full" min={min} max={max} step={step} value={value}
        onChange={(e) => onChange(parseFloat(e.target.value))} aria-label={label}
      />
    </label>
  );
}

export function Player({
  channel, mode, onClose, onMode, onPrev, onNext, onJump, position,
  silent, railOpen, onToggleRail, onActivate, active = true,
}: Props) {
  const { videoRef, state, actions } = usePlayer(channel);
  const video = useStore((s) => s.video);
  const setVideo = useStore((s) => s.setVideo);
  const resetVideo = useStore((s) => s.resetVideo);

  const boxRef = useRef<HTMLDivElement | null>(null);
  const hideTimer = useRef<number | null>(null);
  const numBuf = useRef("");
  const numTimer = useRef<number | null>(null);

  const [fs, setFs] = useState(false);
  const [controls, setControls] = useState(true);
  const [subs, setSubs] = useState(false);
  const [epg, setEpg] = useState(false);
  const [osd, setOsd] = useState<string | null>(null);

  const flash = (t: string) => {
    setOsd(t);
    window.setTimeout(() => setOsd((v) => (v === t ? null : v)), 1100);
  };

  const compact = mode === "mini" || mode === "cell";
  const showBar = mode === "theater" || mode === "full" ? controls || !state.isPlaying : true;

  useEffect(() => {
    if (mode === "theater" || compact) return;
    if (!controls) return;
    hideTimer.current = window.setTimeout(() => { if (state.isPlaying) setControls(false); }, 3200);
    return () => { if (hideTimer.current) window.clearTimeout(hideTimer.current); };
  }, [controls, state.isPlaying, mode, compact]);

  useEffect(() => {
    const onFs = () => setFs(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", onFs);
    return () => document.removeEventListener("fullscreenchange", onFs);
  }, []);

  useEffect(() => { boxRef.current?.focus({ preventScroll: true }); }, [channel.id, mode]);

  // Celdas de multivision: solo suena la activa.
  useEffect(() => {
    if (mode !== "cell") return;
    actions.setMuted(!active);
    if (!active) actions.setVolume(0);
    else actions.setVolume(1);
  }, [active, mode, channel.id]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (silent) actions.setMuted(true);
  }, [silent, channel.id]); // eslint-disable-line react-hooks/exhaustive-deps

  const toggleFs = async () => {
    const el = boxRef.current;
    const v = videoRef.current as (HTMLVideoElement & { webkitEnterFullscreen?: () => void }) | null;
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else if (el?.requestFullscreen) { await el.requestFullscreen(); el.focus({ preventScroll: true }); }
      else v?.webkitEnterFullscreen?.();
    } catch {}
  };

  const onKey = (e: React.KeyboardEvent) => {
    if (e.target !== e.currentTarget) return;
    setControls(true);
    if (/^[0-9]$/.test(e.key) && onJump && position && position.total > 1) {
      e.preventDefault();
      numBuf.current = (numBuf.current + e.key).slice(-4);
      flash(`Canal ${numBuf.current}`);
      if (numTimer.current) window.clearTimeout(numTimer.current);
      numTimer.current = window.setTimeout(() => {
        const n = parseInt(numBuf.current, 10);
        numBuf.current = "";
        if (!isNaN(n)) onJump(n - 1);
      }, 850);
      return;
    }
    switch (e.key) {
      case " ": case "k": case "Enter":
        e.preventDefault(); e.stopPropagation(); actions.playPause(); break;
      case "ArrowRight":
        e.preventDefault(); e.stopPropagation(); actions.seek(state.currentTime + 10); flash("+10 s"); break;
      case "ArrowLeft":
        e.preventDefault(); e.stopPropagation(); actions.seek(state.currentTime - 10); flash("-10 s"); break;
      case "ArrowUp":
        e.preventDefault(); e.stopPropagation();
        if (e.shiftKey) onNext?.();
        else { actions.setVolume(Math.min(1, state.volume + 0.1)); actions.setMuted(false); flash(`Volumen ${Math.round(Math.min(1, state.volume + 0.1) * 100)}%`); }
        break;
      case "ArrowDown":
        e.preventDefault(); e.stopPropagation();
        if (e.shiftKey) onPrev?.();
        else { actions.setVolume(Math.max(0, state.volume - 0.1)); flash(`Volumen ${Math.round(Math.max(0, state.volume - 0.1) * 100)}%`); }
        break;
      case "PageUp": e.preventDefault(); e.stopPropagation(); onNext?.(); break;
      case "PageDown": e.preventDefault(); e.stopPropagation(); onPrev?.(); break;
      case "m": actions.setMuted(!state.muted); flash(state.muted ? "Sonido activado" : "Silenciado"); break;
      case "f": toggleFs(); break;
      case "p": actions.requestPiP(); break;
      case "Escape":
        e.stopPropagation();
        if (document.fullscreenElement) break;
        if (mode === "full") onMode?.("theater");
        else if (mode === "theater") onMode?.("mini");
        else onClose();
        break;
    }
  };

  const filter = `brightness(${video.brightness}%) contrast(${video.contrast}%) saturate(${video.saturate}%)`;
  const pct = state.duration > 0 ? (state.currentTime / state.duration) * 100 : 0;

  return (
    <div
      ref={boxRef}
      tabIndex={-1}
      data-nav-scope="player"
      onKeyDown={onKey}
      onMouseMove={() => setControls(true)}
      onTouchStart={() => { setControls(true); onActivate?.(); }}
      onClick={() => { boxRef.current?.focus({ preventScroll: true }); setControls(true); onActivate?.(); }}
      className={clsx(
        "relative flex min-h-0 flex-col bg-black outline-none",
        mode === "mini" && "h-full w-full overflow-hidden rounded-xl",
        mode === "cell" && "h-full w-full overflow-hidden rounded-lg",
        (mode === "theater" || mode === "full") && "h-full w-full",
        mode === "cell" && active && "ring-2 ring-signal"
      )}
    >
      <div className="relative min-h-0 flex-1 overflow-hidden bg-black">
        <video
          ref={videoRef}
          className="h-full w-full bg-black"
          style={{
            objectFit: video.aspect,
            filter,
            transform: video.zoom !== 100 ? `scale(${video.zoom / 100})` : undefined,
          }}
          playsInline
          autoPlay
          onDoubleClick={toggleFs}
        />

        {epg && !compact && <EpgPanel channel={channel} onClose={() => setEpg(false)} />}

        {subs && !compact && (
          <SubtitleDialog channel={channel} state={state} actions={actions} onClose={() => setSubs(false)} />
        )}

        {state.loading && !state.error && (
          <div className="pointer-events-none absolute inset-0 flex items-center justify-center bg-black/45">
            <Loader2 className={clsx("animate-spin text-signal", compact ? "h-7 w-7" : "h-12 w-12")} />
          </div>
        )}

        {state.error && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-black/85 p-4 text-center">
            <AlertTriangle className={clsx("text-brand", compact ? "h-6 w-6" : "h-9 w-9")} />
            {!compact && <p className="max-w-md text-sm text-ink">{state.error}</p>}
            <div className="flex gap-2">
              <button onClick={actions.retry} className="rounded-lg bg-brand px-3 py-1.5 text-xs font-semibold text-white hover:bg-brand-hover">
                Reintentar
              </button>
              <button onClick={onClose} className="rounded-lg bg-bg-raised px-3 py-1.5 text-xs text-ink hover:bg-bg-line">
                Cerrar
              </button>
            </div>
          </div>
        )}

        {osd && (
          <div className="pointer-events-none absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 animate-pop-in rounded-xl bg-black/80 px-4 py-2 text-base font-bold">
            {osd}
          </div>
        )}

        {/* Cabecera */}
        <div className={clsx(
          "absolute inset-x-0 top-0 flex items-center gap-2 bg-gradient-to-b from-black/80 to-transparent p-2 transition-opacity",
          showBar ? "opacity-100" : "pointer-events-none opacity-0"
        )}>
          {position && position.total > 1 && (
            <span className="rounded-md bg-black/60 px-1.5 py-0.5 font-mono text-[11px] text-signal">
              {position.index + 1}/{position.total}
            </span>
          )}
          <div className="min-w-0 flex-1">
            <p className={clsx("truncate font-semibold", compact ? "text-xs" : "text-sm")}>{channel.name}</p>
            {!compact && <NowNext channel={channel} />}
            {!compact && channel.group && <p className="truncate text-[11px] text-ink-muted">{channel.group}</p>}
          </div>
          {!compact && state.duration === 0 && (
            <span className="flex items-center gap-1 rounded-full bg-brand/20 px-2 py-0.5 text-[10px] font-bold text-brand">
              <span className="h-1.5 w-1.5 animate-live-dot rounded-full bg-brand" /> EN VIVO
            </span>
          )}
          {mode === "theater" && onToggleRail && (
            <button onClick={onToggleRail} className="rounded-lg p-1.5 hover:bg-white/10" aria-label="Mostrar u ocultar canales">
              {railOpen ? <PanelRightClose className="h-4 w-4" /> : <PanelRightOpen className="h-4 w-4" />}
            </button>
          )}
          {onMode && mode !== "cell" && (
            <button
              onClick={() => onMode(mode === "mini" ? "theater" : mode === "theater" ? "full" : "theater")}
              className="rounded-lg p-1.5 hover:bg-white/10"
              aria-label="Cambiar modo de vista"
              title={mode === "mini" ? "Modo teatro" : mode === "theater" ? "Pantalla completa" : "Volver a teatro"}
            >
              {mode === "full" ? <Minimize className="h-4 w-4" /> : <Maximize className="h-4 w-4" />}
            </button>
          )}
          <button onClick={onClose} className="rounded-lg p-1.5 hover:bg-white/10" aria-label="Cerrar reproductor">
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* Controles flotantes inferiores (mini / full / cell) */}
        {mode !== "theater" && (
          <div className={clsx(
            "absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/85 to-transparent p-2 transition-opacity",
            showBar ? "opacity-100" : "pointer-events-none opacity-0"
          )}>
            {state.duration > 0 && (
              <div className="mb-1.5 h-1 w-full overflow-hidden rounded-full bg-white/20">
                <div className="h-full rounded-full bg-signal" style={{ width: `${pct}%` }} />
              </div>
            )}
            <div className="flex items-center gap-1">
              {onPrev && position && position.total > 1 && (
                <button onClick={onPrev} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Canal anterior">
                  <ChevronLeft className="h-4 w-4" />
                </button>
              )}
              <button onClick={actions.playPause} className="rounded-full bg-white/10 p-1.5 hover:bg-white/20" aria-label="Reproducir o pausar">
                {state.isPlaying ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4" fill="currentColor" />}
              </button>
              {onNext && position && position.total > 1 && (
                <button onClick={onNext} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Canal siguiente">
                  <ChevronRight className="h-4 w-4" />
                </button>
              )}
              <button onClick={() => actions.setMuted(!state.muted)} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Silenciar">
                {state.muted || state.volume === 0 ? <VolumeX className="h-4 w-4" /> : <Volume2 className="h-4 w-4" />}
              </button>
              {!compact && state.duration > 0 && (
                <>
                  <button onClick={() => actions.seek(state.currentTime - 10)} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Atrasar 10 segundos">
                    <SkipBack className="h-4 w-4" />
                  </button>
                  <button onClick={() => actions.seek(state.currentTime + 10)} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Adelantar 10 segundos">
                    <SkipForward className="h-4 w-4" />
                  </button>
                  <span className="ml-1 text-[11px] text-ink-muted">{fmt(state.currentTime)} / {fmt(state.duration)}</span>
                </>
              )}
              <div className="flex-1" />
              {!compact && (
                <button onClick={toggleFs} className="rounded-full p-1.5 hover:bg-white/10" aria-label="Pantalla completa">
                  {fs ? <Minimize className="h-4 w-4" /> : <Maximize className="h-4 w-4" />}
                </button>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Barra de control permanente del modo teatro */}
      {mode === "theater" && (
        <div className="shrink-0 space-y-2 border-t border-bg-line bg-bg-surface px-3 py-2.5">
          <div className="flex items-center gap-2">
            {onPrev && position && position.total > 1 && (
              <button onClick={onPrev} className="rounded-lg p-2 hover:bg-bg-raised" aria-label="Canal anterior"><ChevronLeft className="h-4 w-4" /></button>
            )}
            <button onClick={actions.playPause} className="rounded-lg bg-signal/20 p-2 text-signal hover:bg-signal/30" aria-label="Reproducir o pausar">
              {state.isPlaying ? <Pause className="h-5 w-5" /> : <Play className="h-5 w-5" fill="currentColor" />}
            </button>
            {onNext && position && position.total > 1 && (
              <button onClick={onNext} className="rounded-lg p-2 hover:bg-bg-raised" aria-label="Canal siguiente"><ChevronRight className="h-4 w-4" /></button>
            )}
            <button onClick={() => actions.setMuted(!state.muted)} className="rounded-lg p-2 hover:bg-bg-raised" aria-label="Silenciar">
              {state.muted || state.volume === 0 ? <VolumeX className="h-4 w-4" /> : <Volume2 className="h-4 w-4" />}
            </button>
            <input
              type="range" className="sb-range w-24" min={0} max={1} step={0.05}
              value={state.muted ? 0 : state.volume}
              onChange={(e) => { actions.setMuted(false); actions.setVolume(parseFloat(e.target.value)); }}
              aria-label="Volumen"
            />
            {state.duration > 0 ? (
              <span className="ml-1 hidden font-mono text-[11px] text-ink-muted sm:inline">
                {fmt(state.currentTime)} / {fmt(state.duration)}
              </span>
            ) : (
              <span className="ml-1 flex items-center gap-1 text-[11px] font-bold text-brand">
                <span className="h-1.5 w-1.5 animate-live-dot rounded-full bg-brand" /> EN VIVO
              </span>
            )}
            <div className="flex-1" />
            <EpgMenuButton channel={channel} onClick={() => setEpg(true)} className="flex items-center gap-1.5 rounded-lg border border-bg-line px-2.5 py-1.5 text-xs hover:bg-bg-raised" />
            <button onClick={() => setSubs(true)} className="flex items-center gap-1.5 rounded-lg border border-bg-line px-2.5 py-1.5 text-xs hover:bg-bg-raised">
              <Subtitles className="h-4 w-4" /> Subtitulos
            </button>
            <button onClick={actions.requestPiP} className="rounded-lg border border-bg-line p-1.5 hover:bg-bg-raised" aria-label="Picture in Picture" title="Picture-in-Picture">
              <PictureInPicture2 className="h-4 w-4" />
            </button>
            <button onClick={toggleFs} className="rounded-lg border border-bg-line p-1.5 hover:bg-bg-raised" aria-label="Pantalla completa">
              {fs ? <Minimize className="h-4 w-4" /> : <Maximize className="h-4 w-4" />}
            </button>
          </div>

          {state.duration > 0 && (
            <input
              type="range" className="sb-range w-full" min={0} max={state.duration} step={0.1}
              value={state.currentTime} onChange={(e) => actions.seek(parseFloat(e.target.value))}
              aria-label="Posicion de reproduccion"
            />
          )}

          <div className="flex flex-wrap items-end gap-x-4 gap-y-2">
            <Knob label="Brillo" value={video.brightness} min={50} max={160} onChange={(v) => setVideo({ brightness: v })} />
            <Knob label="Contraste" value={video.contrast} min={50} max={160} onChange={(v) => setVideo({ contrast: v })} />
            <Knob label="Saturacion" value={video.saturate} min={0} max={200} onChange={(v) => setVideo({ saturate: v })} />
            <Knob label="Zoom" value={video.zoom} min={100} max={160} onChange={(v) => setVideo({ zoom: v })} />

            <label className="flex flex-col gap-1">
              <span className="text-[10px] uppercase tracking-wider text-ink-dim">Encuadre</span>
              <select className={selCls} value={video.aspect} onChange={(e) => setVideo({ aspect: e.target.value as "contain" | "cover" | "fill" })}>
                <option value="contain">Completo</option>
                <option value="cover">Recortar</option>
                <option value="fill">Estirar</option>
              </select>
            </label>

            <label className="flex flex-col gap-1">
              <span className="flex items-center gap-1 text-[10px] uppercase tracking-wider text-ink-dim"><Gauge className="h-3 w-3" /> Velocidad</span>
              <select className={selCls} value={state.playbackRate} onChange={(e) => actions.setPlaybackRate(parseFloat(e.target.value))}>
                {[0.5, 0.75, 1, 1.25, 1.5, 2].map((r) => <option key={r} value={r}>{r}x</option>)}
              </select>
            </label>

            {state.audioTracks.length > 1 && (
              <label className="flex flex-col gap-1">
                <span className="text-[10px] uppercase tracking-wider text-ink-dim">Audio</span>
                <select className={selCls} value={state.activeAudio} onChange={(e) => actions.setAudioTrack(parseInt(e.target.value, 10))}>
                  {state.audioTracks.map((t) => <option key={t.id} value={t.id}>{t.label}</option>)}
                </select>
              </label>
            )}

            {state.subtitleTracks.length > 0 && (
              <label className="flex flex-col gap-1">
                <span className="text-[10px] uppercase tracking-wider text-ink-dim">Sub. stream</span>
                <select className={selCls} value={state.activeSubtitle} onChange={(e) => actions.setSubtitleTrack(parseInt(e.target.value, 10))}>
                  <option value={-1}>Off</option>
                  {state.subtitleTracks.map((t) => <option key={t.id} value={t.id}>{t.label}</option>)}
                </select>
              </label>
            )}

            <button onClick={resetVideo} className="flex items-center gap-1.5 rounded-lg border border-bg-line px-2.5 py-1.5 text-xs hover:bg-bg-raised">
              <RotateCcw className="h-3.5 w-3.5" /> Reset imagen
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
