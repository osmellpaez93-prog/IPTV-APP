/**
 * Parser M3U/M3U8.
 * - Atributos key="value" (tvg-id, tvg-logo, group-title, tvg-name...)
 * - IDs estables (hash de la URL): los favoritos sobreviven a recargar la lista
 * - Clasificacion live / movies / series por URL (/movie/, /series/), grupo y nombre
 */
import type { Channel } from "../../types";
import { proxify } from "../proxy";

const ATTR_RE = /([a-zA-Z0-9_-]+)="([^"]*)"/g;

function parseExtInf(line: string) {
  const attrs: Record<string, string> = {};
  let m: RegExpExecArray | null;
  ATTR_RE.lastIndex = 0;
  while ((m = ATTR_RE.exec(line)) !== null) attrs[m[1].toLowerCase()] = m[2];

  // El nombre va tras la primera coma posterior al ultimo atributo entrecomillado
  const lastQuote = line.lastIndexOf('"');
  const commaIdx = line.indexOf(",", lastQuote >= 0 ? lastQuote : 0);
  const name = (commaIdx >= 0 ? line.slice(commaIdx + 1).trim() : "") || attrs["tvg-name"] || "Sin nombre";
  return { name, attrs };
}

function classify(group: string, name: string, url: string): Channel["category"] {
  const u = url.toLowerCase();
  const g = group.toLowerCase();
  if (/\/series\//.test(u)) return "series";
  if (/\/movie\//.test(u)) return "movies";
  if (/\bs\d{1,2}\s?e\d{1,3}\b/i.test(name) || /(serie|temporada|season)/.test(g)) return "series";
  if (/(pel[ií]cula|movie|vod|film)/.test(g)) return "movies";
  if (/\.(mp4|mkv|avi|mov|wmv)(\?|$)/.test(u)) return "movies";
  return "live";
}

// Hash de 53 bits (cyrb53) para ids estables
function hash(str: string): string {
  let h1 = 0xdeadbeef, h2 = 0x41c6ce57;
  for (let i = 0; i < str.length; i++) {
    const ch = str.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(36);
}

export interface ParseResult {
  channels: Channel[];
  groups: string[];
}

export async function parseM3U(rawText: string, playlistId: string): Promise<ParseResult> {
  const text = rawText.replace(/^\uFEFF/, "");
  const lines = text.split(/\r?\n/);
  const channels: Channel[] = [];
  const groupsSet = new Set<string>();
  const seen = new Map<string, number>();

  let pending: ReturnType<typeof parseExtInf> | null = null;
  let pendingGroup: string | undefined;

  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;

    if (line.startsWith("#EXTINF")) {
      pending = parseExtInf(line);
      continue;
    }
    if (line.startsWith("#EXTGRP")) {
      pendingGroup = line.slice(line.indexOf(":") + 1).trim();
      continue;
    }
    if (line.startsWith("#")) continue;

    if (pending) {
      const group = pending.attrs["group-title"] || pendingGroup || "Sin categoría";
      groupsSet.add(group);

      const base = `${playlistId}:${hash(line)}`;
      const n = (seen.get(base) ?? 0) + 1;
      seen.set(base, n);

      channels.push({
        id: n === 1 ? base : `${base}-${n}`,
        playlistId,
        name: pending.name,
        logo: pending.attrs["tvg-logo"] || undefined,
        group,
        tvgId: pending.attrs["tvg-id"] || undefined,
        url: line,
        category: classify(group, pending.name, line),
      });
      pending = null;
      pendingGroup = undefined;
    }
  }

  if (channels.length === 0) throw new Error("No se encontraron canales. Comprueba que sea una lista M3U valida.");
  return { channels, groups: Array.from(groupsSet).sort((a, b) => a.localeCompare(b)) };
}

export async function loadM3UFromUrl(url: string, playlistId: string): Promise<ParseResult> {
  const proxied = await proxify(url, "playlist");
  let res: Response;
  try {
    res = await fetch(proxied);
  } catch {
    throw new Error("No se pudo conectar con el proxy. Ejecuta 'npm start'.");
  }
  if (!res.ok) throw new Error(`HTTP ${res.status} al descargar la lista`);
  return parseM3U(await res.text(), playlistId);
}

export async function loadM3UFromFile(file: File, playlistId: string): Promise<ParseResult> {
  return parseM3U(await file.text(), playlistId);
}
