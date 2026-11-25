/**
 * Logica del reproductor:
 *  - hls.js para .m3u8
 *  - mpegts.js para MPEG-TS (.ts o URLs Xtream sin extension) y FLV
 *  - <video> nativo para mp4 y similares
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
};

function detectKind(raw: string): Kind {
  const path = raw.split("?")[0].toLowerCase();
  if (path.endsWith(".m3u8") || /[?&]type=m3u8/i.test(raw)) return "hls";
  if (path.endsWith(".flv")) return "flv";
  // .ts, o formato Xtream sin extension: /user/pass/123 o /live/user/pass/123
  let pathname = path;
  try {
    pathname = new URL(raw).pathname.toLowerCase();
  } catch {}
  if (pathname.endsWith(".ts") || /^\/(live\/)?[^/]+\/[^/]+\/\d+$/.test(pathname)) return "ts";
  return "native";
}

export function usePlayer(channel: Channel | null) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const hlsRef = useRef<Hls | null>(null);
  const tsRef = useRef<MpegtsPlayer | null>(null);
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

  useEffect(() => () => destroyEngines(), [destroyEngines]);

  // Cargar stream al cambiar de canal (o al reintentar)
  useEffect(() => {
    const video = videoRef.current;
    if (!video || !channel) return;

    let cancelled = false;
    destroyEngines();
    video.removeAttribute("src");
    video.load();
    setState((s) => ({ ...s, loading: true, error: null, audioTracks: [], subtitleTracks: [], currentTime: 0, duration: 0 }));

    const fail = (msg: string) => setState((s) => ({ ...s, error: msg, loading: false }));

    (async () => {
      try {
        const kind = detectKind(channel.url);
        const url = await proxify(channel.url, "stream");
        if (cancelled) return;

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
              if (data.type === Hls.ErrorTypes.NETWORK_ERROR && retries < 3) {
                retries++;
                hls.startLoad();
              } else if (data.type === Hls.ErrorTypes.MEDIA_ERROR && retries < 3) {
                retries++;
                hls.recoverMediaError();
              } else {
                fail(`Error HLS: ${data.details}`);
              }
            });
          } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
            video.src = url;
            video.play().catch(() => {});
          } else {
            fail("HLS no soportado en este navegador");
          }
        } else if (kind === "ts" || kind === "flv") {
          if (mpegts.isSupported()) {
            const player = mpegts.createPlayer(
              { type: kind === "flv" ? "flv" : "mpegts", url, isLive: true },
              { enableWorker: true, liveBufferLatencyChasing: true }
            );
            tsRef.current = player;
            player.attachMediaElement(video);
            player.load();
            player.on(mpegts.Events.ERROR, (_type: string, detail: string) => fail(`Error TS/FLV: ${detail}`));
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
        fail(e?.message || "Error al cargar el stream");
      }
    })();

    return () => {
      cancelled = true;
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
      setState((s) => ({ ...s, error: "Error de reproducción", loading: false }));
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
    retry: () => setReloadKey((k) => k + 1),
  };

  return { videoRef, state, actions };
}
