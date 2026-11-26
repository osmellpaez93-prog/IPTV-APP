<#
StreamBox - fix-ac3-mse.ps1
Arregla canales con audio AC-3/DTS (Movistar, etc.) que rompen Chrome:
  1. Guard global de MediaSource.addSourceBuffer -> aborta limpiamente antes de corromper el MediaSource
  2. Deteccion dinamica con MediaSource.isTypeSupported (Firefox/Edge con Dolby siguen funcionando)
  3. mpegts.js sin worker (evita el bug del Blob-URL y el bucle de appendBuffer)
  4. URLs del proxy SIEMPRE absolutas (necesario en produccion HTTPS)
  5. Mensaje de error claro cuando el canal es AC-3/DTS puro
#>
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "package.json"))) {
  Write-Host "ERROR: ejecuta esto en la raiz del proyecto." -ForegroundColor Red
  return
}
Write-Host "Parcheando AC-3/MSE..." -ForegroundColor Cyan

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

# ==================================================== src/services/mseGuard.ts (NUEVO)
Write-ProjectFile 'src/services/mseGuard.ts' @'
/**
 * Guard de MediaSource.
 *
 * Chrome/Edge (sin Dolby Access) NO soportan AC-3, E-AC-3, DTS ni TrueHD en MSE.
 * Cuando mpegts.js intenta addSourceBuffer('audio/mp4;codecs=ac-3') falla, pero
 * su demuxer sigue enviando datos -> bucle "appendBuffer: HTMLMediaElement.error
 * attribute is not null" y "Cannot read properties of null (reading 'emit')".
 *
 * Este guard intercepta addSourceBuffer ANTES de que eso ocurra: si el navegador
 * no soporta el codec de audio, lanza una excepcion limpia que mpegts.js captura
 * como ERROR, lo que permite pasar al siguiente candidato sin corromper el video.
 *
 * La deteccion es DINAMICA (MediaSource.isTypeSupported): en Firefox o Edge con
 * Dolby Access los codecs si se soportan y el guard no interfiere.
 */
const supported = new Map<string, boolean>();

export function isMSESupported(mime: string): boolean {
  if (typeof MediaSource === "undefined" || !MediaSource.isTypeSupported) return true;
  let v = supported.get(mime);
  if (v === undefined) {
    v = MediaSource.isTypeSupported(mime);
    supported.set(mime, v);
  }
  return v;
}

let installed = false;
export function installMSEGuard() {
  if (installed || typeof MediaSource === "undefined") return;
  installed = true;
  const orig = MediaSource.prototype.addSourceBuffer;
  MediaSource.prototype.addSourceBuffer = function (this: MediaSource, type: string) {
    // Solo bloqueamos pistas de AUDIO con codecs que el navegador no puede decodificar en MSE.
    if (/audio\//i.test(type) && !isMSESupported(type)) {
      throw new DOMException(`Audio codec no soportado por el navegador: ${type}`, "NotSupportedError");
    }
    return orig.call(this, type);
  };
}
'@

# ================================================================== src/main.tsx
Write-ProjectFile 'src/main.tsx' @'
import React from "react";
import ReactDOM from "react-dom/client";
import "@fontsource/inter/400.css";
import "@fontsource/inter/600.css";
import "@fontsource/inter/700.css";
import "./index.css";
import { App } from "./App";
import { installMSEGuard } from "./services/mseGuard";

// Debe ejecutarse antes de crear cualquier MediaSource (reproductores, etc.)
installMSEGuard();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
'@

# ============================================================ src/services/proxy.ts
Write-ProjectFile 'src/services/proxy.ts' @'
/**
 * URLs del proxy. SIEMPRE absolutas: los Workers (hls.js/mpegts.js) y las
 * paginas HTTPS no resuelven bien rutas relativas segun contexto.
 */
import { getSettings } from "../db";

export type ProxyKind = "playlist" | "stream" | "image";

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

