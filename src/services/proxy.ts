// Construye URLs que pasan por el proxy Node para evitar CORS / mixed content.
import { getSettings } from "../db";
export async function proxify(url: string, kind: "playlist" | "stream" | "image" = "stream"): Promise<string> {
  if (!url) return url;
  const s = await getSettings();
  const base = (s.proxyUrl || "/proxy").replace(/\/$/, "");
  if (url.startsWith(base + "/")) return url;
  return `${base}/${kind}?url=${encodeURIComponent(url)}`;
}
// Logos http:// no cargan dentro de una pagina https://, los pasamos por el proxy.
export function imgUrl(url?: string): string | undefined {
  if (!url) return undefined;
  if (url.startsWith("http://") && typeof location !== "undefined" && location.protocol === "https:") {
    return `/proxy/image?url=${encodeURIComponent(url)}`;
  }
  return url;
}
