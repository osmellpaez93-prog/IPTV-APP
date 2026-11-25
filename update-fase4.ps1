<#
  StreamBox - update-fase4.ps1
  ---------------------------------------------------------------------------
  Aplica las mejoras de la Fase 4 sobre el repo actual:
    - URLs del proxy SIEMPRE absolutas (arregla el error de mpegts.js en Worker)
    - mpegts.js con enableWorker:false + watchdog + reanudación VOD
    - Cadena de fuentes .m3u8 -> .ts -> fallback
    - Grid virtualizado real (100k entradas sin colgar)
    - Navegación espacial por flechas / D-pad
    - Continuar viendo con reanudación
    - Zapping (Shift+flechas, RePag/AvPag, teclas 0-9)
    - Barra inferior móvil
    - Proxy Node endurecido (redirects internos, detección HTML, rewrite HLS)
    - Fondo mesh + grano, scrollbars con identidad visual

  Uso (raiz del repo, terminal de VS Code / PowerShell):
    powershell -ExecutionPolicy Bypass -File .\update-fase4.ps1

  Guarda .bak de cada archivo que cambia. No requiere npm install.
#>
param([switch]$Force)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "package.json"))) {
  Write-Host "ERROR: ejecuta esto en la raiz del proyecto (donde esta package.json)." -ForegroundColor Red
  return
}
Write-Host ""
Write-Host "StreamBox - Fase 4 -> $root" -ForegroundColor Cyan
if (-not $Force) {
  $r = Read-Host "Aplicar cambios? (S/N)"
  if ($r -notmatch '^[sSyY]') { Write-Host "Cancelado."; return }
}

function Write-ProjectFile {
  param([string]$RelPath, [string]$Content)
  $full = Join-Path $root $RelPath
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if (-not $Content.EndsWith("`n")) { $Content += "`n" }
  if (Test-Path $full) {
    $old = [System.IO.File]::ReadAllText($full)
    if ($old -ne $Content) { Copy-Item $full "$full.bak" -Force }
  }
  [System.IO.File]::WriteAllText($full, $Content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  + $RelPath" -ForegroundColor Green
}

# ================================================================ src/index.css
Write-ProjectFile 'src/index.css' @'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  color-scheme: dark;
  --sb-track: #101018;
  --sb-thumb: #33334a;
}

html, body, #root {
  height: 100%;
  background: #0b0b0f;
  color: #f6f6f8;
}

html {
  scroll-behavior: smooth;
  scroll-padding-top: 88px;
}

body { overscroll-behavior-y: none; }

