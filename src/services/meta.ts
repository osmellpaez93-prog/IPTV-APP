/**
 * Fichas de películas y series: sinopsis, carátula, fondo, reparto, géneros...
 * Orden de fuentes: 1) datos del proveedor Xtream (gratis)  2) TMDB si hay API key (mejora y completa).
 * Resultado en caché 30 días (IndexedDB). Si TMDB falla por red no se guarda en caché.
 */
import { db, getSettings } from "../db";
import type { Channel, Playlist, Settings } from "../types";
import { guessQuery } from "./subtitles";
import { proxify } from "./proxy";
import { normalizeServer, parseXtreamFromUrl } from "./xtream/client";

export interface Meta {
  title: string;
  overview?: string;
  poster?: string;
  backdrop?: string;
  rating?: string;
  year?: string;
  genres: string[];
  runtime?: string;
  cast: string[];
  director?: string;
  source: "tmdb" | "provider" | "none";
}

const TTL = 30 * 24 * 3600 * 1000;
const IMG = "https://image.tmdb.org/t/p";

interface Creds { server: string; username: string; password: string }

const splitList = (v: unknown): string[] =>
  typeof v === "string" ? v.split(/[,/|]/).map((x) => x.trim()).filter(Boolean)
  : Array.isArray(v) ? v.map((x) => String(x)) : [];

const num = (v: unknown): string | undefined => {
  const n = Number(v);
  return isFinite(n) && n > 0 ? n.toFixed(1) : undefined;
};

const year = (v: unknown): string | undefined => String(v ?? "").match(/\d{4}/)?.[0];

function pick(base: Partial<Meta>, over: Partial<Meta>): Partial<Meta> {
  const out: Record<string, unknown> = { ...base };
  for (const [k, v] of Object.entries(over)) {
    if (v === undefined || v === "" || (Array.isArray(v) && v.length === 0)) continue;
    out[k] = v;
  }
  return out as Partial<Meta>;
}

function credsFromPlaylist(p?: Playlist): Creds | null {
  if (!p) return null;
  if (p.type === "xtream" && p.server && p.username && p.password) {
    return { server: normalizeServer(p.server), username: p.username, password: p.password };
  }
  if (p.type === "m3u-url" && p.url) {
    const c = parseXtreamFromUrl(p.url);
    if (c) return { ...c, server: normalizeServer(c.server) };
  }
  return null;
}

function credsFromMovieUrl(url: string): (Creds & { id: string }) | null {
  const m = url.match(/^(https?:\/\/[^/]+)\/movie\/([^/]+)\/([^/]+)\/(\d+)\.[a-z0-9]+/i);
  if (!m) return null;
  const dec = (s: string) => { try { return decodeURIComponent(s); } catch { return s; } };
  return { server: m[1], username: dec(m[2]), password: dec(m[3]), id: m[4] };
}

async function api(c: Creds, action: string, extra: string): Promise<any> {
  const url =
    `${c.server}/player_api.php?username=${encodeURIComponent(c.username)}` +
    `&password=${encodeURIComponent(c.password)}&action=${action}${extra}`;
  const res = await fetch(await proxify(url, "playlist"));
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return JSON.parse(await res.text());
}

function fromProviderInfo(info: any): Partial<Meta> {
  const bd = Array.isArray(info?.backdrop_path) ? info.backdrop_path[0] : info?.backdrop_path;
  return {
    overview: info?.plot || info?.description || undefined,
    poster: info?.movie_image || info?.cover || undefined,
    backdrop: bd || undefined,
    rating: num(info?.rating),
    year: year(info?.releasedate || info?.releaseDate || info?.release_date),
    genres: splitList(info?.genre),
    runtime: info?.duration || (info?.episode_run_time ? `${info.episode_run_time} min` : undefined) || undefined,
    cast: splitList(info?.cast || info?.actors).slice(0, 8),
    director: info?.director || undefined,
  };
}

async function providerMeta(ch: Channel): Promise<Partial<Meta>> {
  try {
    if (ch.category === "series" && ch.seriesId) {
      const c = credsFromPlaylist(await db.playlists.get(ch.playlistId));
      if (!c) return {};
      const d = await api(c, "get_series_info", `&series_id=${encodeURIComponent(ch.seriesId)}`);
      return fromProviderInfo(d?.info);
    }
    if (ch.category === "movies") {
      const fromUrl = credsFromMovieUrl(ch.url);
      const c = fromUrl ?? credsFromPlaylist(await db.playlists.get(ch.playlistId));
      const id = ch.streamId || fromUrl?.id;
      if (!c || !id) return {};
      const d = await api(c, "get_vod_info", `&vod_id=${encodeURIComponent(id)}`);
      return fromProviderInfo(d?.info);
    }
  } catch {}
  return {};
}

