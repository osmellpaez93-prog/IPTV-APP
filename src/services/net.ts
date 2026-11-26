/**
 * appFetch: fetch unificado.
 *  - En Tauri usa el plugin http (URLs directas, sin CORS, sin proxy Node).
 *  - En navegador usa fetch normal (los callers pasan por proxify()).
 * Deteccion: "__TAURI_INTERNALS__" in window (documentacion oficial Tauri v2).
 * Los imports dinamicos llevan @vite-ignore para que el bundle web no
 * empaquete el plugin (solo se ejecuta dentro de Tauri).
 */
import { proxify } from "./proxy";

export const isTauri =
  typeof window !== "undefined" &&
  (window as any).__TAURI_INTERNALS__ !== undefined;

const UA = { "User-Agent": "VLC/3.0.20 LibVLC/3.0.20", Accept: "*/*" };

async function tauriFetch(url: string, init?: RequestInit): Promise<Response> {
  const mod: any = await import(/* @vite-ignore */ "@tauri-apps/plugin-http");
  return mod.fetch(url, {
    method: init?.method,
    headers: { ...UA, ...(init?.headers as Record<string, string>) },
    body: init?.body as any,
  });
}

export async function appFetch(url: string, init?: RequestInit): Promise<Response> {
  if (isTauri) return tauriFetch(url, init);
  return fetch(url, init);
}

/** Listas M3U y API Xtream: en Tauri directo, en navegador via proxify("playlist"). */
export async function appFetchPlaylist(url: string): Promise<Response> {
  if (isTauri) return tauriFetch(url);
  return fetch(await proxify(url, "playlist"));
}

/** Descargas varias (subtitulos etc.): en Tauri directo, en navegador igual que hoy. */
export async function appFetchStream(url: string): Promise<Response> {
  if (isTauri) return tauriFetch(url);
  return fetch(await proxify(url, "stream"));
}