/* Scrollbars con identidad visual */
* {
  scrollbar-width: thin;
  scrollbar-color: var(--sb-thumb) var(--sb-track);
}
*::-webkit-scrollbar { width: 11px; height: 11px; }
*::-webkit-scrollbar-track { background: var(--sb-track); border-radius: 999px; }
*::-webkit-scrollbar-thumb {
  background: linear-gradient(180deg, #3a3a55, #2b2b3d);
  border: 2px solid var(--sb-track);
  border-radius: 999px;
}
*::-webkit-scrollbar-thumb:hover { background: linear-gradient(180deg, #e50914, #8b5cf6); }
*::-webkit-scrollbar-corner { background: transparent; }

.no-scrollbar { scrollbar-width: none; }
.no-scrollbar::-webkit-scrollbar { height: 0; width: 0; }

/* Foco muy visible (teclado / D-pad / mando TV) */
[data-focusable="true"] {
  outline: none;
  transition: transform 0.16s cubic-bezier(0.2, 0.8, 0.2, 1),
              box-shadow 0.16s ease, background-color 0.16s ease, border-color 0.16s ease;
}
[data-focusable="true"]:focus-visible {
  box-shadow: 0 0 0 3px rgba(229, 9, 20, 0.85), 0 0 28px rgba(229, 9, 20, 0.4);
  transform: scale(1.035);
  z-index: 6;
  position: relative;
}
input:focus-visible, select:focus-visible, textarea:focus-visible {
  outline: none;
  box-shadow: 0 0 0 2px rgba(229, 9, 20, 0.7);
}

.skeleton {
  background: linear-gradient(90deg, #181822 0%, #262636 45%, #181822 90%);
  background-size: 220% 100%;
  animation: shimmer 1.5s linear infinite;
}
@keyframes shimmer {
  0% { background-position: 220% 0; }
  100% { background-position: -220% 0; }
}

video::cue {
  background: rgba(0, 0, 0, 0.72);
  color: #fff;
  font-size: 1.12em;
  line-height: 1.35;
  text-shadow: 0 2px 6px rgba(0, 0, 0, 0.9);
}

.safe-bottom { padding-bottom: max(env(safe-area-inset-bottom), 0.5rem); }

.grain {
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='140' height='140'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='3'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.42'/%3E%3C/svg%3E");
}
.range-brand { accent-color: #e50914; }

@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.001ms !important;
  }
}
'@

# ========================================================== src/services/proxy.ts
Write-ProjectFile 'src/services/proxy.ts' @'
/**
 * URLs del proxy.
 *
 * CLAVE: siempre ABSOLUTAS. mpegts.js (y cualquier Worker creado desde un Blob)
 * hace fetch dentro de un WorkerGlobalScope cuyo documento base es "blob:".
 * Una ruta relativa como "/proxy/stream?url=..." no se puede resolver ahi y
 * revienta con: "Failed to execute 'fetch' on 'WorkerGlobalScope':
 * Failed to parse URL from /proxy/stream?...".
 */
import { getSettings } from "../db";

export type ProxyKind = "playlist" | "stream" | "image";

// Base sincrona para helpers que no pueden ser async (imgUrl).
let baseSync = "/proxy";

export function toAbsolute(u: string): string {
  if (!u) return u;
  if (/^(https?:|blob:|data:)/i.test(u)) return u;
  if (typeof location === "undefined") return u;
  try {
    return new URL(u, location.origin).href;
  } catch {
    return u;
  }
}

export async function proxyBase(): Promise<string> {
  const s = await getSettings();
  baseSync = (s.proxyUrl || "/proxy").replace(/\/+$/, "") || "/proxy";
  return baseSync;
}

export async function proxify(url: string, kind: ProxyKind = "stream"): Promise<string> {
  if (!url) return url;
  const base = await proxyBase();
  if (url.startsWith(base + "/")) return toAbsolute(url);
  return toAbsolute(`${base}/${kind}?url=${encodeURIComponent(url)}`);
}

/** Logos: los http pasan por el proxy (mixed content + hotlink protection). */
export function imgUrl(url?: string): string | undefined {
  if (!url) return undefined;
  if (/^http:\/\//i.test(url)) {
    return toAbsolute(`${baseSync}/image?url=${encodeURIComponent(url)}`);
  }
  return url;
}
'@

# ============================================================ src/hooks/usePlayer.ts
Write-ProjectFile 'src/hooks/usePlayer.ts' @'
/**
 * Motor de reproduccion.
 *  - hls.js  -> .m3u8
 *  - mpegts.js -> MPEG-TS / FLV (worker DESACTIVADO: maxima compatibilidad)
 *  - <video> nativo -> mp4 / webm / mov
 *  - Cadena de fuentes: prueba .m3u8 y .ts del mismo canal antes de rendirse.
 *  - URLs siempre absolutas (ver services/proxy.ts).
 *  - Reintentos, watchdog, recuperacion de stalls, autoplay bloqueado,
 *    progreso guardado y reanudacion para VOD.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import Hls from "hls.js";
import mpegts from "mpegts.js";
import type { Channel } from "../types";
import { proxify } from "../services/proxy";
import { db } from "../db";

type MpegtsPlayer = ReturnType<typeof mpegts.createPlayer>;
export type EngineKind = "hls" | "ts" | "flv" | "native";
export interface Track { id: number; label: string }

export interface PlayerState {
  loading: boolean;
  error: string | null;
  isPlaying: boolean;
  blocked: boolean;
  stalled: boolean;
  currentTime: number;
  duration: number;
  buffered: number;
  volume: number;
  muted: boolean;
  playbackRate: number;
  audioTracks: Track[];
  subtitleTracks: Track[];
  activeAudio: number;
  activeSubtitle: number;
  extSubs: { id: string; label: string }[];
  activeExtSub: string | null;
  subOffset: number;
  engine: EngineKind | null;
  attempt: number;
  attempts: number;
}

const INITIAL: PlayerState = {
  loading: true,
  error: null,
  isPlaying: false,
  blocked: false,
  stalled: false,
  currentTime: 0,
  duration: 0,
  buffered: 0,
  volume: 1,
  muted: false,
  playbackRate: 1,
  audioTracks: [],
  subtitleTracks: [],
  activeAudio: -1,
  activeSubtitle: -1,
  extSubs: [],
  activeExtSub: null,
  subOffset: 0,
  engine: null,
  attempt: 0,
  attempts: 0,
};

function pathOf(raw: string): string {
  try { return new URL(raw).pathname.toLowerCase(); }
  catch { return raw.split("?")[0].toLowerCase(); }
}

export function detectKind(raw: string): EngineKind {
  const p = pathOf(raw);
  if (p.endsWith(".m3u8") || /[?&](type|output)=m3u8/i.test(raw)) return "hls";
  if (p.endsWith(".flv")) return "flv";
  if (p.endsWith(".ts")) return "ts";
  if (/\.(mp4|m4v|webm|mkv|mov|avi|wmv)$/.test(p)) return "native";
  if (/^\/(live\/)?[^/]+\/[^/]+\/\d+$/.test(p)) return "ts";
  return "native";
}

function buildCandidates(ch: Channel): string[] {
  const list = [ch.url, ...(ch.altUrls ?? [])].filter(Boolean);
  if (ch.category === "live") {
    const m = ch.url.match(
      /^(https?:\/\/[^/]+)\/(?:live\/)?([^/]+)\/([^/]+)\/(\d+)(?:\.(?:ts|m3u8))?(?:\?.*)?$/i
    );
    if (m) {
      const base = `${m[1]}/live/${m[2]}/${m[3]}/${m[4]}`;
      list.push(`${base}.m3u8`, `${base}.ts`, base);
    }
  }
  return Array.from(new Set(list));
}

export function usePlayer(channel: Channel | null) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const hlsRef = useRef<Hls | null>(null);
  const tsRef = useRef<MpegtsPlayer | null>(null);
  const extTracksRef = useRef<{ id: string; el: HTMLTrackElement; url: string; offset: number }[]>([]);
  const activeExtRef = useRef<string | null>(null);
  const channelRef = useRef<Channel | null>(channel);
  channelRef.current = channel;

  const [reloadKey, setReloadKey] = useState(0);
  const [state, setState] = useState<PlayerState>(INITIAL);

  const destroyEngines = useCallback(() => {
    if (hlsRef.current) { try { hlsRef.current.destroy(); } catch {} hlsRef.current = null; }
    if (tsRef.current) {
      try { tsRef.current.pause(); tsRef.current.unload(); tsRef.current.detachMediaElement(); tsRef.current.destroy(); }
      catch {}
      tsRef.current = null;
    }
  }, []);

  const clearExtSubs = useCallback(() => {
    for (const t of extTracksRef.current) { try { t.el.remove(); URL.revokeObjectURL(t.url); } catch {} }
    extTracksRef.current = [];
    activeExtRef.current = null;
  }, []);

  useEffect(() => () => { destroyEngines(); clearExtSubs(); }, [destroyEngines, clearExtSubs]);

  // ---------------------------------------------------------------- carga
  useEffect(() => {
    const video = videoRef.current;
    if (!video || !channel) return;

    const candidates = buildCandidates(channel);
    if (candidates.length === 0) {
      setState({ ...INITIAL, loading: false, error: "Este elemento no tiene URL de reproduccion." });
      return;
    }

    const isLive = channel.category === "live";
    let alive = true;
    let idx = 0;
    let watchdog: number | undefined;
    let stallTimer: number | undefined;
    let resumeAt = 0;
    let resumeDone = isLive;
    let softRetries = 0;

    const clearWatchdog = () => { if (watchdog) window.clearTimeout(watchdog); watchdog = undefined; };
    const clearStall = () => { if (stallTimer) window.clearTimeout(stallTimer); stallTimer = undefined; };

    const applyResume = () => {
      if (resumeDone || !resumeAt) return;
      const d = video.duration;
      if (!isFinite(d) || d <= 0) return;
      resumeDone = true;
      if (resumeAt < d - 12) { try { video.currentTime = resumeAt; } catch {} }
    };

    if (!isLive) {
      db.history.get(channel.id)
        .then((h) => {
          if (!alive || !h) { resumeDone = true; return; }
          if (h.duration > 0 && h.position > 30 && h.position < h.duration * 0.97) {
            resumeAt = h.position;
            applyResume();
          } else { resumeDone = true; }
        })
        .catch(() => { resumeDone = true; });
    }

    const failFinal = (msg: string) => {
      clearWatchdog(); clearStall();
      const tried = candidates.length > 1 ? ` (se probaron ${candidates.length} fuentes)` : "";
      setState((s) => ({ ...s, error: msg + tried, loading: false, stalled: false }));
    };

    const next = (msg: string) => {
      if (!alive) return;
      clearWatchdog(); clearStall();
      if (idx + 1 < candidates.length) { idx++; void start(); }
      else failFinal(msg);
    };

    const softRecover = () => {
      if (!alive || softRetries >= 2) return false;
      softRetries++;
      if (hlsRef.current) { try { hlsRef.current.startLoad(); } catch {} return true; }
      if (tsRef.current) { try { tsRef.current.unload(); tsRef.current.load(); tsRef.current.play(); } catch {} return true; }
      return false;
    };

    const onPlaying = () => {
      clearWatchdog(); clearStall();
      softRetries = 0;
      setState((s) => ({ ...s, loading: false, stalled: false, blocked: false, error: null }));
    };
    const onWaiting = () => {
      clearStall();
      stallTimer = window.setTimeout(() => {
        if (!alive) return;
        setState((s) => ({ ...s, stalled: true }));
        if (!softRecover()) next("La fuente dejo de enviar datos");
      }, 9000);
    };
    const onMeta = () => applyResume();

    video.addEventListener("playing", onPlaying);
    video.addEventListener("waiting", onWaiting);
    video.addEventListener("loadedmetadata", onMeta);

    const start = async () => {
      destroyEngines();
      clearExtSubs();
      try { video.removeAttribute("src"); video.load(); } catch {}
      setState((s) => ({
        ...s,
        loading: true, error: null, stalled: false, blocked: false,
        audioTracks: [], subtitleTracks: [], activeAudio: -1, activeSubtitle: -1,
        extSubs: [], activeExtSub: null, subOffset: 0,
        currentTime: 0, duration: 0, buffered: 0,
        attempt: idx + 1, attempts: candidates.length,
      }));

      const raw = candidates[idx];
      const kind = detectKind(raw);
      let url = "";
      try { url = await proxify(raw, "stream"); }
      catch (e: any) { return next(e?.message || "No se pudo preparar la URL del proxy"); }
      if (!alive) return;

      setState((s) => ({ ...s, engine: kind }));
      clearWatchdog();
      watchdog = window.setTimeout(
        () => next(isLive ? "El canal no responde" : "La fuente no responde"),
        isLive ? 14000 : 22000
      );

      const tryPlay = () => {
        video.play().catch((err: any) => {
          if (!alive) return;
          if (err && (err.name === "NotAllowedError" || err.name === "AbortError")) {
            setState((s) => ({ ...s, blocked: err.name === "NotAllowedError", loading: false }));
          }
        });
      };

      try {
        if (kind === "hls") {
          if (Hls.isSupported()) {
            const hls = new Hls({
              enableWorker: true,
              lowLatencyMode: false,
              backBufferLength: isLive ? 30 : 90,
              maxBufferLength: isLive ? 20 : 40,
              manifestLoadingTimeOut: 12000,
              manifestLoadingMaxRetry: 1,
              levelLoadingTimeOut: 12000,
              fragLoadingTimeOut: 22000,
            });
            hlsRef.current = hls;
            let net = 0, med = 0;
            hls.on(Hls.Events.MANIFEST_PARSED, () => {
              if (!alive) return;
              setState((s) => ({
                ...s,
                audioTracks: hls.audioTracks.map((t, i) => ({ id: i, label: t.name || t.lang || `Audio ${i + 1}` })),
                subtitleTracks: hls.subtitleTracks.map((t, i) => ({ id: i, label: t.name || t.lang || `Sub ${i + 1}` })),
                activeAudio: hls.audioTrack ?? 0,
                activeSubtitle: -1,
              }));
              tryPlay();
            });
            hls.on(Hls.Events.ERROR, (_e, data) => {
              if (!alive || !data.fatal) return;
              if (data.type === Hls.ErrorTypes.NETWORK_ERROR && net < 2) { net++; hls.startLoad(); }
              else if (data.type === Hls.ErrorTypes.MEDIA_ERROR && med < 2) {
                med++;
                if (med === 1) hls.recoverMediaError();
                else { try { hls.swapAudioCodec(); } catch {} hls.recoverMediaError(); }
              } else next(`HLS: ${data.details}`);
            });
            hls.loadSource(url);
            hls.attachMedia(video);
          } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
            video.src = url;
            tryPlay();
          } else { next("HLS no soportado en este navegador"); }
          return;
        }

        if (kind === "ts" || kind === "flv") {
          if (!mpegts.isSupported()) return next("Este navegador no soporta MPEG-TS");
          const player = mpegts.createPlayer(
            { type: kind === "flv" ? "flv" : "mpegts", url, isLive, cors: true },
            {
              // Worker OFF: evita el fetch en WorkerGlobalScope y los problemas
              // de Blob-URL en Safari/WebView. El demux en hilo principal es
              // suficiente para un unico stream.
              enableWorker: false,
              isLive,
              lazyLoad: !isLive,
              enableStashBuffer: !isLive,
              stashInitialSize: 384,
              liveBufferLatencyChasing: isLive,
              liveBufferLatencyMaxLatency: 4,
              liveBufferLatencyMinRemain: 1,
              autoCleanupSourceBuffer: true,
            }
          );
          tsRef.current = player;
          player.attachMediaElement(video);
          player.on(mpegts.Events.ERROR, (_t: string, detail: string, info: any) => {
            const http = info?.code ? ` (HTTP ${info.code})` : "";
            const msg = info?.msg ? ` - ${info.msg}` : "";
            next(`TS/FLV: ${detail}${http}${msg}`);
          });
          player.load();
          tryPlay();
          return;
        }

        video.src = url;
        tryPlay();
      } catch (e: any) { next(e?.message || "Error al cargar el stream"); }
    };

    void start();

    // -------------------------------------------------- progreso (solo VOD)
    let saver: number | undefined;
    const persist = () => {
      const ch = channelRef.current;
      if (!ch || ch.category === "live") return;
      const d = video.duration;
      const p = video.currentTime;
      if (!isFinite(d) || d < 60 || !isFinite(p) || p < 5) return;
      if (p / d > 0.97) { void db.history.delete(ch.id).catch(() => {}); return; }
      void db.history.put({
        id: ch.id, position: p, duration: d, updatedAt: Date.now(),
        name: ch.name, logo: ch.logo, group: ch.group,
        playlistId: ch.playlistId, category: ch.category,
      }).catch(() => {});
    };
    if (!isLive) saver = window.setInterval(persist, 5000);

    return () => {
      alive = false;
      clearWatchdog(); clearStall();
      if (saver) window.clearInterval(saver);
      persist();
      video.removeEventListener("playing", onPlaying);
      video.removeEventListener("waiting", onWaiting);
      video.removeEventListener("loadedmetadata", onMeta);
      destroyEngines();
      clearExtSubs();
    };
  }, [channel?.id, reloadKey, destroyEngines, clearExtSubs]);

  // ------------------------------------------------------- eventos <video>
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    const onPlay = () => setState((s) => ({ ...s, isPlaying: true, blocked: false }));
    const onPause = () => setState((s) => ({ ...s, isPlaying: false }));
    const onCanPlay = () => setState((s) => ({ ...s, loading: false }));
    const onTime = () => {
      let buf = 0;
      try {
        const b = video.buffered;
        for (let i = 0; i < b.length; i++) {
          if (b.start(i) <= video.currentTime && b.end(i) >= video.currentTime) { buf = b.end(i); break; }
        }
        if (!buf && b.length) buf = b.end(b.length - 1);
      } catch {}
      setState((s) => ({
        ...s,
        currentTime: video.currentTime,
        duration: isFinite(video.duration) ? video.duration : 0,
        buffered: buf,
      }));
    };
    const onVolume = () => setState((s) => ({ ...s, volume: video.volume, muted: video.muted }));
    const onEnded = () => {
      const ch = channelRef.current;
      if (ch && ch.category !== "live") void db.history.delete(ch.id).catch(() => {});
      setState((s) => ({ ...s, isPlaying: false }));
    };
    video.addEventListener("play", onPlay);
    video.addEventListener("pause", onPause);
    video.addEventListener("canplay", onCanPlay);
    video.addEventListener("timeupdate", onTime);
    video.addEventListener("volumechange", onVolume);
    video.addEventListener("ended", onEnded);
    return () => {
      video.removeEventListener("play", onPlay);
      video.removeEventListener("pause", onPause);
      video.removeEventListener("canplay", onCanPlay);
      video.removeEventListener("timeupdate", onTime);
      video.removeEventListener("volumechange", onVolume);
      video.removeEventListener("ended", onEnded);
    };
  }, []);

  useEffect(() => { activeExtRef.current = state.activeExtSub; }, [state.activeExtSub]);

  const actions = {
    playPause: () => {
      const v = videoRef.current;
      if (!v) return;
      if (v.paused) v.play().catch(() => setState((s) => ({ ...s, blocked: true })));
      else v.pause();
    },
    unblock: () => {
      const v = videoRef.current;
      if (!v) return;
      v.play().then(() => setState((s) => ({ ...s, blocked: false }))).catch(() => {});
    },
    seek: (t: number) => {
      const v = videoRef.current;
      if (v && isFinite(v.duration) && v.duration > 0) v.currentTime = Math.max(0, Math.min(v.duration, t));
    },
    seekBy: (d: number) => {
      const v = videoRef.current;
      if (v && isFinite(v.duration) && v.duration > 0) {
        v.currentTime = Math.max(0, Math.min(v.duration, v.currentTime + d));
      }
    },
    setVolume: (vol: number) => {
      const v = videoRef.current;
      if (v) { v.volume = Math.max(0, Math.min(1, vol)); if (vol > 0) v.muted = false; }
    },
    setMuted: (m: boolean) => { const v = videoRef.current; if (v) v.muted = m; },
    setPlaybackRate: (r: number) => {
      const v = videoRef.current;
      if (v) v.playbackRate = r;
      setState((s) => ({ ...s, playbackRate: r }));
    },
    setAudioTrack: (id: number) => {
      if (hlsRef.current) { hlsRef.current.audioTrack = id; setState((s) => ({ ...s, activeAudio: id })); }
    },
    setSubtitleTrack: (id: number) => {
      if (hlsRef.current) { hlsRef.current.subtitleTrack = id; setState((s) => ({ ...s, activeSubtitle: id })); }
    },
    requestPiP: async () => {
      const v = videoRef.current;
      if (!v) return;
      try {
        if (document.pictureInPictureElement) await document.exitPictureInPicture();
        else if (v.requestPictureInPicture) await v.requestPictureInPicture();
      } catch {}
    },
    addSubtitle: (label: string, vtt: string) => {
      const v = videoRef.current;
      if (!v) return;
      for (const t of extTracksRef.current) t.el.track.mode = "disabled";
      Array.from(v.textTracks).forEach((t) => { if (t.mode === "showing") t.mode = "disabled"; });
      const url = URL.createObjectURL(new Blob([vtt], { type: "text/vtt" }));
      const el = document.createElement("track");
      el.kind = "subtitles"; el.label = label; el.src = url; el.default = true;
      v.appendChild(el);
      const id = String(Date.now()) + Math.random().toString(36).slice(2, 5);
      el.track.mode = "showing";
      extTracksRef.current.push({ id, el, url, offset: 0 });
      activeExtRef.current = id;
      setState((s) => ({
        ...s, extSubs: [...s.extSubs, { id, label }], activeExtSub: id, subOffset: 0, activeSubtitle: -1,
      }));
    },
    setExtSubtitle: (id: string | null) => {
      for (const t of extTracksRef.current) t.el.track.mode = t.id === id ? "showing" : "disabled";
      const cur = extTracksRef.current.find((t) => t.id === id);
      activeExtRef.current = id;
      setState((s) => ({ ...s, activeExtSub: id, subOffset: cur?.offset ?? 0 }));
    },
    shiftSubtitles: (delta: number) => {
      const cur = extTracksRef.current.find((t) => t.id === activeExtRef.current);
      if (!cur) return;
      const cues = cur.el.track.cues;
      if (!cues) return;
      for (const c of Array.from(cues)) {
        const st = Math.max(0, c.startTime + delta);
        const en = Math.max(st + 0.05, c.endTime + delta);
        c.startTime = st; c.endTime = en;
      }
      cur.offset = Math.round((cur.offset + delta) * 10) / 10;
      setState((s) => ({ ...s, subOffset: cur.offset }));
    },
    retry: () => setReloadKey((k) => k + 1),
  };

  return { videoRef, state, actions };
}
'@

# =========================================================== src/hooks/useHistory.ts
Write-ProjectFile 'src/hooks/useHistory.ts' @'
import { useCallback } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { db } from "../db";
import type { Channel, WatchHistory } from "../types";

export interface ResumeItem {
  history: WatchHistory;
  channel: Channel;
  percent: number;
}

/** "Continuar viendo": empezados y no terminados, mas recientes primero. */
export function useContinueWatching(limit = 14): ResumeItem[] {
  const rows = useLiveQuery(async () => {
    const hist = await db.history.orderBy("updatedAt").reverse().limit(limit * 3).toArray();
    const usable = hist.filter((h) => h.duration > 0 && h.position > 30 && h.position / h.duration < 0.97);
    if (usable.length === 0) return [] as ResumeItem[];
    const found = await db.channels.bulkGet(usable.map((h) => h.id));
    const out: ResumeItem[] = [];
    usable.forEach((h, i) => {
      const ch = found[i];
      if (!ch) return;
      out.push({ history: h, channel: ch, percent: Math.min(99, (h.position / h.duration) * 100) });
    });
    return out.slice(0, limit);
  }, [limit]);
  return rows ?? [];
}

export function useRemoveResume() {
  return useCallback((id: string) => { void db.history.delete(id).catch(() => {}); }, []);
}
'@

# ======================================================== src/hooks/useSpatialNav.ts
Write-ProjectFile 'src/hooks/useSpatialNav.ts' @'
/**
 * Navegacion espacial por foco (flechas / D-pad / mando TV).
 * Elige el elemento enfocable mas cercano en la direccion pulsada,
 * ponderando distancia en el eje principal y desalineacion en el cruzado.
 * El reproductor gestiona sus propias flechas y los modales bloquean el fondo.
 */
import { useEffect } from "react";

const SELECTOR = '[data-focusable="true"]';
const DIRS: Record<string, [number, number]> = {
  ArrowUp: [0, -1], ArrowDown: [0, 1], ArrowLeft: [-1, 0], ArrowRight: [1, 0],
};

function isTyping(el: Element | null): boolean {
  if (!el) return false;
  const t = el as HTMLElement;
  return t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.tagName === "SELECT" || t.isContentEditable === true;
}

export function useSpatialNav(enabled = true) {
  useEffect(() => {
    if (!enabled) return;

    const collect = (): HTMLElement[] => {
      const lock = document.querySelector("[data-nav-lock]");
      const root: ParentNode = lock ?? document;
      return (Array.from(root.querySelectorAll(SELECTOR)) as HTMLElement[]).filter((n) => {
        const r = n.getBoundingClientRect();
        return r.width > 1 && r.height > 1 && !n.hasAttribute("disabled");
      });
    };

    const pick = (nodes: HTMLElement[], dir: [number, number]): HTMLElement | null => {
      const active = document.activeElement as HTMLElement | null;
      if (!active || !nodes.includes(active)) return nodes[0] ?? null;
      const a = active.getBoundingClientRect();
      const ax = a.left + a.width / 2;
      const ay = a.top + a.height / 2;
      let best: HTMLElement | null = null;
      let bestScore = Infinity;
      for (const n of nodes) {
        if (n === active) continue;
        const r = n.getBoundingClientRect();
        const dx = r.left + r.width / 2 - ax;
        const dy = r.top + r.height / 2 - ay;
        const primary = dx * dir[0] + dy * dir[1];
        if (primary < 6) continue;
        const cross = Math.abs(dx * dir[1] - dy * dir[0]);
        const score = primary + cross * 2.4;
        if (score < bestScore) { bestScore = score; best = n; }
      }
      return best;
    };

    const onKey = (e: KeyboardEvent) => {
      if (e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
      const dir = DIRS[e.key];
      if (!dir) return;
      const target = e.target as HTMLElement | null;
      if (isTyping(target)) return;
      if (target && target.closest('[data-nav-scope="player"]')) return;

      const nodes = collect();
      if (nodes.length === 0) return;

      const found = pick(nodes, dir);
      if (found) {
        e.preventDefault();
        found.focus({ preventScroll: true });
        found.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "smooth" });
        return;
      }

      // Lista virtualizada: el siguiente puede no estar montado aun.
      if (dir[1] !== 0) {
        e.preventDefault();
        window.scrollBy({ top: dir[1] * window.innerHeight * 0.55, behavior: "smooth" });
        window.setTimeout(() => {
          const again = pick(collect(), dir);
          if (again) { again.focus({ preventScroll: true }); again.scrollIntoView({ block: "nearest", behavior: "smooth" }); }
        }, 260);
      }
    };

    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [enabled]);
}
'@

# ============================================================= src/store/index.ts
Write-ProjectFile 'src/store/index.ts' @'
import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Channel } from "../types";

interface UIState {
  sidebarOpen: boolean;
  setSidebarOpen: (v: boolean) => void;
  toggleSidebar: () => void;

  activePlaylistId: string | null;
  setActivePlaylistId: (id: string | null) => void;

  nowPlaying: Channel | null;
  setNowPlaying: (c: Channel | null) => void;

  /** Cola de zapping: la lista filtrada desde la que se lanzo el canal. */
  queue: Channel[];
  play: (c: Channel, list?: Channel[]) => void;
  zap: (delta: number) => void;
  zapTo: (index: number) => void;

  openSeries: Channel | null;
  closeSeries: () => void;
}

export const useStore = create<UIState>()(
  persist(
    (set, get) => ({
      sidebarOpen: false,
      setSidebarOpen: (v) => set({ sidebarOpen: v }),
      toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),

      activePlaylistId: null,
      setActivePlaylistId: (id) => set({ activePlaylistId: id }),

      nowPlaying: null,
      queue: [],
      setNowPlaying: (c) =>
        set((s) => {
          if (c && c.seriesId) return { openSeries: c };
          if (!c) return { nowPlaying: null };
          const inQueue = s.queue.some((x) => x.id === c.id);
          return { nowPlaying: c, queue: inQueue ? s.queue : [c] };
        }),

      play: (c, list) => set({ nowPlaying: c, queue: list && list.length ? list : [c] }),

      zap: (delta) => {
        const { queue, nowPlaying } = get();
        if (!nowPlaying || queue.length < 2) return;
        const i = queue.findIndex((x) => x.id === nowPlaying.id);
        if (i < 0) return;
        const n = (i + delta + queue.length) % queue.length;
        set({ nowPlaying: queue[n] });
      },

      zapTo: (index) => {
        const { queue } = get();
        if (index >= 0 && index < queue.length) set({ nowPlaying: queue[index] });
      },

      openSeries: null,
      closeSeries: () => set({ openSeries: null }),
    }),
    {
      name: "streambox-ui",
      partialize: (s) => ({ activePlaylistId: s.activePlaylistId }),
    }
  )
);
'@

# ======================================================= src/components/ChannelCard.tsx
Write-ProjectFile 'src/components/ChannelCard.tsx' @'
import { memo, useState } from "react";
import { clsx } from "clsx";
import { Star, Play } from "lucide-react";
import type { Channel } from "../types";
import { imgUrl } from "../services/proxy";

interface Props {
  channel: Channel;
  isFavorite: boolean;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
  index?: number;
}

const TONE: Record<Channel["category"], string> = {
  live: "text-brand", movies: "text-gold", series: "text-iris", other: "text-aqua",
};

function CardBase({ channel, isFavorite, onToggleFavorite, onPlay, index }: Props) {
  const [imgError, setImgError] = useState(false);
  const logo = imgUrl(channel.logo);

  return (
    <div
      data-focusable="true" tabIndex={0} role="button" title={channel.name}
      aria-label={`Reproducir ${channel.name}`}
      onClick={() => onPlay(channel)}
      onKeyDown={(e) => {
        if (e.target !== e.currentTarget) return;
        if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onPlay(channel); }
      }}
      className="group relative flex h-[72px] items-center gap-3 rounded-xl border border-white/5 bg-bg-card px-3 hover:border-brand/40 hover:bg-bg-hover cursor-pointer"
    >
      <div className="relative h-12 w-12 shrink-0 overflow-hidden rounded-lg bg-bg-deep ring-1 ring-white/5">
        {logo && !imgError ? (
          <img src={logo} alt="" loading="lazy" decoding="async" onError={() => setImgError(true)} className="h-full w-full object-contain p-1" />
        ) : (
          <span className="flex h-full w-full items-center justify-center text-[11px] font-bold text-ink-dim">
            {channel.name.replace(/[^\p{L}\p{N}]/gu, "").slice(0, 2).toUpperCase() || "TV"}
          </span>
        )}
        <span className="absolute inset-0 flex items-center justify-center bg-black/60 opacity-0 transition-opacity group-hover:opacity-100">
          <Play className="h-5 w-5 text-white" fill="currentColor" />
        </span>
      </div>

      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold leading-tight">{channel.name}</p>
        <p className="mt-0.5 truncate text-xs text-ink-muted">
          {index != null && <span className={clsx("font-mono", TONE[channel.category])}>{index + 1} · </span>}
          {channel.group || "Sin categoria"}
        </p>
      </div>

      <button
        onClick={(e) => { e.stopPropagation(); onToggleFavorite(channel.id); }}
        className="rounded-full p-2 hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-brand"
        aria-label={isFavorite ? "Quitar de favoritos" : "Anadir a favoritos"}
      >
        <Star className={clsx("h-5 w-5", isFavorite ? "fill-gold text-gold" : "text-ink-dim")} />
      </button>
    </div>
  );
}

