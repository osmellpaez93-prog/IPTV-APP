/**
 * appFetch: fetch unificado que en Tauri usa el plugin http (sin CORS, sin proxy)
 * y en navegador usa fetch normal (con proxify para evitar CORS/mixed content).
 *
 * Deteccion: "__TAURI_INTERNALS__" in window (documentacion oficial Tauri v2).
 */
import { proxify } from "./proxy";

export const isTauri =
  typeof window !== "undefined" &&
  (window as any).__TAURI_INTERNALS__ !== undefined;

export async function appFetch(url: string, init?: RequestInit): Promise<Response> {
  if (isTauri) {
    // Importacion dinamica para que el bundle de navegador no incluya el plugin.
    const mod = await import("@tauri-apps/plugin-http");
    const headers: Record<string, string> = {
      "User-Agent": "VLC/3.0.20 LibVLC/3.0.20",
      Accept: "*/*",
      ...(init?.headers as Record<string, string>),
    };
    return mod.fetch(url, {
      method: init?.method,
      headers,
      body: init?.body as any,
    });
  }
  // Navegador: el caller ya ha llamado a proxify() cuando corresponde.
  return fetch(url, init);
}

/**
 * appFetchPlaylist: para listas M3U y llamadas Xtream, en navegador pasa por el proxy;
 * en Tauri va directa a la URL original.
 */
export async function appFetchPlaylist(url: string): Promise<Response> {
  if (isTauri) {
    const mod = await import("@tauri-apps/plugin-http");
    return mod.fetch(url, {
      headers: {
        "User-Agent": "VLC/3.0.20 LibVLC/3.0.20",
        Accept: "*/*",
      },
    });
  }
  const proxied = await proxify(url, "playlist");
  return fetch(proxied);
}

/**
 * appFetchStream: para streams de video. En Tauri, directa; en navegador, por proxy.
 * NOTA: el reproductor web (hls.js / mpegts.js) usa sus propias URLs; este helper
 * se usa solo para descargas de subtitulos y llamadas a la API Xtream.
 */
export async function appFetchStream(url: string): Promise<Response> {
  if (isTauri) {
    const mod = await import("@tauri-apps/plugin-http");
    return mod.fetch(url, {
      headers: {
        "User-Agent": "VLC/3.0.20 LibVLC/3.0.20",
        Accept: "*/*",
      },
    });
  }
  const proxied = await proxify(url, "stream");
  return fetch(proxied);
}
