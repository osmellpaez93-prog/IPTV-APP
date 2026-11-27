// ffmpeg disponible en el servidor (solo se cachea el resultado positivo)
let ffmpegOk = false;
async function hasFfmpeg(): Promise<boolean> {
  if (ffmpegOk) return true;
  try {
    const r = await fetch("/proxy/ffmpeg");
    const j = await r.json();
    ffmpegOk = !!j.available;
  } catch { ffmpegOk = false; }
  return ffmpegOk;
}

/**
 * Motor de reproduccion.
 *  - hls.js -> .m3u8      - mpegts.js -> MPEG-TS / FLV      - <video> nativo -> mp4 / webm / mov
 *  - Cadena de fuentes: prueba .m3u8 y .ts del mismo canal antes de rendirse.
 *  - Ultima fuente en vivo: TRANSCODIFICADA con ffmpeg (video copiado, audio -> AAC). Se salta
 *    directamente a ella cuando el navegador no puede decodificar el audio (AC-3 / E-AC-3).
 *  - URLs absolutas, reintentos, watchdog, autoplay bloqueado, progreso y reanudacion (VOD).
 *  - Si todo falla, el error lista el motivo de cada fuente.
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
interface Source { url: string; tx?: "mp4" | "ts" }

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
  loading: true, error: null, isPlaying: false, blocked: false, stalled: false,
  currentTime: 0, duration: 0, buffered: 0, volume: 1, muted: false, playbackRate: 1,
  audioTracks: [], subtitleTracks: [], activeAudio: -1, activeSubtitle: -1,
  extSubs: [], activeExtSub: null, subOffset: 0, engine: null, attempt: 0, attempts: 0,
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

// Formato preferido para TV en vivo: el que funciono la ultima vez en ese servidor.
// Sin dato previo, MPEG-TS primero (casi todos los paneles Xtream lo sirven y HLS suele
// tardar o no existir, lo que anade segundos de espera antes del siguiente intento).
const PREF_PREFIX = "streambox-fmt:";
function hostOf(u: string): string {
  try { return new URL(u).host; } catch { return ""; }
}
function readPref(host: string): EngineKind | null {
  try {
    const v = localStorage.getItem(PREF_PREFIX + host);
    return v === "ts" || v === "hls" ? v : null;
  } catch { return null; }
}
function writePref(host: string, kind: EngineKind) {
  try { if (host && (kind === "ts" || kind === "hls")) localStorage.setItem(PREF_PREFIX + host, kind); } catch {}
}
function preferTs(urls: string[], ch: Channel): string[] {
  if (ch.category !== "live") return urls;
  const pref = readPref(hostOf(ch.url)) ?? "ts";
  const rank = (u: string) => {
    const k = detectKind(u);
    return k === pref ? 0 : k === "ts" || k === "hls" ? 1 : 2;
  };
  return [...urls].sort((a, b) => rank(a) - rank(b));
}

function buildCandidates(ch: Channel): Source[] {
  const urls = [ch.url, ...(ch.altUrls ?? [])].filter(Boolean);
  if (ch.category === "live") {
    const m = ch.url.match(/^(https?:\/\/[^/]+)\/(?:live\/)?([^/]+)\/([^/]+)\/(\d+)(?:\.(?:ts|m3u8))?(?:\?.*)?$/i);
    if (m) {
      const base = `${m[1]}/live/${m[2]}/${m[3]}/${m[4]}`;
      urls.push(`${base}.m3u8`, `${base}.ts`, base);
    }
  }
  const direct = preferTs(Array.from(new Set(urls)), ch);
  const list: Source[] = direct.map((url) => ({ url }));
  if (ch.category === "live" && direct.length) {
    const tsUrl = direct.find((u) => detectKind(u) === "ts") ?? direct[0];
    list.push({ url: tsUrl, tx: "mp4" }, { url: tsUrl, tx: "ts" });
  }
  return list;
}

export function usePlayer(channel: Channel | null) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const hlsRef = useRef<Hls | null>(null);
  const tsRef = useRef<MpegtsPlayer | null>(null);
  const extTracksRef = useRef<{ id: string; el: HTMLTrackElement; url: string; offset: number }[]>([]);
  const activeExtRef = useRef<string | null>(null);
  const channelRef = useRef<Channel | null>(channel);
  useEffect(() => { channelRef.current = channel; });

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
    const failures: string[] = [];
    let seq = 0;
    let failedSeq = -1;
    let curBail: ((msg: string, toTx?: boolean) => void) | null = null;

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
      setState((s) => ({ ...s, error: failures.length > 1 ? failures.join("\n") : msg, loading: false, stalled: false }));
    };

    // toTx: salta directamente a la fuente transcodificada (el navegador no soporta el audio/video)
    const next = (msg: string, toTx = false) => {
      if (!alive) return;
      clearWatchdog(); clearStall();
      const cur = candidates[idx];
      failures.push(`${idx + 1}. ${cur.tx ? "transcodificado-" + cur.tx : detectKind(cur.url)}: ${msg}`);
      let n = idx + 1;
      if (toTx) {
        const t = candidates.findIndex((c, i) => i > idx && c.tx);
        if (t >= 0) n = t;
      }
      if (n < candidates.length) { idx = n; void start(); }
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
      if (!isLive) return;
      clearStall();
      stallTimer = window.setTimeout(() => {
        if (!alive) return;
        setState((s) => ({ ...s, stalled: true }));
        if (!softRecover()) curBail?.("La fuente dejo de enviar datos");
      }, 9000);
    };
    const onMeta = () => applyResume();

    video.addEventListener("playing", onPlaying);
    video.addEventListener("waiting", onWaiting);
    video.addEventListener("loadedmetadata", onMeta);
    const onVideoError = () => {
      if (!video.getAttribute("src") && !hlsRef.current && !tsRef.current) return;
      const e = video.error;
      curBail?.(`Video: ${e ? "codigo " + e.code + (e.message ? " - " + e.message : "") : "error"}`);
    };
    video.addEventListener("error", onVideoError);

    const start = async () => {
      const my = ++seq;
      // Cada intento solo puede fallar UNA vez y los avisos tardios de un intento anterior se ignoran
      const bail = (msg: string, toTx = false) => {
        if (my !== seq || failedSeq === my) return;
        failedSeq = my;
        window.setTimeout(() => { if (my === seq) next(msg, toTx); }, 0);
      };
      curBail = bail;
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

      const src = candidates[idx];
      const kind: EngineKind = src.tx === "mp4" ? "native" : src.tx === "ts" ? "ts" : detectKind(src.url);
      if (src.tx && !(await hasFfmpeg())) {
        return bail("ffmpeg no esta instalado en el PC (winget install Gyan.FFmpeg; reinicia la terminal y el servidor)");
      }
      if (!alive || my !== seq) return;
      let url = "";
      try { url = await proxify(src.url, src.tx ? "transcode" : "stream"); if (src.tx) url += (url.includes("?") ? "&" : "?") + "fmt=" + src.tx; }
      catch (e: any) { return bail(e?.message || "No se pudo preparar la URL del proxy"); }
      if (!alive) return;

      setState((s) => ({ ...s, engine: kind }));
      // Recuerda el formato que funciona en este servidor (solo si ESTE intento llega a reproducir)
      if (isLive && !src.tx && (kind === "ts" || kind === "hls")) {
        video.addEventListener("playing", () => { if (my === seq) writePref(hostOf(src.url), kind); }, { once: true });
      }
      clearWatchdog();
      watchdog = window.setTimeout(
        () => bail(isLive ? "El canal no responde" : "La fuente no responde"),
        isLive ? (src.tx ? 20000 : 10000) : 60000
      );

      const tryPlay = () => {
        video.play().catch((err: any) => {
          if (!alive) return;
          if (err && (err.name === "NotAllowedError" || err.name === "AbortError")) {
            if (err.name === "NotAllowedError") clearWatchdog();
            setState((s) => ({ ...s, blocked: err.name === "NotAllowedError", loading: false }));
          }
        });
      };

      try {
        if (kind === "hls") {
          if (Hls.isSupported()) {
            const hls = new Hls({
              enableWorker: true, lowLatencyMode: false,
              backBufferLength: isLive ? 30 : 90, maxBufferLength: isLive ? 20 : 40,
              manifestLoadingTimeOut: 12000, manifestLoadingMaxRetry: 1,
              levelLoadingTimeOut: 12000, fragLoadingTimeOut: 22000,
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
              const codec = /bufferAddCodecError|bufferIncompatibleCodecsError/.test(String(data.details));
              if (codec && !src.tx) { bail(`HLS: ${data.details} (codec no compatible)`, true); return; }
              if (data.type === Hls.ErrorTypes.NETWORK_ERROR && net < 2) { net++; hls.startLoad(); }
              else if (data.type === Hls.ErrorTypes.MEDIA_ERROR && med < 2) {
                med++;
                if (med === 1) hls.recoverMediaError();
                else { try { hls.swapAudioCodec(); } catch {} hls.recoverMediaError(); }
              } else bail(`HLS: ${data.details}${data.response?.code ? ` (HTTP ${data.response.code})` : ""}`);
            });
            hls.loadSource(url);
            hls.attachMedia(video);
          } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
            video.src = url;
            tryPlay();
          } else { bail("HLS no soportado en este navegador"); }
          return;
        }

        if (kind === "ts" || kind === "flv") {
          if (!mpegts.isSupported()) return bail("Este navegador no soporta MPEG-TS (usa Chrome o Edge)", true);
          const player = mpegts.createPlayer(
            { type: kind === "flv" ? "flv" : "mpegts", url, isLive, cors: true },
            {
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
            const text = String(info?.msg || "");
            if (src.tx && info?.code === 501) {
              return bail("ffmpeg no esta instalado en el PC (winget install Gyan.FFmpeg; reinicia la terminal y el servidor)");
            }
            const codec = !src.tx && /addSourceBuffer|unsupported|ac-?3/i.test(text);
            const http = info?.code ? ` (HTTP ${info.code})` : "";
            bail(`TS/FLV: ${detail}${http}${text ? ` - ${text}` : ""}`, codec);
          });
          player.load();
          tryPlay();
          return;
        }

        video.src = url;
        tryPlay();
      } catch (e: any) { bail(e?.message || "Error al cargar el stream"); }
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
      void db.history.put({ id: ch.id, position: p, duration: d, updatedAt: Date.now(), item: ch }).catch(() => {});
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
      video.removeEventListener("error", onVideoError);
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
      setState((s) => ({ ...s, currentTime: video.currentTime, duration: isFinite(video.duration) ? video.duration : 0, buffered: buf }));
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
      if (v && isFinite(v.duration) && v.duration > 0) v.currentTime = Math.max(0, Math.min(v.duration, v.currentTime + d));
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
      setState((s) => ({ ...s, extSubs: [...s.extSubs, { id, label }], activeExtSub: id, subOffset: 0, activeSubtitle: -1 }));
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
        c.startTime = st;
        c.endTime = Math.max(st + 0.05, c.endTime + delta);
      }
      cur.offset = Math.round((cur.offset + delta) * 10) / 10;
      setState((s) => ({ ...s, subOffset: cur.offset }));
    },
    retry: () => setReloadKey((k) => k + 1),
  };

  return { videoRef, state, actions };
}