export const ChannelCard = memo(CardBase);
'@

# ======================================================= src/components/ChannelGrid.tsx
Write-ProjectFile 'src/components/ChannelGrid.tsx' @'
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
'@

# ========================================================= src/components/BottomNav.tsx
Write-ProjectFile 'src/components/BottomNav.tsx' @'
import { NavLink } from "react-router-dom";
import { Home, Tv, Film, Clapperboard, Search } from "lucide-react";
import { clsx } from "clsx";

const items = [
  { to: "/", label: "Inicio", icon: Home },
  { to: "/live", label: "TV", icon: Tv },
  { to: "/movies", label: "Pelis", icon: Film },
  { to: "/series", label: "Series", icon: Clapperboard },
  { to: "/search", label: "Buscar", icon: Search },
];

export function BottomNav() {
  return (
    <nav className="safe-bottom fixed inset-x-0 bottom-0 z-30 border-t border-white/10 bg-bg-deep/95 backdrop-blur-xl lg:hidden">
      <ul className="mx-auto flex max-w-lg items-stretch justify-between px-1 pt-1">
        {items.map((it) => (
          <li key={it.to} className="flex-1">
            <NavLink to={it.to} end={it.to === "/"}
              className={({ isActive }) => clsx(
                "flex flex-col items-center gap-1 rounded-lg px-1 py-2 text-[10px] font-semibold transition-colors",
                isActive ? "text-brand" : "text-ink-dim hover:text-ink"
              )}
            >
              {({ isActive }) => (
                <>
                  <span className={clsx("flex h-7 w-12 items-center justify-center rounded-full transition-colors", isActive && "bg-brand/15")}>
                    <it.icon className="h-[18px] w-[18px]" />
                  </span>
                  {it.label}
                </>
              )}
            </NavLink>
          </li>
        ))}
      </ul>
    </nav>
  );
}
'@

