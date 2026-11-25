import { useEffect, useRef, useState } from "react";
import {
  Play, Pause, Volume2, VolumeX, Maximize, Minimize,
  Settings, SkipBack, SkipForward, X, Loader2, AlertTriangle,
} from "lucide-react";
import { clsx } from "clsx";
import { usePlayer } from "../hooks/usePlayer";
import type { Channel } from "../types";

interface Props {
  channel: Channel;
  onClose: () => void;
}

const fmt = (s: number) => {
  if (!isFinite(s) || s < 0) return "0:00";
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = Math.floor(s % 60).toString().padStart(2, "0");
  return h > 0 ? `${h}:${m.toString().padStart(2, "0")}:${sec}` : `${m}:${sec}`;
};

export function Player({ channel, onClose }: Props) {
  const { videoRef, state, actions } = usePlayer(channel);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [fullscreen, setFullscreen] = useState(false);
  const [showControls, setShowControls] = useState(true);
  const [showMenu, setShowMenu] = useState(false);
  const hideTimer = useRef<number | null>(null);

  // Auto-ocultar controles mientras se reproduce
  useEffect(() => {
    if (!showControls || showMenu) return;
    hideTimer.current = window.setTimeout(() => {
      if (state.isPlaying) setShowControls(false);
    }, 3500);
    return () => {
      if (hideTimer.current) window.clearTimeout(hideTimer.current);
    };
  }, [showControls, showMenu, state.isPlaying]);

  useEffect(() => {
    const onFs = () => setFullscreen(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", onFs);
    return () => document.removeEventListener("fullscreenchange", onFs);
  }, []);

  const toggleFullscreen = async () => {
    const el = containerRef.current;
    const video = videoRef.current as (HTMLVideoElement & { webkitEnterFullscreen?: () => void }) | null;
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else if (el?.requestFullscreen) {
        await el.requestFullscreen();
        el.focus({ preventScroll: true });
      } else video?.webkitEnterFullscreen?.(); // iPhone
    } catch {}
  };

  // Atajos: solo cuando el propio reproductor tiene el foco (no interfiere con la pagina)
  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.target !== e.currentTarget) return;
    setShowControls(true);
    switch (e.key) {
      case " ":
      case "k":
        e.preventDefault();
        actions.playPause();
        break;
      case "ArrowRight":
        actions.seek(state.currentTime + 10);
        break;
      case "ArrowLeft":
        actions.seek(state.currentTime - 10);
        break;
      case "ArrowUp":
        e.preventDefault();
        actions.setVolume(state.volume + 0.1);
        break;
      case "ArrowDown":
        e.preventDefault();
        actions.setVolume(state.volume - 0.1);
        break;
      case "m":
        actions.setMuted(!state.muted);
        break;
      case "f":
        toggleFullscreen();
        break;
      case "p":
        actions.requestPiP();
        break;
      case "Escape":
        if (!document.fullscreenElement) onClose();
        break;
    }
  };

  const optBtn = (active: boolean) =>
    clsx("text-left text-xs px-2 py-1 rounded-md", active ? "bg-brand text-white" : "hover:bg-bg-hover");

  return (
    <div
      ref={containerRef}
      tabIndex={-1}
      onKeyDown={onKeyDown}
      onMouseMove={() => setShowControls(true)}
      className={clsx(
        "relative bg-black outline-none",
        fullscreen ? "w-screen h-screen" : "aspect-video w-full rounded-xl overflow-hidden"
      )}
    >
      <video
        ref={videoRef}
        className="w-full h-full object-contain bg-black"
        playsInline
        autoPlay
        onClick={() => {
          containerRef.current?.focus({ preventScroll: true });
          setShowControls(true);
        }}
        onDoubleClick={toggleFullscreen}
      />

      {state.loading && !state.error && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/40 pointer-events-none">
          <Loader2 className="w-12 h-12 text-brand animate-spin" />
        </div>
      )}

      {state.error && (
        <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/80 gap-3 p-6 text-center">
          <AlertTriangle className="w-10 h-10 text-brand" />
          <p className="text-ink max-w-md">{state.error}</p>
          <div className="flex gap-2">
            <button onClick={actions.retry} className="px-4 py-2 rounded-lg bg-brand hover:bg-brand-hover text-white font-semibold">
              Reintentar
            </button>
            <button onClick={onClose} className="px-4 py-2 rounded-lg bg-bg-card hover:bg-bg-hover text-ink">
              Cerrar
            </button>
          </div>
        </div>
      )}

      <div
        className={clsx(
          "absolute inset-0 flex flex-col justify-between bg-gradient-to-b from-black/60 via-transparent to-black/80 transition-opacity pointer-events-none",
          showControls ? "opacity-100" : "opacity-0"
        )}
      >
        <div className="flex items-center gap-3 p-3 md:p-4 pointer-events-auto">
          <button onClick={onClose} className="p-2 rounded-full hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-brand" aria-label="Cerrar">
            <X className="w-5 h-5" />
          </button>
          <div className="flex-1 min-w-0">
            <p className="font-semibold truncate">{channel.name}</p>
            {channel.group && <p className="text-xs text-ink-muted truncate">{channel.group}</p>}
          </div>
        </div>

        <div className="p-3 md:p-4 space-y-2 pointer-events-auto">
          {state.duration > 0 && (
            <input
              type="range"
              min={0}
              max={state.duration}
              step={0.1}
              value={state.currentTime}
              onChange={(e) => actions.seek(parseFloat(e.target.value))}
              className="w-full accent-brand"
            />
          )}
          <div className="flex items-center gap-1 md:gap-2">
            {state.duration > 0 && (
              <button onClick={() => actions.seek(state.currentTime - 10)} className="p-2 rounded-full hover:bg-white/10" aria-label="Atrasar 10 s">
                <SkipBack className="w-5 h-5" />
              </button>
            )}
            <button onClick={actions.playPause} className="p-2 rounded-full hover:bg-white/10" aria-label="Reproducir / pausar">
              {state.isPlaying ? <Pause className="w-6 h-6" /> : <Play className="w-6 h-6" />}
            </button>
            {state.duration > 0 && (
              <button onClick={() => actions.seek(state.currentTime + 10)} className="p-2 rounded-full hover:bg-white/10" aria-label="Adelantar 10 s">
                <SkipForward className="w-5 h-5" />
              </button>
            )}

            <button onClick={() => actions.setMuted(!state.muted)} className="p-2 rounded-full hover:bg-white/10" aria-label="Silenciar">
              {state.muted || state.volume === 0 ? <VolumeX className="w-5 h-5" /> : <Volume2 className="w-5 h-5" />}
            </button>
            <input
              type="range"
              min={0}
              max={1}
              step={0.05}
              value={state.muted ? 0 : state.volume}
              onChange={(e) => {
                actions.setMuted(false);
                actions.setVolume(parseFloat(e.target.value));
              }}
              className="w-24 accent-brand hidden sm:block"
            />

            {state.duration > 0 ? (
              <span className="text-xs text-ink-muted ml-2 hidden sm:inline">
                {fmt(state.currentTime)} / {fmt(state.duration)}
              </span>
            ) : (
              <span className="ml-2 text-xs font-semibold text-brand">EN VIVO</span>
            )}

            <div className="flex-1" />

            <div className="relative">
              <button onClick={() => setShowMenu((v) => !v)} className="p-2 rounded-full hover:bg-white/10" aria-label="Ajustes">
                <Settings className="w-5 h-5" />
              </button>
              {showMenu && (
                <div className="absolute right-0 bottom-full mb-2 w-64 max-h-72 overflow-y-auto bg-bg-soft border border-white/10 rounded-lg p-3 shadow-2xl space-y-3">
                  <div>
                    <p className="text-xs text-ink-muted mb-1">Velocidad</p>
                    <div className="flex gap-1 flex-wrap">
                      {[0.5, 0.75, 1, 1.25, 1.5, 2].map((r) => (
                        <button key={r} onClick={() => actions.setPlaybackRate(r)} className={optBtn(state.playbackRate === r)}>
                          {r}x
                        </button>
                      ))}
                    </div>
                  </div>
                  {state.audioTracks.length > 1 && (
                    <div>
                      <p className="text-xs text-ink-muted mb-1">Audio</p>
                      <div className="flex flex-col gap-1">
                        {state.audioTracks.map((t) => (
                          <button key={t.id} onClick={() => actions.setAudioTrack(t.id)} className={optBtn(state.activeAudio === t.id)}>
                            {t.label}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}
                  {state.subtitleTracks.length > 0 && (
                    <div>
                      <p className="text-xs text-ink-muted mb-1">Subtítulos</p>
                      <div className="flex flex-col gap-1">
                        <button onClick={() => actions.setSubtitleTrack(-1)} className={optBtn(state.activeSubtitle === -1)}>
                          Desactivados
                        </button>
                        {state.subtitleTracks.map((t) => (
                          <button key={t.id} onClick={() => actions.setSubtitleTrack(t.id)} className={optBtn(state.activeSubtitle === t.id)}>
                            {t.label}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}
                  <button onClick={actions.requestPiP} className={optBtn(false) + " w-full"}>
                    Picture-in-Picture
                  </button>
                </div>
              )}
            </div>

            <button onClick={toggleFullscreen} className="p-2 rounded-full hover:bg-white/10" aria-label="Pantalla completa">
              {fullscreen ? <Minimize className="w-5 h-5" /> : <Maximize className="w-5 h-5" />}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