export async function proxify(url: string, kind: ProxyKind = "stream"): Promise<string> {
  if (!url) return url;
  const s = await getSettings();
  baseSync = (s.proxyUrl || "/proxy").replace(/\/+$/, "") || "/proxy";
  if (url.startsWith(baseSync + "/")) return toAbsolute(url);
  return toAbsolute(`${baseSync}/${kind}?url=${encodeURIComponent(url)}`);
}

/** Logos http:// no cargan en HTTPS (mixed content): los pasamos por el proxy. */
export function imgUrl(url?: string): string | undefined {
  if (!url) return undefined;
  if (/^http:\/\//i.test(url)) {
    return toAbsolute(`${baseSync}/image?url=${encodeURIComponent(url)}`);
  }
  return url;
}
'@

# ============================================================= src/hooks/usePlayer.ts
Write-ProjectFile 'src/hooks/usePlayer.ts' @'
/**
 * Logica del reproductor:
 *  - hls.js para .m3u8, mpegts.js para MPEG-TS/FLV, <video> nativo para mp4/mkv
 *  - En TV en vivo prueba varios formatos del mismo canal (.m3u8 y .ts) antes de rendirse
 *  - mpegts.js SIN worker: evita el bug del Blob-URL y el bucle de appendBuffer
 *    cuando el codec de audio no esta soportado (ver services/mseGuard.ts)
 *  - Detecta AC-3/DTS y da un mensaje claro en lugar de errores cruptos
 */
import { useCallback, useEffect, useRef, useState } from "react";
import Hls from "hls.js";
import mpegts from "mpegts.js";
import type { Channel } from "../types";
import { proxify } from "../services/proxy";

type MpegtsPlayer = ReturnType<typeof mpegts.createPlayer>;
type Kind = "hls" | "ts" | "flv" | "native";

export interface PlayerState {
  loading: boolean;
  error: string | null;
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  volume: number;
  muted: boolean;
  playbackRate: number;
  audioTracks: { id: number; label: string }[];
  subtitleTracks: { id: number; label: string }[];
  activeAudio: number;
  activeSubtitle: number;
  extSubs: { id: string; label: string }[];
  activeExtSub: string | null;
  subOffset: number;
}

const INITIAL: PlayerState = {
  loading: true,
  error: null,
  isPlaying: false,
  currentTime: 0,
  duration: 0,
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
};

function detectKind(raw: string): Kind {
  const path = raw.split("?")[0].toLowerCase();
  if (path.endsWith(".m3u8") || /[?&]type=m3u8/i.test(raw)) return "hls";
  if (path.endsWith(".flv")) return "flv";
  let pathname = path;
  try {
    pathname = new URL(raw).pathname.toLowerCase();
  } catch {}
  if (pathname.endsWith(".ts") || /^\/(live\/)?[^/]+\/[^/]+\/\d+$/.test(pathname)) return "ts";
  return "native";
}

// .m3u8 PRIMERO (mejor compatibilidad), luego .ts y la URL original.
function buildCandidates(channel: Channel): string[] {
  const list: string[] = [];
  if (channel.category === "live") {
    const m = channel.url.match(
      /^(https?:\/\/[^/]+)\/(?:live\/)?([^/]+)\/([^/]+)\/(\d+)(?:\.(?:ts|m3u8))?(?:\?.*)?$/i
    );
    if (m) {
      const base = `${m[1]}/live/${m[2]}/${m[3]}/${m[4]}`;
      list.push(`${base}.m3u8`, `${base}.ts`);
    }
  }
  list.push(channel.url, ...(channel.altUrls ?? []));
  return Array.from(new Set(list.filter(Boolean)));
}

// El guard lanza "Audio codec no soportado por el navegador: audio/mp4;codecs=ac-3"
// Detectamos aqui esos codecs para dar un mensaje entendible al usuario.
const CODEC_RE = /ac-?3|ec-?3|eac-?3|dtsc|dtse|dtsl|mlpa|ac-?4/i;
function friendlyCodecError(msg: string): string | null {
  const m = msg.match(CODEC_RE);
  if (!m) return null;
  const codec = m[0].toUpperCase().replace("EAC", "E-AC").replace("AC3", "AC-3").replace("AC4", "AC-4");
  return `Este canal usa audio Dolby/DTS (${codec}) que tu navegador no puede decodificar. Prueba en Firefox, o usa un navegador con soporte Dolby (Edge + Dolby Access).`;
}