# ==================================================== src/components/ContinueWatching.tsx
Write-ProjectFile 'src/components/ContinueWatching.tsx' @'
import { Play, X } from "lucide-react";
import { useContinueWatching, useRemoveResume } from "../hooks/useHistory";
import { useStore } from "../store";
import { imgUrl } from "../services/proxy";

function left(min: number) {
  const m = Math.max(1, Math.round(min));
  if (m < 60) return `${m} min restantes`;
  return `${Math.floor(m / 60)} h ${m % 60} min restantes`;
}

export function ContinueWatching() {
  const items = useContinueWatching();
  const remove = useRemoveResume();
  const setNowPlaying = useStore((s) => s.setNowPlaying);
  const setActivePlaylistId = useStore((s) => s.setActivePlaylistId);

  if (items.length === 0) return null;

  return (
    <section className="animate-slide-up">
      <div className="mb-3 flex items-baseline gap-3">
        <h2 className="text-xl font-bold">Continuar viendo</h2>
        <span className="text-xs font-semibold uppercase tracking-widest text-aqua">Retoma donde lo dejaste</span>
      </div>

      <div className="no-scrollbar -mx-1 flex snap-x gap-3 overflow-x-auto px-1 pb-2">
        {items.map(({ channel, history, percent }) => {
          const poster = imgUrl(channel.logo);
          return (
            <div key={channel.id} className="group relative w-[168px] shrink-0 snap-start">
              <button
                data-focusable="true"
                onClick={() => {
                  if (channel.playlistId) setActivePlaylistId(channel.playlistId);
                  setNowPlaying(channel);
                }}
                className="block w-full overflow-hidden rounded-xl border border-white/5 bg-bg-card text-left hover:border-aqua/50"
              >
                <div className="relative aspect-video w-full overflow-hidden bg-bg-deep">
                  {poster ? (
                    <img src={poster} alt="" loading="lazy" className="h-full w-full object-contain p-3" />
                  ) : (
                    <span className="flex h-full w-full items-center justify-center px-3 text-center text-xs text-ink-dim">{channel.name.slice(0, 40)}</span>
                  )}
                  <span className="absolute inset-0 flex items-center justify-center bg-black/55 opacity-0 transition-opacity group-hover:opacity-100">
                    <Play className="h-8 w-8 text-white" fill="currentColor" />
                  </span>
                  <span className="absolute inset-x-0 bottom-0 h-1 bg-black/70">
                    <span className="block h-full bg-gradient-to-r from-aqua to-iris" style={{ width: `${percent}%` }} />
                  </span>
                </div>
                <div className="p-2.5">
                  <p className="truncate text-sm font-semibold">{channel.name}</p>
                  <p className="mt-0.5 text-[11px] text-ink-muted">{left((history.duration - history.position) / 60)}</p>
                </div>
              </button>

              <button
                onClick={() => remove(channel.id)}
                aria-label={`Quitar ${channel.name} de continuar viendo`}
                className="absolute right-1.5 top-1.5 rounded-full bg-black/70 p-1.5 opacity-0 transition-opacity hover:bg-danger focus-visible:opacity-100 group-hover:opacity-100"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          );
        })}
      </div>
    </section>
  );
}
'@

