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