export function usePlayer(channel: Channel | null) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const hlsRef = useRef<Hls | null>(null);
  const tsRef = useRef<MpegtsPlayer | null>(null);
  const fallbackRef = useRef<((msg: string) => void) | null>(null);
  const extTracksRef = useRef<{ id: string; el: HTMLTrackElement; url: string; offset: number }[]>([]);
  const [reloadKey, setReloadKey] = useState(0);
  const [state, setState] = useState<PlayerState>(INITIAL);

  const destroyEngines = useCallback(() => {
    if (hlsRef.current) {
      try { hlsRef.current.destroy(); } catch {}
      hlsRef.current = null;
    }
    if (tsRef.current) {
      try {
        tsRef.current.pause();
        tsRef.current.unload();
        tsRef.current.detachMediaElement();
        tsRef.current.destroy();
      } catch {}
      tsRef.current = null;
    }
    // Reset completo del <video>: si el MediaSource quedo roto por un codec
    // no soportado, esto limpia el estado para el siguiente intento.
    const video = videoRef.current;
    if (video) {
      try {
        video.removeAttribute("src");
        video.load();
      } catch {}
    }
  }, []);

  const clearExtSubs = useCallback(() => {
    for (const t of extTracksRef.current) {
      try {
        t.el.remove();
        URL.revokeObjectURL(t.url);
      } catch {}
    }
    extTracksRef.current = [];
    setState((s) => ({ ...s, extSubs: [], activeExtSub: null, subOffset: 0 }));
  }, []);

  useEffect(
    () => () => {
      destroyEngines();
      clearExtSubs();
    },
    [destroyEngines, clearExtSubs]
  );

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !channel) return;

    let cancelled = false;
    clearExtSubs();
    let idx = 0;
    let timer: number | undefined;
    const candidates = buildCandidates(channel);
    const errors: string[] = [];

    const clearTimer = () => {
      if (timer) window.clearTimeout(timer);
      timer = undefined;
    };
    const failFinal = (msg: string) => {
      clearTimer();
      // Si algun candidato fallo por codec de audio, ese es el error real.
      const codecMsg = [...errors, msg].map(friendlyCodecError).find(Boolean);
      const tried = candidates.length > 1 ? ` (se probaron ${candidates.length} formatos)` : "";
      setState((s) => ({ ...s, error: codecMsg || msg + tried, loading: false }));
    };
    const next = (msg: string) => {
      if (cancelled) return;
      clearTimer();
      errors.push(msg);
      destroyEngines();
      if (idx + 1 < candidates.length) {
        idx++;
        start();
      } else {
        failFinal(msg);
      }
    };
    fallbackRef.current = next;

    const onPlaying = () => clearTimer();
    video.addEventListener("playing", onPlaying);

    const start = async () => {
      destroyEngines();
      setState((s) => ({
        ...s,
        loading: true,
        error: null,
        audioTracks: [],
        subtitleTracks: [],
        currentTime: 0,
        duration: 0,
      }));

      try {
        const raw = candidates[idx];
        const kind = detectKind(raw);
        const url = await proxify(raw, "stream");
        if (cancelled) return;

        if (channel.category === "live") {
          timer = window.setTimeout(() => next("El canal no responde"), 15000);
        }

        if (kind === "hls") {
          if (Hls.isSupported()) {
            const hls = new Hls({ enableWorker: true });
            hlsRef.current = hls;
            let retries = 0;
            hls.loadSource(url);
            hls.attachMedia(video);
            hls.on(Hls.Events.MANIFEST_PARSED, () => {
              if (cancelled) return;
              const audio = hls.audioTracks.map((t, i) => ({ id: i, label: t.name || t.lang || `Audio ${i + 1}` }));
              const subs = hls.subtitleTracks.map((t, i) => ({ id: i, label: t.name || t.lang || `Sub ${i + 1}` }));
              setState((s) => ({ ...s, audioTracks: audio, subtitleTracks: subs, activeAudio: 0, activeSubtitle: -1 }));
              video.play().catch(() => {});
            });
            hls.on(Hls.Events.ERROR, (_e, data) => {
              if (!data.fatal) return;
              if (data.type === Hls.ErrorTypes.NETWORK_ERROR && retries < 2) {
                retries++;
                hls.startLoad();
              } else if (data.type === Hls.ErrorTypes.MEDIA_ERROR && retries < 2) {
                retries++;
                hls.recoverMediaError();
              } else {
                next(`Error HLS: ${data.details}`);
              }
            });
          } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
            video.src = url;
            video.play().catch(() => {});
          } else {
            next("HLS no soportado en este navegador");
          }
        } else if (kind === "ts" || kind === "flv") {
          if (mpegts.isSupported()) {
            const player = mpegts.createPlayer(
              { type: kind === "flv" ? "flv" : "mpegts", url, isLive: true },
              {
                // Worker OFF: el worker hace fetch desde un Blob-URL (origin blob:)
                // y ademas, si el codec de audio falla, entra en bucle de appendBuffer.
                // En hilo principal el guard de MSE aborta limpio y podemos fallback.
                enableWorker: false,
                liveBufferLatencyChasing: true,
                stashInitialSize: 384,
              }
            );
            tsRef.current = player;
            player.attachMediaElement(video);
            player.load();
            player.on(mpegts.Events.ERROR, (_type: string, detail: string, info: any) =>
              next(`Error TS/FLV: ${detail}${info?.code ? ` (HTTP ${info.code})` : ""}${info?.msg ? ` - ${info.msg}` : ""}`)
            );
            video.play().catch(() => {});
          } else {
            video.src = url;
            video.play().catch(() => {});
          }
        } else {
          video.src = url;
          video.play().catch(() => {});
        }
      } catch (e: any) {
        next(e?.message || "Error al cargar el stream");
      }
    };

    start();

    return () => {
      cancelled = true;
      clearTimer();
      video.removeEventListener("playing", onPlaying);
      fallbackRef.current = null;
    };
  }, [channel?.id, reloadKey]);

  // Eventos del <video>
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    const onPlay = () => setState((s) => ({ ...s, isPlaying: true, loading: false }));
    const onPause = () => setState((s) => ({ ...s, isPlaying: false }));
    const onWaiting = () => setState((s) => ({ ...s, loading: true }));
    const onCanPlay = () => setState((s) => ({ ...s, loading: false }));
    const onTime = () =>
      setState((s) => ({ ...s, currentTime: video.currentTime, duration: isFinite(video.duration) ? video.duration : 0 }));
    const onVolume = () => setState((s) => ({ ...s, volume: video.volume, muted: video.muted }));
    const onError = () => {
      if (!video.getAttribute("src") && !hlsRef.current && !tsRef.current) return;
      if (fallbackRef.current) fallbackRef.current("Error de reproducción");
      else setState((s) => ({ ...s, error: "Error de reproducción", loading: false }));
    };
    video.addEventListener("play", onPlay);
    video.addEventListener("pause", onPause);
    video.addEventListener("waiting", onWaiting);
    video.addEventListener("canplay", onCanPlay);
    video.addEventListener("timeupdate", onTime);
    video.addEventListener("volumechange", onVolume);
    video.addEventListener("error", onError);
    return () => {
      video.removeEventListener("play", onPlay);
      video.removeEventListener("pause", onPause);
      video.removeEventListener("waiting", onWaiting);
      video.removeEventListener("canplay", onCanPlay);
      video.removeEventListener("timeupdate", onTime);
      video.removeEventListener("volumechange", onVolume);
      video.removeEventListener("error", onError);
    };
  }, []);

  const actions = {
    playPause: () => {
      const v = videoRef.current;
      if (!v) return;
      if (v.paused) v.play().catch(() => {});
      else v.pause();
    },
    seek: (t: number) => {
      const v = videoRef.current;
      if (v && isFinite(v.duration) && v.duration > 0) v.currentTime = Math.max(0, Math.min(v.duration, t));
    },
    setVolume: (vol: number) => {
      const v = videoRef.current;
      if (v) v.volume = Math.max(0, Math.min(1, vol));
    },
    setMuted: (m: boolean) => {
      const v = videoRef.current;
      if (v) v.muted = m;
    },
    setPlaybackRate: (r: number) => {
      const v = videoRef.current;
      if (v) v.playbackRate = r;
      setState((s) => ({ ...s, playbackRate: r }));
    },
    setAudioTrack: (id: number) => {
      if (hlsRef.current) {
        hlsRef.current.audioTrack = id;
        setState((s) => ({ ...s, activeAudio: id }));
      }
    },
    setSubtitleTrack: (id: number) => {
      if (hlsRef.current) {
        hlsRef.current.subtitleTrack = id;
        setState((s) => ({ ...s, activeSubtitle: id }));
      }
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
      Array.from(v.textTracks).forEach((t) => {
        if (t.mode === "showing") t.mode = "disabled";
      });
      const url = URL.createObjectURL(new Blob([vtt], { type: "text/vtt" }));
      const el = document.createElement("track");
      el.kind = "subtitles";
      el.label = label;
      el.src = url;
      el.default = true;
      v.appendChild(el);
      el.track.mode = "showing";
      const id = String(Date.now()) + Math.random().toString(36).slice(2, 5);
      extTracksRef.current.push({ id, el, url, offset: 0 });
      setState((s) => ({ ...s, extSubs: [...s.extSubs, { id, label }], activeExtSub: id, subOffset: 0, activeSubtitle: -1 }));
    },
    setExtSubtitle: (id: string | null) => {
      for (const t of extTracksRef.current) t.el.track.mode = t.id === id ? "showing" : "disabled";
      const cur = extTracksRef.current.find((t) => t.id === id);
      setState((s) => ({ ...s, activeExtSub: id, subOffset: cur?.offset ?? 0 }));
    },
    shiftSubtitles: (delta: number) => {
      const cur = extTracksRef.current.find((t) => t.id === state.activeExtSub);
      if (!cur) return;
      const cues = cur.el.track.cues;
      if (!cues) return;
      for (const c of Array.from(cues)) {
        c.startTime = Math.max(0, c.startTime + delta);
        c.endTime = Math.max(0.05, c.endTime + delta);
      }
      cur.offset = Math.round((cur.offset + delta) * 10) / 10;
      setState((s) => ({ ...s, subOffset: cur.offset }));
    },
    retry: () => setReloadKey((k) => k + 1),
  };

  return { videoRef, state, actions };
}
'@

Write-Host ""
Write-Host "Listo. Reinicia: Ctrl+C y luego npm start" -ForegroundColor Green
Write-Host ""
Write-Host "Que cambia:" -ForegroundColor Cyan
Write-Host "  * Guard global de MediaSource: aborta codecs de audio no soportados ANTES"
Write-Host "    de corromper el reproductor (adios al bucle de appendBuffer)."
Write-Host "  * mpegts.js con enableWorker:false (adios al error del Blob-URL)."
Write-Host "  * Mensaje claro: 'Este canal usa audio Dolby/DTS (AC-3)...' con alternativa."
Write-Host "  * URLs del proxy absolutas (necesario para produccion HTTPS)."
Write-Host ""
Write-Host "Importante: los canales AC-3 PUROS seguiran sin ir en Chrome (es limite" -ForegroundColor Yellow
Write-Host "del navegador, no de la app). En Firefox deberian sonar ya. Si Movistar" -ForegroundColor Yellow
Write-Host "ofrece una variante AAC en HLS para esos canales, esa funcionara en Chrome." -ForegroundColor Yellow