# ============================================================ src/components/Player.tsx
Write-ProjectFile 'src/components/Player.tsx' @'
import { useEffect, useRef, useState } from "react";
import {
  Play, Pause, Volume2, VolumeX, Maximize, Minimize, Settings,
  SkipBack, SkipForward, X, Loader2, AlertTriangle, ChevronLeft, ChevronRight,
} from "lucide-react";
import { clsx } from "clsx";
import { usePlayer } from "../hooks/usePlayer";
import { SubtitleDialog } from "./SubtitleDialog";
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
          <p className="max-w-md text-sm text-ink">{state.error}</p>
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
'@

# ============================================================ src/components/Layout.tsx
Write-ProjectFile 'src/components/Layout.tsx' @'
import { Outlet } from "react-router-dom";
import { Menu } from "lucide-react";
import { Sidebar } from "./Sidebar";
import { BottomNav } from "./BottomNav";
import { Player } from "./Player";
import { SeriesDetail } from "./SeriesDetail";
import { useStore } from "../store";
import { useSpatialNav } from "../hooks/useSpatialNav";

export function Layout() {
  const toggleSidebar = useStore((s) => s.toggleSidebar);
  const nowPlaying = useStore((s) => s.nowPlaying);
  const setNowPlaying = useStore((s) => s.setNowPlaying);
  const queue = useStore((s) => s.queue);
  const zap = useStore((s) => s.zap);
  const zapTo = useStore((s) => s.zapTo);
  const openSeries = useStore((s) => s.openSeries);

  useSpatialNav(true);

  const index = nowPlaying ? queue.findIndex((c) => c.id === nowPlaying.id) : -1;
  const canZap = index >= 0 && queue.length > 1;

  return (
    <div className="relative min-h-screen">
      {/* Fondo con profundidad: mesh + grano, estatico y barato */}
      <div aria-hidden className="pointer-events-none fixed inset-0 -z-10 overflow-hidden bg-bg">
        <div className="absolute -left-40 -top-40 h-[520px] w-[520px] animate-drift rounded-full bg-brand/18 blur-[130px]" />
        <div className="absolute -right-32 top-1/4 h-[460px] w-[460px] animate-drift rounded-full bg-iris/14 blur-[140px]" />
        <div className="absolute bottom-0 left-1/3 h-[420px] w-[420px] animate-drift rounded-full bg-aqua/10 blur-[150px]" />
        <div className="grain absolute inset-0 opacity-[0.035] mix-blend-overlay" />
      </div>

      <div className="flex min-h-screen">
        <Sidebar />
        <div className="flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-20 flex items-center gap-3 border-b border-white/5 bg-bg/85 px-4 py-3 backdrop-blur-xl lg:hidden">
            <button onClick={toggleSidebar} className="rounded-lg p-2 hover:bg-white/10" aria-label="Abrir menu"><Menu className="h-5 w-5" /></button>
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-md bg-brand text-sm font-bold">S</div>
              <span className="font-semibold">StreamBox</span>
            </div>
          </header>

          <main className="mx-auto w-full max-w-[1600px] flex-1 p-4 pb-28 md:p-6 lg:p-8 lg:pb-10">
            {nowPlaying && (
              <div className="sticky top-[53px] z-10 mb-4 bg-bg/95 pb-3 backdrop-blur lg:top-0">
                <div className="max-w-5xl">
                  <Player
                    channel={nowPlaying}
                    onClose={() => setNowPlaying(null)}
                    onPrev={canZap ? () => zap(-1) : undefined}
                    onNext={canZap ? () => zap(1) : undefined}
                    onJump={canZap ? (i) => zapTo(i) : undefined}
                    position={canZap ? { index, total: queue.length } : undefined}
                  />
                </div>
              </div>
            )}
            <Outlet />
          </main>
        </div>
      </div>

      <BottomNav />

      <div {...(openSeries ? { "data-nav-lock": "modal" } : {})}>
        <SeriesDetail />
      </div>
    </div>
  );
}
'@

