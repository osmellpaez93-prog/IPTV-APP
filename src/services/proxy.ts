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
