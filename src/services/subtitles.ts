// Cliente de subtitulos: busqueda/descarga via nuestro servidor (OpenSubtitles) y conversion SRT -> VTT.
import type { Settings } from "../types";

export interface SubResult {
  fileId: number;
  release: string;
  language: string;
  downloads: number;
  hearingImpaired: boolean;
  trusted?: boolean;
  ai?: boolean;
  title?: string;
  year?: number;
}

export interface SubQuery {
  query: string;
  year?: string;
  season?: string;
  episode?: string;
}

// Limpia el nombre de un canal/pelicula de IPTV para buscar subtitulos
export function guessQuery(raw: string): SubQuery {
  let n = raw.replace(/\s+/g, " ").trim();

  // Episodios de serie: "Nombre serie · T1E2 Titulo"
  const dot = n.indexOf(" · ");
  const ep = n.match(/\bT(\d{1,2})\s?E(\d{1,3})\b/i) || n.match(/\bS(\d{1,2})\s?E(\d{1,3})\b/i);
  if (dot > 0 && ep) {
    return { query: n.slice(0, dot).trim(), season: String(parseInt(ep[1], 10)), episode: String(parseInt(ep[2], 10)) };
  }

  n = n.replace(/^[A-Za-z0-9_ ]{2,10}\|\s*/, ""); // prefijo "ES| "
  n = n.replace(/[\[(][^\])]*[\])]/g, (m) => (/(19|20)\d{2}/.test(m) ? m : " "));
  const y = n.match(/\b(19|20)\d{2}\b/);
  n = n.replace(/\(?\b(19|20)\d{2}\b\)?/, " ");
  n = n.replace(/\b(4k|uhd|fhd|hd|sd|1080p|720p|2160p|hevc|x264|x265|dual|lat|latino|castellano|spa|esp|multi|subs?|vose|vos)\b/gi, " ");
  n = n.replace(/[._]+/g, " ").replace(/\s+/g, " ").trim();
  return { query: n, year: y?.[0] };
}

export function decodeText(bytes: Uint8Array): string {
  const utf8 = new TextDecoder("utf-8").decode(bytes);
  if (!utf8.includes("\uFFFD")) return utf8;
  return new TextDecoder("windows-1252").decode(bytes);
}

export function srtToVtt(srt: string): string {
  const text = srt.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n").trim();
  return "WEBVTT\n\n" + text.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, "$1.$2") + "\n";
}

async function post<T>(path: string, body: unknown): Promise<T> {
  let res: Response;
  try {
    res = await fetch(path, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  } catch {
    throw new Error("No se pudo conectar con el servidor de StreamBox.");
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data?.error || `Error ${res.status}`);
  return data as T;
}

export async function searchSubs(s: Settings, q: SubQuery, languages: string): Promise<SubResult[]> {
  const r = await post<{ items: SubResult[] }>("/api/subs/search", { apiKey: s.osApiKey, languages, ...q });
  return r.items;
}

export async function downloadSub(s: Settings, fileId: number) {
  return post<{ vtt: string; remaining?: number; fileName?: string }>("/api/subs/download", {
    apiKey: s.osApiKey,
    username: s.osUsername,
    password: s.osPassword,
    fileId,
  });
}