# =========================================================== src/components/Sidebar.tsx
Write-ProjectFile 'src/components/Sidebar.tsx' @'
import { NavLink } from "react-router-dom";
import { Home, Tv, Film, Clapperboard, Star, Search, Settings, ListVideo, X } from "lucide-react";
import { clsx } from "clsx";
import { useStore } from "../store";

const items = [
  { to: "/", label: "Inicio", icon: Home },
  { to: "/live", label: "TV en vivo", icon: Tv },
  { to: "/movies", label: "Peliculas", icon: Film },
  { to: "/series", label: "Series", icon: Clapperboard },
  { to: "/favorites", label: "Favoritos", icon: Star },
  { to: "/search", label: "Buscar", icon: Search },
  { to: "/playlists", label: "Mis listas", icon: ListVideo },
  { to: "/settings", label: "Ajustes", icon: Settings },
];

export function Sidebar() {
  const sidebarOpen = useStore((s) => s.sidebarOpen);
  const setSidebarOpen = useStore((s) => s.setSidebarOpen);

  return (
    <>
      {sidebarOpen && <div className="fixed inset-0 z-30 bg-black/70 backdrop-blur-sm lg:hidden" onClick={() => setSidebarOpen(false)} />}
      <aside className={clsx(
        "fixed left-0 top-0 z-40 flex h-screen w-64 shrink-0 flex-col border-r border-white/5 bg-bg-soft/95 backdrop-blur-xl transition-transform duration-200 lg:sticky lg:translate-x-0 lg:bg-bg-soft/70",
        sidebarOpen ? "translate-x-0" : "-translate-x-full"
      )}>
        <div className="flex items-center justify-between border-b border-white/5 p-5">
          <div className="flex items-center gap-2.5">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-brand to-iris font-black shadow-card">S</div>
            <div>
              <span className="block text-lg font-bold leading-none tracking-tight">StreamBox</span>
              <span className="text-[10px] uppercase tracking-[0.18em] text-ink-dim">Tu IPTV</span>
            </div>
          </div>
          <button onClick={() => setSidebarOpen(false)} className="rounded p-1 hover:bg-white/10 lg:hidden" aria-label="Cerrar menu"><X className="h-5 w-5" /></button>
        </div>

        <nav className="flex-1 space-y-1 overflow-y-auto p-3">
          {items.map((it) => (
            <NavLink key={it.to} to={it.to} end={it.to === "/"} data-focusable="true" onClick={() => setSidebarOpen(false)}
              className={({ isActive }) => clsx(
                "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium",
                isActive ? "bg-brand/15 text-brand" : "text-ink-muted hover:bg-bg-hover hover:text-ink"
              )}
            >
              <it.icon className="h-5 w-5" /> {it.label}
            </NavLink>
          ))}
        </nav>

        <div className="border-t border-white/5 p-4 text-[11px] leading-relaxed text-ink-dim">
          <p className="font-semibold text-ink-muted">StreamBox v0.4</p>
          <p>Flechas para navegar · Enter abre</p>
        </div>
      </aside>
    </>
  );
}
'@

# ========================================================= src/pages/CategoryPage.tsx
Write-ProjectFile 'src/pages/CategoryPage.tsx' @'
import { useDeferredValue, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useLiveQuery } from "dexie-react-hooks";
import { Search } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { ChannelGrid } from "../components/ChannelGrid";
import { ChannelCardSkeleton } from "../components/SkeletonLoader";
import type { Channel } from "../types";

interface Props {
  category: Channel["category"];
  title: string;
  placeholder: string;
  noun: string;
}

export function CategoryPage({ category, title, placeholder, noun }: Props) {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const play = useStore((s) => s.play);
  const { favSet, toggle } = useFavorites();
  const [group, setGroup] = useState("Todas");
  const [query, setQuery] = useState("");
  const deferredQuery = useDeferredValue(query);

  const items = useLiveQuery(
    () => activePlaylistId ? db.channels.where("[playlistId+category]").equals([activePlaylistId, category]).toArray() : Promise.resolve([] as Channel[]),
    [activePlaylistId, category]
  );

  const groups = useMemo(() => Array.from(new Set((items ?? []).map((c) => c.group || "Sin categoria"))).sort((a, b) => a.localeCompare(b)), [items]);
  const activeGroup = groups.includes(group) ? group : "Todas";

  const filtered = useMemo(() => {
    const q = deferredQuery.trim().toLowerCase();
    return (items ?? []).filter((c) =>
      (activeGroup === "Todas" || (c.group || "Sin categoria") === activeGroup) && (!q || c.name.toLowerCase().includes(q))
    );
  }, [items, activeGroup, deferredQuery]);

  if (!activePlaylistId) {
    return (
      <div className="py-20 text-center text-ink-muted">
        <p className="mb-2">No hay ninguna lista cargada.</p>
        <Link to="/playlists" className="text-brand hover:underline">Ir a Mis listas</Link>
      </div>
    );
  }

  return (
    <div className="animate-fade-in space-y-5">
      <div>
        <h1 className="text-2xl font-bold md:text-3xl">{title}</h1>
        <p className="mt-1 text-ink-muted">{items ? `${filtered.length.toLocaleString()} ${noun}` : "Cargando…"}</p>
      </div>

      <div className="flex flex-col gap-3 md:flex-row">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ink-muted" />
          <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder={placeholder}
            className="w-full rounded-lg border border-white/10 bg-bg-card py-2 pl-9 pr-3 focus:border-brand focus:outline-none" />
        </div>
        <select value={activeGroup} onChange={(e) => setGroup(e.target.value)}
          className="rounded-lg border border-white/10 bg-bg-card px-3 py-2 focus:border-brand focus:outline-none">
          <option value="Todas">Todas las categorias</option>
          {groups.map((g) => (<option key={g} value={g}>{g}</option>))}
        </select>
      </div>

      {!items ? (
        <div className="grid gap-2 md:grid-cols-2">{Array.from({ length: 8 }).map((_, i) => <ChannelCardSkeleton key={i} />)}</div>
      ) : (
        <ChannelGrid channels={filtered} favSet={favSet} onToggleFavorite={toggle} onPlay={(c) => play(c, filtered)} emptyText={`No hay ${noun} con ese filtro.`} />
      )}
    </div>
  );
}
'@

