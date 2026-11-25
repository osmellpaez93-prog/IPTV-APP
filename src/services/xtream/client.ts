/**
 * Cliente Xtream Codes (player_api.php). Todas las peticiones pasan por el proxy.
 * Live: .m3u8 (HLS) con .ts como alternativa. VOD y series: contenedor original (mp4/mkv).
 */
import type { Channel, Playlist } from "../../types";
import { proxify } from "../proxy";

export interface XtreamCreds {
  server: string;
  username: string;
  password: string;
}

export interface Episode {
  id: string;
  title: string;
  season: number;
  num: number;
  ext: string;
  plot?: string;
  duration?: string;
  image?: string;
}

export interface SeriesInfo {
  plot?: string;
  cover?: string;
  seasons: Record<number, Episode[]>;
}

export function normalizeServer(s: string) {
  let v = s.trim().replace(/\/+$/, "");
  if (!/^https?:\/\//i.test(v)) v = "http://" + v;
  return v;
}

// Detecta credenciales dentro de una URL tipo get.php?username=...&password=...
export function parseXtreamFromUrl(input: string): XtreamCreds | null {
  try {
    const u = new URL(input.trim());
    const username = u.searchParams.get("username");
    const password = u.searchParams.get("password");
    if (!username || !password) return null;
    return { server: `${u.protocol}//${u.host}`, username, password };
  } catch {
    return null;
  }
}

async function api<T>(c: XtreamCreds, action?: string, extra = ""): Promise<T> {
  const url =
    `${normalizeServer(c.server)}/player_api.php?username=${encodeURIComponent(c.username)}` +
    `&password=${encodeURIComponent(c.password)}${action ? `&action=${action}` : ""}${extra}`;
  let res: Response;
  try {
    res = await fetch(await proxify(url, "playlist"));
  } catch {
    throw new Error("No se pudo conectar con el proxy. ¿Está corriendo 'npm start'?");
  }
  if (!res.ok) {
    let detail = "";
    try {
      const j = await res.json();
      if (j?.error) detail = `: ${j.error}`;
    } catch {}
    throw new Error(`El servidor respondió HTTP ${res.status}${detail}`);
  }
  const text = await res.text();
  try {
    return JSON.parse(text) as T;
  } catch {
    throw new Error("Respuesta no válida del servidor (¿servidor o credenciales incorrectos?).");
  }
}

export interface AccountInfo {
  maxConnections: number;
  activeConnections: number;
  expires: Date | null;
}

export async function checkAccount(c: XtreamCreds): Promise<AccountInfo> {
  const r: any = await api(c);
  const ui = r?.user_info;
  if (!ui || Number(ui.auth) !== 1) throw new Error("Usuario o contraseña incorrectos.");
  if (ui.status && String(ui.status).toLowerCase() !== "active") throw new Error(`La cuenta no está activa (${ui.status}).`);
  return {
    maxConnections: Number(ui.max_connections) || 0,
    activeConnections: Number(ui.active_cons) || 0,
    expires: ui.exp_date ? new Date(Number(ui.exp_date) * 1000) : null,
  };
}

async function categoryMap(c: XtreamCreds, action: string) {
  const arr = await api<any[]>(c, action);
  const m = new Map<string, string>();
  for (const x of Array.isArray(arr) ? arr : []) m.set(String(x.category_id), String(x.category_name ?? ""));
  return m;
}

export async function loadXtream(
  pid: string,
  creds: XtreamCreds,
  onProgress: (msg: string) => void
): Promise<{ channels: Channel[]; warnings: string[] }> {
  const base = normalizeServer(creds.server);
  const U = encodeURIComponent(creds.username);
  const P = encodeURIComponent(creds.password);
  const channels: Channel[] = [];
  const warnings: string[] = [];
  const group = (m: Map<string, string>, id: unknown) => m.get(String(id)) || "Sin categoría";

  // --- TV en vivo
  try {
    onProgress("Descargando canales en vivo...");
    const cats = await categoryMap(creds, "get_live_categories");
    const list = await api<any[]>(creds, "get_live_streams");
    for (const s of Array.isArray(list) ? list : []) {
      const id = String(s.stream_id);
      channels.push({
        id: `${pid}:l${id}`,
        playlistId: pid,
        name: String(s.name ?? "Sin nombre"),
        logo: s.stream_icon || undefined,
        group: group(cats, s.category_id),
        tvgId: s.epg_channel_id || undefined,
        url: `${base}/live/${U}/${P}/${id}.m3u8`,
        altUrls: [`${base}/live/${U}/${P}/${id}.ts`],
        category: "live",
        streamType: "live",
        streamId: id,
      });
    }
  } catch (e: any) {
    warnings.push(`TV en vivo: ${e?.message}`);
  }

  // --- Películas
  try {
    onProgress("Descargando películas...");
    const cats = await categoryMap(creds, "get_vod_categories");
    const list = await api<any[]>(creds, "get_vod_streams");
    for (const s of Array.isArray(list) ? list : []) {
      const id = String(s.stream_id);
      channels.push({
        id: `${pid}:m${id}`,
        playlistId: pid,
        name: String(s.name ?? "Sin nombre"),
        logo: s.stream_icon || undefined,
        group: group(cats, s.category_id),
        url: `${base}/movie/${U}/${P}/${id}.${s.container_extension || "mp4"}`,
        category: "movies",
        streamType: "movie",
        streamId: id,
        containerExtension: s.container_extension || undefined,
        rating: s.rating ? String(s.rating) : undefined,
      });
    }
  } catch (e: any) {
    warnings.push(`Películas: ${e?.message}`);
  }

  // --- Series (solo títulos; los episodios se piden al abrir cada serie)
  try {
    onProgress("Descargando series...");
    const cats = await categoryMap(creds, "get_series_categories");
    const list = await api<any[]>(creds, "get_series");
    for (const s of Array.isArray(list) ? list : []) {
      const id = String(s.series_id);
      channels.push({
        id: `${pid}:s${id}`,
        playlistId: pid,
        name: String(s.name ?? "Sin nombre"),
        logo: s.cover || undefined,
        group: group(cats, s.category_id),
        url: "",
        category: "series",
        streamType: "series",
        seriesId: id,
        plot: s.plot || undefined,
        rating: s.rating ? String(s.rating) : undefined,
      });
    }
  } catch (e: any) {
    warnings.push(`Series: ${e?.message}`);
  }

  if (channels.length === 0) throw new Error(warnings[0] || "La cuenta no devolvió contenido.");
  onProgress("Guardando en el dispositivo...");
  return { channels, warnings };
}

function credsOf(p: Playlist): XtreamCreds {
  return { server: p.server || "", username: p.username || "", password: p.password || "" };
}

export async function getSeriesInfo(p: Playlist, seriesId: string): Promise<SeriesInfo> {
  const r: any = await api(credsOf(p), "get_series_info", `&series_id=${encodeURIComponent(seriesId)}`);
  const eps = r?.episodes || {};
  const entries: [string, any[]][] = Array.isArray(eps)
    ? eps.map((arr: any[], i: number) => [String(i + 1), arr])
    : Object.entries(eps);

  const seasons: Record<number, Episode[]> = {};
  for (const [key, list] of entries) {
    for (const e of list || []) {
      const season = Number(e.season ?? key) || 1;
      (seasons[season] ||= []).push({
        id: String(e.id),
        title: e.title || `Episodio ${e.episode_num}`,
        season,
        num: Number(e.episode_num) || 0,
        ext: e.container_extension || "mp4",
        plot: e.info?.plot,
        duration: e.info?.duration,
        image: e.info?.movie_image,
      });
    }
  }
  for (const k of Object.keys(seasons)) seasons[Number(k)].sort((a, b) => a.num - b.num);
  return { plot: r?.info?.plot, cover: r?.info?.cover, seasons };
}

export function episodeUrl(p: Playlist, ep: Episode) {
  const c = credsOf(p);
  return `${normalizeServer(c.server)}/series/${encodeURIComponent(c.username)}/${encodeURIComponent(c.password)}/${ep.id}.${ep.ext}`;
}
