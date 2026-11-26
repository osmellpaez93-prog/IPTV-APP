<#
StreamBox - FASE 2: red sin proxy dentro de Tauri.
- tauri-plugin-http para llamadas directas a Xtream/M3U/subtitulos.
- appFetch() detecta Tauri (window.__TAURI_INTERNALS__) y usa el plugin;
  en navegador sigue usando fetch(await proxify(...)) como siempre.
- imgUrl() en Tauri devuelve la URL tal cual (http permitido).
- La app web sigue funcionando identica.
#>
param([switch]$Force)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "package.json"))) {
  Write-Host "ERROR: ejecuta en la raiz del repo." -ForegroundColor Red; return
}
Write-Host ""
Write-Host "StreamBox FASE 2 (red Tauri) -> $root" -ForegroundColor Cyan
if (-not $Force) {
  $r = Read-Host "Continuar? (S/N)"
  if ($r -notmatch '^[sSyY]') { Write-Host "Cancelado."; return }
}

function Get-NL([string]$t) { if ($t.Contains("`r`n")) { "`r`n" } else { "`n" } }

function Edit-File {
  param([string]$RelPath, [string]$Anchor, [string]$Insert, [string]$Marker)
  $full = Join-Path $root $RelPath
  if (-not (Test-Path $full)) { Write-Host "  ! $RelPath no existe" -ForegroundColor Yellow; return }
  $c = [System.IO.File]::ReadAllText($full)
  if ($c.Contains($Marker)) { Write-Host "  = $RelPath (ya aplicado)" -ForegroundColor Gray; return }
  $i = $c.IndexOf($Anchor)
  if ($i -lt 0) { Write-Host "  ! ANCLA no encontrada en ${RelPath}: $Anchor" -ForegroundColor Yellow; return }
  Copy-Item $full "$full.bak" -Force
  $nl = Get-NL $c
  $p = $i + $Anchor.Length
  $new = $c.Substring(0, $p) + $nl + $Insert + $c.Substring($p)
  [System.IO.File]::WriteAllText($full, $new, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  ~ $RelPath" -ForegroundColor Green
}

function Write-NewFile {
  param([string]$RelPath, [string]$Content)
  $full = Join-Path $root $RelPath
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if (-not $Content.EndsWith("`n")) { $Content += "`n" }
  if (Test-Path $full) {
    $old = [System.IO.File]::ReadAllText($full)
    if ($old -ne $Content) { Copy-Item $full "$full.bak" -Force }
  }
  [System.IO.File]::WriteAllText($full, $Content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  + $RelPath" -ForegroundColor Green
}

# ---------------- package.json ----------------
Edit-File 'package.json' '"zustand": "^4.5.5",' '"@tauri-apps/plugin-http": "^2.2.0",' '"@tauri-apps/plugin-http"'

# ---------------- Cargo.toml ----------------
Edit-File 'src-tauri/Cargo.toml' 'serde_json = "1"' 'tauri-plugin-http = "2"' 'tauri-plugin-http'

# ---------------- lib.rs ----------------
Edit-File 'src-tauri/src/lib.rs' 'tauri::Builder::default()' '.plugin(tauri_plugin_http::init())' 'tauri_plugin_http'

# ---------------- capabilities ----------------
Edit-File 'src-tauri/capabilities/default.json' '"core:default"' '"http:default"' 'http:default'

# ---------------- NUEVO: src/services/net.ts ----------------
Write-NewFile 'src/services/net.ts' @'
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
'@

# ---------------- m3u/parser.ts ----------------
Edit-File 'src/services/m3u/parser.ts' 'import { proxify } from "../proxy";' 'import { proxify } from "../proxy";' + (Get-NL ([System.IO.File]::ReadAllText((Join-Path $root "src/services/m3u/parser.ts")))) + 'import { appFetchPlaylist } from "../net";' 'appFetchPlaylist'

# Sustituir "res = await fetch(proxied);" por "res = await appFetchPlaylist(url);"
Edit-File 'src/services/m3u/parser.ts' 'res = await fetch(proxied);' 'res = await appFetchPlaylist(url);' 'appFetchPlaylist(url)'

# ---------------- xtream/client.ts ----------------
Edit-File 'src/services/xtream/client.ts' 'import { proxify } from "../proxy";' 'import { appFetchPlaylist } from "../net";' 'appFetchPlaylist'

# Sustituir el bloque "res = await fetch(await proxify(url, "playlist"));" por "res = await appFetchPlaylist(url);"
Edit-File 'src/services/xtream/client.ts' 'res = await fetch(await proxify(url, "playlist"));' 'res = await appFetchPlaylist(url);' 'appFetchPlaylist(url)'

# ---------------- subtitles.ts ----------------
Edit-File 'src/services/subtitles.ts' 'import type { Settings } from "../types";' 'import { appFetch } from "./net";' 'appFetch'
Edit-File 'src/services/subtitles.ts' 'res = await fetch(path, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });' 'res = await appFetch(path, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });' 'appFetch(path'

# ---------------- proxy.ts (imgUrl en Tauri) ----------------
# Reemplazamos imgUrl para que en Tauri devuelva la URL tal cual (http permitido)
$proxyContent = @'
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
'@
Write-NewFile 'src/services/proxy.ts' $proxyContent

Write-Host ""
Write-Host "Fase 2 aplicada." -ForegroundColor Green
Write-Host ""
Write-Host "Siguientes pasos:" -ForegroundColor Cyan
Write-Host "  1. npm install   (instala @tauri-apps/plugin-http)" -ForegroundColor White
Write-Host "  2. npm run build (debe pasar sin errores TS)" -ForegroundColor White
Write-Host "  3. npx tauri dev (abre la app; ahora las listas Xtream/M3U van DIRECTAS, sin proxy Node)" -ForegroundColor White
Write-Host ""
Write-Host "Verificacion:" -ForegroundColor Yellow
Write-Host "  - En navegador (npm start): todo igual que antes (usa proxy Node)." -ForegroundColor White
Write-Host "  - En Tauri (tauri dev): se pueden anadir listas Xtream/M3U y ver caratulas" -ForegroundColor White
Write-Host "    sin que corra 'npm start'. El proxy Node ya no es necesario en Tauri." -ForegroundColor White
Write-Host ""
Write-Host "Riesgos / no comprobado:" -ForegroundColor Yellow
Write-Host "  - 'http:default' da acceso a cualquier URL http/https desde Tauri." -ForegroundColor White
Write-Host "    Es aceptable porque el usuario solo anade sus propias listas." -ForegroundColor White
Write-Host "  - Si 'npm run build' falla por TS, revisa que @tauri-apps/plugin-http" -ForegroundColor White
Write-Host "    este en package.json (deberia haberlo añadido el script)." -ForegroundColor White