# ================================================================ src/pages/Home.tsx
Write-ProjectFile 'src/pages/Home.tsx' @'
import { useMemo } from "react";
import { Link } from "react-router-dom";
import { useLiveQuery } from "dexie-react-hooks";
import { Tv, Film, ListVideo, Plus, Clapperboard, Star } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { imgUrl } from "../services/proxy";
import { ContinueWatching } from "../components/ContinueWatching";
import type { Channel } from "../types";

export function Home() {
  const activePlaylistId = useStore((s) => s.activePlaylistId);
  const play = useStore((s) => s.play);
  const playlists = useLiveQuery(() => db.playlists.toArray(), []);

  const data = useLiveQuery(async () => {
    if (!activePlaylistId) return null;
    const q = (cat: Channel["category"]) => db.channels.where("[playlistId+category]").equals([activePlaylistId, cat]);
    const [live, movies, series, nLive, nMovies, nSeries] = await Promise.all([
      q("live").limit(24).toArray(), q("movies").limit(24).toArray(), q("series").limit(24).toArray(),
      q("live").count(), q("movies").count(), q("series").count(),
    ]);
    return { live, movies, series, nLive, nMovies, nSeries };
  }, [activePlaylistId]);

  const active = playlists?.find((p) => p.id === activePlaylistId);
  const heroLogo = useMemo(() => imgUrl(data?.live.find((c) => c.logo)?.logo), [data]);

  if (playlists && playlists.length === 0) {
    return (
      <div className="flex animate-fade-in flex-col items-center justify-center py-24 text-center">
        <div className="mb-5 flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-brand to-iris shadow-card"><ListVideo className="h-8 w-8" /></div>
        <h1 className="text-3xl font-bold md:text-4xl">Bienvenido a StreamBox</h1>
        <p className="mt-3 max-w-md text-ink-muted">Anade tu cuenta Xtream o una lista M3U. StreamBox no incluye contenido: tu traes el tuyo.</p>
        <Link to="/playlists" data-focusable="true" className="mt-6 flex items-center gap-2 rounded-lg bg-brand px-5 py-2.5 font-semibold hover:bg-brand-hover"><Plus className="h-4 w-4" /> Anadir mi primera lista</Link>
      </div>
    );
  }

  if (!data) return null;

  return (
    <div className="animate-fade-in space-y-9">
      <section className="relative overflow-hidden rounded-2xl border border-white/10 bg-bg-card">
        {heroLogo && <img src={heroLogo} alt="" className="absolute inset-0 h-full w-full object-cover opacity-20 blur-[2px]" />}
        <div className="absolute inset-0 bg-gradient-to-r from-bg-deep via-bg-deep/85 to-transparent" />
        <div className="absolute -right-16 -top-16 h-64 w-64 rounded-full bg-brand/25 blur-[90px]" />
        <div className="relative flex min-h-[268px] flex-col justify-end p-6 md:p-10">
          <p className="text-xs font-semibold uppercase tracking-[0.22em] text-brand">{active?.name || "Lista activa"}</p>
          <h1 className="mt-2 text-3xl font-black leading-tight md:text-5xl">Tu IPTV, a un clic</h1>
          <div className="mt-3 flex flex-wrap gap-x-5 gap-y-1 text-sm text-ink-muted">
            <span><b className="text-ink">{data.nLive.toLocaleString()}</b> en vivo</span>
            <span><b className="text-gold">{data.nMovies.toLocaleString()}</b> peliculas</span>
            <span><b className="text-iris">{data.nSeries.toLocaleString()}</b> series</span>
          </div>
          <div className="mt-5 flex flex-wrap gap-2">
            <Link to="/live" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-brand px-4 py-2 font-semibold hover:bg-brand-hover"><Tv className="h-4 w-4" /> TV en vivo</Link>
            <Link to="/movies" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-white/10 px-4 py-2 font-semibold hover:bg-white/20"><Film className="h-4 w-4" /> Peliculas</Link>
            <Link to="/series" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-white/10 px-4 py-2 font-semibold hover:bg-white/20"><Clapperboard className="h-4 w-4" /> Series</Link>
            <Link to="/favorites" data-focusable="true" className="flex items-center gap-2 rounded-lg bg-white/10 px-4 py-2 font-semibold hover:bg-white/20"><Star className="h-4 w-4" /> Favoritos</Link>
          </div>
        </div>
      </section>

      <ContinueWatching />

      <Row title="Canales en vivo" accent="text-brand" items={data.live} onPlay={play} />
      <Row title="Peliculas" accent="text-gold" items={data.movies} onPlay={play} />
      <Row title="Series" accent="text-iris" items={data.series} onPlay={play} />
    </div>
  );
}

function Row({ title, accent, items, onPlay }: { title: string; accent: string; items: Channel[]; onPlay: (c: Channel, list?: Channel[]) => void }) {
  if (items.length === 0) return null;
  return (
    <section>
      <div className="mb-3 flex items-baseline gap-3">
        <h2 className="text-xl font-bold">{title}</h2>
        <span className={`text-xs font-semibold uppercase tracking-widest ${accent}`}>{items.length} destacados</span>
      </div>
      <div className="no-scrollbar -mx-1 flex snap-x gap-3 overflow-x-auto px-1 pb-2">
        {items.map((c) => (
          <button key={c.id} data-focusable="true" onClick={() => onPlay(c, items)} title={c.name}
            className="group w-40 shrink-0 snap-start rounded-lg text-left">
            <div className="aspect-video overflow-hidden rounded-lg border border-white/5 bg-bg-card transition-colors group-hover:border-brand/50">
              {c.logo ? <img src={imgUrl(c.logo)} alt="" loading="lazy" className="h-full w-full object-contain p-2" />
                : <div className="flex h-full w-full items-center justify-center p-2 text-center text-xs text-ink-muted">{c.name.slice(0, 30)}</div>}
            </div>
            <p className="mt-2 truncate text-sm font-medium">{c.name}</p>
            <p className="truncate text-xs text-ink-muted">{c.group}</p>
          </button>
        ))}
      </div>
    </section>
  );
}
'@