async function tmdb<T>(key: string, path: string, params: Record<string, string>): Promise<T> {
  const u = new URL(`https://api.themoviedb.org/3${path}`);
  for (const [k, v] of Object.entries(params)) u.searchParams.set(k, v);
  const headers: Record<string, string> = { Accept: "application/json" };
  if (key.startsWith("eyJ") || key.length > 60) headers.Authorization = `Bearer ${key}`;
  else u.searchParams.set("api_key", key);
  const res = await fetch(u.toString(), { headers });
  if (!res.ok) throw new Error(`TMDB ${res.status}`);
  return res.json() as Promise<T>;
}

async function tmdbMeta(ch: Channel, s: Settings): Promise<Partial<Meta> | null> {
  const key = s.tmdbApiKey.trim();
  if (!key) return null;
  const isTv = ch.category === "series";
  if (ch.category !== "movies" && !isTv) return null;
  const q = guessQuery(ch.name);
  if (!q.query) return null;
  const lang = s.language === "en" ? "en-US" : "es-ES";
  const kind = isTv ? "tv" : "movie";

  const search = (withYear: boolean) =>
    tmdb<any>(key, `/search/${kind}`, {
      query: q.query,
      language: lang,
      include_adult: "false",
      ...(withYear && q.year ? (isTv ? { first_air_date_year: q.year } : { year: q.year }) : {}),
    });

  let r = await search(true);
  if (!r?.results?.length && q.year) r = await search(false);
  const hit = r?.results?.[0];
  if (!hit) return {};

  const d = await tmdb<any>(key, `/${kind}/${hit.id}`, { language: lang, append_to_response: "credits" });
  const cast = (d.credits?.cast ?? []).slice(0, 8).map((c: any) => String(c.name));
  const director = isTv
    ? (d.created_by ?? []).map((c: any) => c.name).join(", ")
    : (d.credits?.crew ?? []).find((c: any) => c.job === "Director")?.name;
  const rt = isTv ? d.episode_run_time?.[0] : d.runtime;

  return {
    title: d.title || d.name || undefined,
    overview: d.overview || undefined,
    poster: d.poster_path ? `${IMG}/w500${d.poster_path}` : undefined,
    backdrop: d.backdrop_path ? `${IMG}/w1280${d.backdrop_path}` : undefined,
    rating: num(d.vote_average),
    year: year(isTv ? d.first_air_date : d.release_date),
    genres: (d.genres ?? []).map((g: any) => String(g.name)),
    runtime: rt ? `${rt} min` : undefined,
    cast,
    director: director || undefined,
  };
}

export async function getMeta(ch: Channel): Promise<Meta> {
  const s = await getSettings();
  const lang = s.language === "en" ? "en" : "es";
  const hasKey = !!s.tmdbApiKey.trim();
  const id = `${ch.id}|${lang}|${hasKey ? "t" : "p"}`;

  const cached = await db.meta.get(id).catch(() => undefined);
  if (cached && Date.now() - cached.at < TTL) return cached.data as Meta;

  const fallbackTitle = guessQuery(ch.name).query || ch.name;
  const provider = await providerMeta(ch);
  let tm: Partial<Meta> | null = null;
  let tmdbFailed = false;
  try { tm = await tmdbMeta(ch, s); } catch { tmdbFailed = true; }

  const base: Partial<Meta> = { title: fallbackTitle, poster: ch.logo, rating: num(ch.rating) };
  const m = pick(pick(base, provider), tm ?? {});
  const hasTmdb = !!(tm && (tm.overview || tm.poster || tm.backdrop));
  const hasProv = !!(provider.overview || provider.poster || provider.backdrop);

  const meta: Meta = {
    title: m.title ?? fallbackTitle,
    overview: m.overview,
    poster: m.poster,
    backdrop: m.backdrop,
    rating: m.rating,
    year: m.year,
    genres: m.genres ?? [],
    runtime: m.runtime,
    cast: m.cast ?? [],
    director: m.director,
    source: hasTmdb ? "tmdb" : hasProv ? "provider" : "none",
  };

  if (!tmdbFailed) await db.meta.put({ id, at: Date.now(), data: meta }).catch(() => {});
  return meta;
}
