/**
* Logica del reproductor:
*  - hls.js para .m3u8, mpegts.js para MPEG-TS/FLV, <video> nativo para mp4/mkv
*  - En TV en vivo prueba varios formatos del mismo canal (.m3u8 y .ts) antes de rendirse
*  - Configuracion optimizada para evitar stuttering en streams Xtream
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
  try { pathname = new URL(raw).pathname.toLowerCase(); } catch {}
  if (pathname.endsWith(".ts") || /^\/(live\/)?[^/]+\/[^/]+\/\d+$/.test(pathname)) return "ts";
  return "native";
}

function buildCandidates(channel: Channel): string[] {
  const list = [channel.url, ...(channel.altUrls ?? [])];
  if (channel.category === "live") {
    const m = channel.url.match(/^(https?:\/\/[^/]+)\/(?:live\/)?([^/]+)\/([^/]+)\/(\d+)(?:\.(?:ts|m3u8))?(?:\?.*)?$/i);
    if (m) {
      const base = `${m[1]}/live/${m[2]}/${m[3]}/${m[4]}`;
      list.push(`${base}.m3u8`, `${base}.ts`);
    }
  }
  return Array.from(new Set(list.filter(Boolean)));
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
    hlsRef.current?.destroy();
    hlsRef.current = null;
    if (tsRef.current) {
      try {
        tsRef.current.pause();
        tsRef.current.unload();
        tsRef.current.detachMediaElement();
        tsRef.current.destroy();
      } catch {}
      tsRef.current = null;
    }
  }, []);

  const clearExtSubs = useCallback(() => {
    for (const t of extTracksRef.current) {
      try { t.el.remove(); URL.revokeObjectURL(t.url); } catch {}
    }
    extTracksRef.current = [];
    setState((s) => ({ ...s, extSubs: [], activeExtSub: null, subOffset: 0 }));
  }, []);

  useEffect(() => () => { destroyEngines(); clearExtSubs(); }, [destroyEngines, clearExtSubs]);

  useEffect(() => {
    const video = videoRef.current;
    if (!video || !channel) return;

    let cancelled = false;
    clearExtSubs();
    let idx = 0;
    let timer: number | undefined;
    const candidates = buildCandidates(channel);

    const clearTimer = () => { if (timer) window.clearTimeout(timer); timer = undefined; };
    const failFinal = (msg: string) => {
      clearTimer();
      const tried = candidates.length > 1 ? ` (se probaron ${candidates.length} formatos)` : "";
      setState((s) => ({ ...s, error: msg + tried, loading: false }));
    };
    const next = (msg: string) => {
      if (cancelled) return;
      clearTimer();
      if (idx + 1 < candidates.length) { idx++; start(); }
      else failFinal(msg);
    };
    fallbackRef.current = next;

    const onPlaying = () => clearTimer();
    video.addEventListener("playing", onPlaying);

    const start = async () => {
      destroyEngines();
      video.removeAttribute("src");
      video.load();
      setState((s) => ({ ...s, loading: true, error: null, audioTracks: [], subtitleTracks: [], currentTime: 0, duration: 0 }));

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
            const hls = new Hls({
              enableWorker: true,
              lowLatencyMode: false,
              backBufferLength: 30,
              maxBufferLength: 20,
              manifestLoadingTimeOut: 12000,
              levelLoadingTimeOut: 12000,
              fragLoadingTimeOut: 22000,
            });
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
              if (data.type === Hls.ErrorTypes.NETWORK_ERROR && retries < 2) { retries++; hls.startLoad(); }
              else if (data.type === Hls.ErrorTypes.MEDIA_ERROR && retries < 2) { retries++; hls.recoverMediaError(); }
              else next(`Error HLS: ${data.details}`);
            });
          } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
            video.src = url;
            video.play().catch(() => {});
          } else next("HLS no soportado en este navegador");
        } else if (kind === "ts" || kind === "flv") {
          if (mpegts.isSupported()) {
            const player = mpegts.createPlayer(
              { type: kind === "flv" ? "flv" : "mpegts", url, isLive: true },
              {
                enableWorker: true,
                // CLAVE: desactivar liveBufferLatencyChasing para evitar stuttering
                liveBufferLatencyChasing: false,
                liveBufferLatencyMaxLatency: 10,
                liveBufferLatencyMinRemain: 3,
                // Buffer mas grande para absorber discontinuidades
                stashInitialSize: 512,
                autoCleanupSourceBuffer: true,
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
      if (fallbackRef.current) fallbackRef.current("Error de reproduccion");
      else setState((s) => ({ ...s, error: "Error de reproduccion", loading: false }));
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
    playPause: () => { const v = videoRef.current; if (!v) return; if (v.paused) v.play().catch(() => {}); else v.pause(); },
    seek: (t: number) => { const v = videoRef.current; if (v && isFinite(v.duration) && v.duration > 0) v.currentTime = Math.max(0, Math.min(v.duration, t)); },
    setVolume: (vol: number) => { const v = videoRef.current; if (v) v.volume = Math.max(0, Math.min(1, vol)); },
    setMuted: (m: boolean) => { const v = videoRef.current; if (v) v.muted = m; },
    setPlaybackRate: (r: number) => { const v = videoRef.current; if (v) v.playbackRate = r; setState((s) => ({ ...s, playbackRate: r })); },
    setAudioTrack: (id: number) => { if (hlsRef.current) { hlsRef.current.audioTrack = id; setState((s) => ({ ...s, activeAudio: id })); } },
    setSubtitleTrack: (id: number) => { if (hlsRef.current) { hlsRef.current.subtitleTrack = id; setState((s) => ({ ...s, activeSubtitle: id })); } },
    requestPiP: async () => { const v = videoRef.current; if (!v) return; try { if (document.pictureInPictureElement) await document.exitPictureInPicture(); else if (v.requestPictureInPicture) await v.requestPictureInPicture(); } catch {} },
    addSubtitle: (label: string, vtt: string) => {
      const v = videoRef.current; if (!v) return;
      for (const t of extTracksRef.current) t.el.track.mode = "disabled";
      Array.from(v.textTracks).forEach((t) => { if (t.mode === "showing") t.mode = "disabled"; });
      const url = URL.createObjectURL(new Blob([vtt], { type: "text/vtt" }));
      const el = document.createElement("track");
      el.kind = "subtitles"; el.label = label; el.src = url; el.default = true;
      v.appendChild(el); el.track.mode = "showing";
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
      const cues = cur.el.track.cues; if (!cues) return;
      for (const c of Array.from(cues)) { c.startTime = Math.max(0, c.startTime + delta); c.endTime = Math.max(0.05, c.endTime + delta); }
      cur.offset = Math.round((cur.offset + delta) * 10) / 10;
      setState((s) => ({ ...s, subOffset: cur.offset }));
    },
    retry: () => setReloadKey((k) => k + 1),
  };

  return { videoRef, state, actions };
}