# ========================================================== tailwind.config.js
Write-ProjectFile 'tailwind.config.js' @'
/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: { DEFAULT: "#0b0b0f", deep: "#07070b", soft: "#12121a", card: "#181822", hover: "#22222f", line: "#2c2c3c" },
        brand: { DEFAULT: "#e50914", hover: "#ff2430", soft: "#ff6b70" },
        ink: { DEFAULT: "#f6f6f8", muted: "#a4a4b2", dim: "#6e6e80" },
        gold: { DEFAULT: "#f5a524", soft: "#ffc86b" },
        aqua: { DEFAULT: "#22d3ee", soft: "#7ee7f7" },
        iris: { DEFAULT: "#8b5cf6", soft: "#b79bff" },
        ok: "#22c55e", warn: "#f5a524", danger: "#ef4444", info: "#38bdf8",
      },
      fontFamily: { sans: ['"Inter"', "system-ui", "sans-serif"] },
      boxShadow: {
        focus: "0 0 0 3px rgba(229,9,20,.8), 0 0 26px rgba(229,9,20,.35)",
        card: "0 10px 30px -12px rgba(0,0,0,.85)",
      },
      animation: {
        "fade-in": "fadeIn .32s ease-out both",
        "slide-up": "slideUp .38s cubic-bezier(.2,.8,.2,1) both",
        "pop-in": "popIn .22s cubic-bezier(.2,.9,.3,1.3) both",
        drift: "drift 26s ease-in-out infinite alternate",
      },
      keyframes: {
        fadeIn: { "0%": { opacity: "0" }, "100%": { opacity: "1" } },
        slideUp: { "0%": { opacity: "0", transform: "translateY(14px)" }, "100%": { opacity: "1", transform: "translateY(0)" } },
        popIn: { "0%": { opacity: "0", transform: "scale(.94)" }, "100%": { opacity: "1", transform: "scale(1)" } },
        drift: { "0%": { transform: "translate3d(-4%, -2%, 0) scale(1)" }, "100%": { transform: "translate3d(5%, 3%, 0) scale(1.12)" } },
      },
    },
  },
  plugins: [],
};
'@

# =============================================================== server/index.js
Write-ProjectFile 'server/index.js' @'
// Proxy StreamBox: evita CORS y mixed content (HTTP dentro de HTTPS).
// - Sigue redirecciones en el servidor (el navegador nunca ve la URL original).
// - Reescribe manifiestos HLS para que segmentos y claves pasen por el proxy.
// - Soporta Range y streaming. En produccion sirve tambien dist/.
import express from "express";
import cors from "cors";
import path from "node:path";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { request as httpRequest } from "node:http";
import { request as httpsRequest } from "node:https";

const app = express();
const PORT = process.env.PORT || 3001;
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DIST = path.join(__dirname, "..", "dist");
const MAX_REDIRECTS = 5;
const UA_VLC = "VLC/3.0.20 LibVLC/3.0.20";

app.use(cors({ exposedHeaders: ["Content-Range", "Accept-Ranges", "Content-Length"], allowedHeaders: ["Range", "Content-Type", "Accept"] }));
app.get("/health", (_req, res) => res.json({ ok: true, uptime: process.uptime() }));

const toProxy = (kind, absoluteUrl) => `/proxy/${kind}?url=${encodeURIComponent(absoluteUrl)}`;

function rewriteHls(text, base) {
  const abs = (u) => {
    if (!u) return u;
    if (/^data:/i.test(u)) return u;
    if (u.startsWith("/proxy/")) return u;
    try { return toProxy("stream", new URL(u, base).toString()); } catch { return u; }
  };
  return text.split(/\r?\n/).map((line) => {
    const t = line.trim();
    if (!t) return line;
    if (t.startsWith("#")) return line.replace(/URI="([^"]+)"/g, (_m, u) => `URI="${abs(u)}"`);
    return abs(t);
  }).join("\n");
}

function makeHandler(kind) {
  return (req, res) => {
    const target = req.query.url;
    if (!target || typeof target !== "string") return res.status(400).json({ error: "Missing url query" });

    let current = null;
    let finished = false;
    res.on("close", () => { if (!finished && current) current.destroy(); });

    const fail = (code, msg) => { finished = true; if (!res.headersSent) res.status(code).json({ error: msg }); else res.end(); };

    const go = (urlStr, hops) => {
      let parsed;
      try { parsed = new URL(urlStr); } catch { return fail(400, "Invalid url"); }
      if (!/^https?:$/.test(parsed.protocol)) return fail(400, "Unsupported protocol");

      const isHttps = parsed.protocol === "https:";
      const headers = { "User-Agent": UA_VLC, Accept: "*/*", "Accept-Encoding": "identity", Connection: "keep-alive" };
      if (req.headers.range) headers.Range = req.headers.range;

      current = (isHttps ? httpsRequest : httpRequest)(
        { method: req.method === "HEAD" ? "HEAD" : "GET", hostname: parsed.hostname, port: parsed.port || (isHttps ? 443 : 80),
          path: parsed.pathname + parsed.search, headers, timeout: kind === "playlist" ? 180000 : 30000 },
        (upRes) => {
          const code = upRes.statusCode || 200;

          if ([301, 302, 303, 307, 308].includes(code) && upRes.headers.location) {
            upRes.resume();
            if (hops >= MAX_REDIRECTS) return fail(508, "Too many redirects");
            return go(new URL(upRes.headers.location, parsed).toString(), hops + 1);
          }

          const ct = String(upRes.headers["content-type"] || "").toLowerCase();

          // Un .ts/.m3u8 que devuelve HTML suele ser una pagina de error/login.
          if (kind === "stream" && ct.includes("text/html")) {
            upRes.resume();
            return fail(502, "El servidor devolvio una pagina HTML en lugar del stream (credenciales o limite de conexiones).");
          }

          const looksLikeManifest = kind === "stream" && (ct.includes("mpegurl") || /\.m3u8?$/i.test(parsed.pathname));

          if (looksLikeManifest && req.method !== "HEAD") {
            const chunks = [];
            upRes.on("data", (c) => chunks.push(c));
            upRes.on("end", () => {
              finished = true;
              const text = Buffer.concat(chunks).toString("utf8");
              const body = text.includes("#EXT-X-") ? rewriteHls(text, parsed) : text;
              res.status(code);
              res.setHeader("Content-Type", ct || "application/vnd.apple.mpegurl");
              res.setHeader("Cache-Control", "no-store");
              res.setHeader("Content-Length", Buffer.byteLength(body));
              res.end(body);
            });
            upRes.on("error", () => fail(502, "Upstream error"));
            return;
          }

          for (const h of ["content-type", "content-length", "content-range", "accept-ranges", "etag", "last-modified"]) {
            if (upRes.headers[h]) res.setHeader(h, upRes.headers[h]);
          }
          if (kind === "image") res.setHeader("Cache-Control", "public, max-age=86400");
          res.status(code);
          upRes.pipe(res);
          upRes.on("error", () => { finished = true; res.end(); });
          res.on("finish", () => { finished = true; });
        }
      );

      current.on("timeout", () => current.destroy(new Error("Upstream timeout")));
      current.on("error", (err) => {
        const why = err.code || (err.errors && err.errors.map((e) => `${e.code} ${e.address}:${e.port}`).join(", ")) || err.message || "desconocido";
        console.error("[proxy] fallo:", why, parsed.host);
        fail(502, "No se pudo conectar con el servidor: " + why);
      });
      current.end();
    };

    go(target, 0);
  };
}

for (const kind of ["playlist", "stream", "image"]) {
  app.get(`/proxy/${kind}`, makeHandler(kind));
  app.head(`/proxy/${kind}`, makeHandler(kind));
}

if (existsSync(DIST)) {
  app.use(express.static(DIST));
  app.get("*", (_req, res) => res.sendFile(path.join(DIST, "index.html")));
}

app.listen(PORT, () => { console.log(`StreamBox proxy escuchando en http://localhost:${PORT}`); });
'@

Write-Host ""
Write-Host "Listo. Reinicia: Ctrl+C y luego  npm start" -ForegroundColor Green
Write-Host ""
Write-Host "Que cambia:" -ForegroundColor Cyan
Write-Host "  * URLs del proxy SIEMPRE absolutas -> arregla el fetch en WorkerGlobalScope."
Write-Host "  * mpegts.js con enableWorker:false + config live (sin lazyLoad/stash)."
Write-Host "  * Cadena de fuentes .m3u8 -> .ts -> sin extension, con watchdog y recuperacion."
Write-Host "  * Grid virtualizado real (100k entradas sin colgar el navegador)."
Write-Host "  * Continuar viendo con reanudacion automatica y borrado por item."
Write-Host "  * Navegacion por flechas / D-pad y barra inferior en movil."
Write-Host "  * Zapping: Shift+flechas, RePag/AvPag y teclas 0-9."
Write-Host "  * Proxy Node: sigue redirects internos, detecta HTML de error, rewrite HLS robusto."
Write-Host "  * Fondo mesh + grano, scrollbars con identidad, animaciones suaves."
Write-Host ""
Write-Host "Subir a Git:  git add . ; git commit -m 'StreamBox fase 4' ; git push"