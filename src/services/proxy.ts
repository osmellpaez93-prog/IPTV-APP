// Construye URLs que pasan por el proxy Node para evitar CORS / mixed content.
import { getSettings } from "../db";
import { isTauri } from "./net";

export async function proxify(url: string, kind: "playlist" | "stream" | "image" = "stream"): Promise<string> {
  if (!url) return url;
  const s = await getSettings();
  const base = (s.proxyUrl || "/proxy").replace(/\/$/, "");
  if (url.startsWith(base + "/")) return url;
  return `${base}/${kind}?url=${encodeURIComponent(url)}`;
}

// En Tauri no hay mixed content ni CORS: devolvemos la URL tal cual.
// En navegador, los logos http:// dentro de pagina https:// pasan por el proxy.
export function imgUrl(url?: string): string | undefined {
  if (!url) return undefined;
  if (isTauri) return url;
  if (url.startsWith("http://") && typeof location !== "undefined" && location.protocol === "https:") {
    return `/proxy/image?url=${encodeURIComponent(url)}`;
  }
  return url;
}
