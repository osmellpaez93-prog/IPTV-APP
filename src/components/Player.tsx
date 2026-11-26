import { useEffect, useRef, useState } from "react";
import {
  Play, Pause, Volume2, VolumeX, Maximize, Minimize, Settings,
  SkipBack, SkipForward, X, Loader2, AlertTriangle, ChevronLeft, ChevronRight,
} from "lucide-react";
import { clsx } from "clsx";
import { usePlayer } from "../hooks/usePlayer";
import { SubtitleDialog } from "./SubtitleDialog";
import { NowNext, EpgPanel, EpgMenuButton } from "./Epg";
import type { Channel } from "../types";

interface Props {
  channel: Channel;
  onClose: () => void;
  onPrev?: () => void;
  onNext?: () => void;
  onJump?: (index: number) => void;
  position?: { index: number; total: number };
}

const fmt = (s: number) => {
  if (!isFinite(s) || s < 0) return "0:00";
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = Math.floor(s % 60).toString().padStart(2, "0");
  return h > 0 ? `${h}:${m.toString().padStart(2, "0")}:${sec}` : `${m}:${sec}`;
};

const ENGINE_LABEL: Record<string, string> = { hls: "HLS", ts: "MPEG-TS", flv: "FLV", native: "Directo" };

export function Player({ channel, onClose, onPrev, onNext, onJump, position }: Props) {
  const { videoRef, state, actions } = usePlayer(channel);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const hideTimer = useRef<number | null>(null);
  const numBuf = useRef("");
  const numTimer = useRef<number | null>(null);

  const [fullscreen, setFullscreen] = useState(false);
  const [showControls, setShowControls] = useState(true);
  const [showMenu, setShowMenu] = useState(false);
  const [showSubs, setShowSubs] = useState(false);
  const [showEpg, setShowEpg] = useState(false);
  const [osd, setOsd] = useState<string | null>(null);

  const flash = (text: string) => {
    setOsd(text);
    window.setTimeout(() => setOsd((v) => (v === text ? null : v)), 1200);
  };

  useEffect(() => {
    if (!showControls || showMenu || showSubs) return;
    hideTimer.current = window.setTimeout(() => { if (state.isPlaying) setShowControls(false); }, 3500);
    return () => { if (hideTimer.current) window.clearTimeout(hideTimer.current); };
  }, [showControls, showMenu, showSubs, state.isPlaying]);

  useEffect(() => {
    const onFs = () => setFullscreen(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", onFs);
    return () => document.removeEventListener("fullscreenchange", onFs);
  }, []);

  useEffect(() => { containerRef.current?.focus({ preventScroll: true }); }, [channel.id]);

  const toggleFullscreen = async () => {
    const el = containerRef.current;
    const video = videoRef.current as (HTMLVideoElement & { webkitEnterFullscreen?: () => void }) | null;
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else if (el?.requestFullscreen) { await el.requestFullscreen(); el.focus({ preventScroll: true }); }
      else video?.webkitEnterFullscreen?.();
    } catch {}
  };

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.target !== e.currentTarget) return;
    setShowControls(true);

    if (/^[0-9]$/.test(e.key) && onJump && position && position.total > 1) {
      e.preventDefault();
      numBuf.current = (numBuf.current + e.key).slice(-4);
      flash(`Canal ${numBuf.current}`);
      if (numTimer.current) window.clearTimeout(numTimer.current);
      numTimer.current = window.setTimeout(() => {
        const n = parseInt(numBuf.current, 10);
        numBuf.current = "";
        if (!isNaN(n)) onJump(n - 1);
      }, 900);
      return;
    }

    switch (e.key) {
      case " ": case "k": case "Enter":
        e.preventDefault(); e.stopPropagation(); actions.playPause(); break;
      case "ArrowRight":
        e.preventDefault(); e.stopPropagation(); actions.seekBy(10); flash("+10 s"); break;
      case "ArrowLeft":
        e.preventDefault(); e.stopPropagation(); actions.seekBy(-10); flash("-10 s"); break;
      case "ArrowUp":
        e.preventDefault(); e.stopPropagation();
        if (e.shiftKey && onNext) onNext();
        else { actions.setVolume(state.volume + 0.1); flash(`Volumen ${Math.round(Math.min(1, state.volume + 0.1) * 100)}%`); }
        break;
      case "ArrowDown":
        e.preventDefault(); e.stopPropagation();
        if (e.shiftKey && onPrev) onPrev();
        else { actions.setVolume(state.volume - 0.1); flash(`Volumen ${Math.round(Math.max(0, state.volume - 0.1) * 100)}%`); }
        break;
      case "PageUp": e.preventDefault(); e.stopPropagation(); onNext?.(); break;
      case "PageDown": e.preventDefault(); e.stopPropagation(); onPrev?.(); break;
      case "m": actions.setMuted(!state.muted); flash(state.muted ? "Sonido activado" : "Silenciado"); break;
      case "f": toggleFullscreen(); break;
      case "p": actions.requestPiP(); break;
      case "Escape": if (!document.fullscreenElement) onClose(); break;
    }
  };

  const optBtn = (active: boolean) =>
    clsx("text-left text-xs px-2 py-1 rounded-md transition-colors", active ? "bg-brand text-white" : "hover:bg-bg-hover");

  const pct = state.duration > 0 ? (state.currentTime / state.duration) * 100 : 0;
  const bufPct = state.duration > 0 ? Math.min(100, (state.buffered / state.duration) * 100) : 0;

  return (
    <div ref={containerRef} tabIndex={-1} data-nav-scope="player" onKeyDown={onKeyDown}
      onMouseMove={() => setShowControls(true)} onTouchStart={() => setShowControls(true)}
      className={clsx("relative bg-black outline-none", fullscreen ? "h-screen w-screen" : "aspect-video w-full overflow-hidden rounded-xl ring-1 ring-white/10")}
    >
      <video ref={videoRef} className="h-full w-full bg-black object-contain" playsInline autoPlay
        onClick={() => { containerRef.current?.focus({ preventScroll: true }); setShowControls(true); }}
        onDoubleClick={toggleFullscreen} />

      {showSubs && <SubtitleDialog channel={channel} state={state} actions={actions} onClose={() => setShowSubs(false)} />}

      {showEpg && <EpgPanel channel={channel} onClose={() => setShowEpg(false)} />}

      {state.loading && !state.error && !state.blocked && (
        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center gap-3 bg-black/45">
          <Loader2 className="h-12 w-12 animate-spin text-brand" />
          {state.attempts > 1 && (
            <span className="rounded-full bg-black/70 px-3 py-1 text-xs font-semibold text-ink-muted">
              Fuente {state.attempt}/{state.attempts}{state.engine ? ` · ${ENGINE_LABEL[state.engine]}` : ""}
            </span>
          )}
        </div>
      )}

      {state.blocked && !state.error && (
        <button onClick={actions.unblock} className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-black/70">
          <span className="flex h-16 w-16 items-center justify-center rounded-full bg-brand shadow-card">
            <Play className="h-8 w-8 text-white" fill="currentColor" />
          </span>
          <span className="text-sm font-semibold">Toca para reproducir</span>
        </button>
      )}

      {state.stalled && !state.error && (
        <div className="pointer-events-none absolute left-1/2 top-4 -translate-x-1/2 rounded-full bg-warn/20 px-3 py-1 text-xs font-semibold text-warn">Buffering…</div>
      )}

      {osd && (
        <div className="pointer-events-none absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 animate-pop-in rounded-xl bg-black/80 px-5 py-3 text-lg font-bold">{osd}</div>
      )}

      {state.error && (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-black/85 p-6 text-center">
          <AlertTriangle className="h-10 w-10 text-brand" />
          <p className="max-w-md whitespace-pre-line text-sm text-ink">{state.error}</p>
          <div className="flex gap-2">
            <button onClick={actions.retry} className="rounded-lg bg-brand px-4 py-2 font-semibold text-white hover:bg-brand-hover">Reintentar</button>
            <button onClick={onClose} className="rounded-lg bg-bg-card px-4 py-2 text-ink hover:bg-bg-hover">Cerrar</button>
          </div>
        </div>
      )}

      <div className={clsx("pointer-events-none absolute inset-0 flex flex-col justify-between bg-gradient-to-b from-black/70 via-transparent to-black/85 transition-opacity duration-200", showControls ? "opacity-100" : "opacity-0")}>
        <div className="pointer-events-auto flex items-center gap-3 p-3 md:p-4">
          <button onClick={onClose} className="rounded-full p-2 hover:bg-white/10" aria-label="Cerrar reproductor"><X className="h-5 w-5" /></button>
          <div className="min-w-0 flex-1">
            <p className="truncate font-semibold">{channel.name}</p>
            <NowNext channel={channel} />
            <p className="truncate text-xs text-ink-muted">
              {position && position.total > 1 && <span className="font-mono text-aqua">{position.index + 1}/{position.total} · </span>}
              {channel.group}
            </p>
          </div>
          {state.engine && (
            <span className="hidden rounded-full border border-white/15 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-ink-muted sm:inline">{ENGINE_LABEL[state.engine]}</span>
          )}
        </div>

        <div className="pointer-events-auto space-y-2 p-3 md:p-4">
          {state.duration > 0 && (
            <div className="relative h-4 w-full">
              <div className="absolute inset-x-0 top-1.5 h-1 rounded-full bg-white/20">
                <div className="h-full rounded-full bg-white/25" style={{ width: `${bufPct}%` }} />
                <div className="absolute inset-y-0 left-0 rounded-full bg-brand" style={{ width: `${pct}%` }} />
              </div>
              <input type="range" min={0} max={state.duration} step={0.1} value={state.currentTime}
                onChange={(e) => actions.seek(parseFloat(e.target.value))}
                aria-label="Posicion de reproduccion"
                className="absolute inset-0 w-full cursor-pointer opacity-0" />
            </div>
          )}

          <div className="flex items-center gap-1 md:gap-2">
            {onPrev && position && position.total > 1 && (
              <button onClick={onPrev} className="rounded-full p-2 hover:bg-white/10" aria-label="Canal anterior"><ChevronLeft className="h-5 w-5" /></button>
            )}
            {state.duration > 0 && (
              <button onClick={() => actions.seekBy(-10)} className="rounded-full p-2 hover:bg-white/10" aria-label="Atrasar 10 segundos"><SkipBack className="h-5 w-5" /></button>
            )}
            <button onClick={actions.playPause} className="rounded-full bg-white/10 p-2.5 hover:bg-white/20" aria-label="Reproducir o pausar">
              {state.isPlaying ? <Pause className="h-6 w-6" /> : <Play className="h-6 w-6" fill="currentColor" />}
            </button>
            {state.duration > 0 && (
              <button onClick={() => actions.seekBy(10)} className="rounded-full p-2 hover:bg-white/10" aria-label="Adelantar 10 segundos"><SkipForward className="h-5 w-5" /></button>
            )}
            {onNext && position && position.total > 1 && (
              <button onClick={onNext} className="rounded-full p-2 hover:bg-white/10" aria-label="Canal siguiente"><ChevronRight className="h-5 w-5" /></button>
            )}

            <button onClick={() => actions.setMuted(!state.muted)} className="rounded-full p-2 hover:bg-white/10" aria-label="Silenciar">
              {state.muted || state.volume === 0 ? <VolumeX className="h-5 w-5" /> : <Volume2 className="h-5 w-5" />}
            </button>
            <input type="range" min={0} max={1} step={0.05} value={state.muted ? 0 : state.volume}
              onChange={(e) => actions.setVolume(parseFloat(e.target.value))}
              aria-label="Volumen" className="range-brand hidden w-24 sm:block" />

            {state.duration > 0 ? (
              <span className="ml-2 hidden text-xs text-ink-muted sm:inline">{fmt(state.currentTime)} / {fmt(state.duration)}</span>
            ) : (
              <span className="ml-2 flex items-center gap-1.5 text-xs font-bold text-brand">
                <span className="h-2 w-2 animate-pulse rounded-full bg-brand" /> EN VIVO
              </span>
            )}

            <div className="flex-1" />

            <div className="relative">
              <button onClick={() => setShowMenu((v) => !v)} className="rounded-full p-2 hover:bg-white/10" aria-label="Ajustes de reproduccion"><Settings className="h-5 w-5" /></button>
              {showMenu && (
                <div className="absolute bottom-full right-0 mb-2 max-h-72 w-64 space-y-3 overflow-y-auto rounded-lg border border-white/10 bg-bg-soft p-3 shadow-2xl">
                  <div>
                    <p className="mb-1 text-xs text-ink-muted">Velocidad</p>
                    <div className="flex flex-wrap gap-1">
                      {[0.5, 0.75, 1, 1.25, 1.5, 2].map((r) => (
                        <button key={r} onClick={() => actions.setPlaybackRate(r)} className={optBtn(state.playbackRate === r)}>{r}x</button>
                      ))}
                    </div>
                  </div>
                  {state.audioTracks.length > 1 && (
                    <div>
                      <p className="mb-1 text-xs text-ink-muted">Audio</p>
                      <div className="flex flex-col gap-1">
                        {state.audioTracks.map((t) => (
                          <button key={t.id} onClick={() => actions.setAudioTrack(t.id)} className={optBtn(state.activeAudio === t.id)}>{t.label}</button>
                        ))}
                      </div>
                    </div>
                  )}
                  {state.subtitleTracks.length > 0 && (
                    <div>
                      <p className="mb-1 text-xs text-ink-muted">Subtitulos del stream</p>
                      <div className="flex flex-col gap-1">
                        <button onClick={() => actions.setSubtitleTrack(-1)} className={optBtn(state.activeSubtitle === -1)}>Desactivados</button>
                        {state.subtitleTracks.map((t) => (
                          <button key={t.id} onClick={() => actions.setSubtitleTrack(t.id)} className={optBtn(state.activeSubtitle === t.id)}>{t.label}</button>
                        ))}
                      </div>
                    </div>
                  )}
                  <button onClick={() => { setShowSubs(true); setShowMenu(false); }} className={optBtn(false) + " w-full"}>Buscar / cargar subtitulos…</button>
                  {state.extSubs.length > 0 && (
                    <div>
                      <p className="mb-1 text-xs text-ink-muted">Subtitulos anadidos</p>
                      <div className="flex flex-col gap-1">
                        <button onClick={() => actions.setExtSubtitle(null)} className={optBtn(state.activeExtSub === null)}>Desactivados</button>
                        {state.extSubs.map((t) => (
                          <button key={t.id} onClick={() => actions.setExtSubtitle(t.id)} className={optBtn(state.activeExtSub === t.id)}>{t.label}</button>
                        ))}
                      </div>
                    </div>
                  )}
                  <EpgMenuButton channel={channel} className={optBtn(false) + " w-full"} onClick={() => { setShowEpg(true); setShowMenu(false); }} />
                  <button onClick={actions.requestPiP} className={optBtn(false) + " w-full"}>Picture-in-Picture</button>
                  <button onClick={actions.retry} className={optBtn(false) + " w-full"}>Recargar fuente</button>
                  <p className="border-t border-white/5 pt-2 text-[10px] leading-relaxed text-ink-dim">
                    Espacio play · ← → 10 s · ↑ ↓ volumen · Shift+↑ ↓ canal · teclas 0-9 saltar · F pantalla · M silencio · P PiP
                  </p>
                </div>
              )}
            </div>

            <button onClick={toggleFullscreen} className="rounded-full p-2 hover:bg-white/10" aria-label="Pantalla completa">
              {fullscreen ? <Minimize className="h-5 w-5" /> : <Maximize className="h-5 w-5" />}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
