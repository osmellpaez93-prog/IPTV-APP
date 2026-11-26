<#
StreamBox - fix-fase2.ps1
Repara los 5 errores de build de la Fase 2:
  1. proxy.ts   -> anade "transcode" a ProxyKind (lo usa tu usePlayer.ts actual)
  2. parser.ts  -> reinserta el import de appFetchPlaylist si falta
  3. net.ts     -> reescrito con @vite-ignore (el bundle web no empaqueta el plugin)
  4. tauri-http.d.ts -> declaracion para que TS no falle si el paquete no esta instalado
Idempotente. .bak en cada archivo tocado. UTF-8 sin BOM.
#>
param([switch]$Force)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "package.json"))) {
  Write-Host "ERROR: ejecuta en la raiz del repo." -ForegroundColor Red; return
}
Write-Host ""
Write-Host "Reparando Fase 2 -> $root" -ForegroundColor Cyan
if (-not $Force) {
  $r = Read-Host "Continuar? (S/N)"
  if ($r -notmatch '^[sSyY]') { Write-Host "Cancelado."; return }
}

function Get-NL([string]$t) { if ($t.Contains("`r`n")) { "`r`n" } else { "`n" } }

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

function Edit-Replace {
  param([string]$RelPath, [string]$Find, [string]$Replace, [string]$Marker)
  $full = Join-Path $root $RelPath
  if (-not (Test-Path $full)) { Write-Host "  ! $RelPath no existe" -ForegroundColor Yellow; return }
  $c = [System.IO.File]::ReadAllText($full)
  if ($c.Contains($Marker)) { Write-Host "  = $RelPath (ya aplicado)" -ForegroundColor Gray; return }
  $i = $c.IndexOf($Find)
  if ($i -lt 0) { Write-Host "  ! no encontrado en ${RelPath}: $Find" -ForegroundColor Yellow; return }
  Copy-Item $full "$full.bak" -Force
  $new = $c.Substring(0, $i) + $Replace + $c.Substring($i + $Find.Length)
  [System.IO.File]::WriteAllText($full, $new, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  ~ $RelPath" -ForegroundColor Green
}

function Ensure-Import {
  param([string]$RelPath, [string]$Anchor, [string]$ImportLine)
  $full = Join-Path $root $RelPath
  if (-not (Test-Path $full)) { Write-Host "  ! $RelPath no existe" -ForegroundColor Yellow; return }
  $c = [System.IO.File]::ReadAllText($full)
  if ($c.Contains($ImportLine)) { Write-Host "  = $RelPath (import ya presente)" -ForegroundColor Gray; return }
  $i = $c.IndexOf($Anchor)
  if ($i -lt 0) { Write-Host "  ! ancla no encontrada en ${RelPath}: $Anchor" -ForegroundColor Yellow; return }
  Copy-Item $full "$full.bak" -Force
  $nl = Get-NL $c
  $p = $i + $Anchor.Length
  $new = $c.Substring(0, $p) + $nl + $ImportLine + $c.Substring($p)
  [System.IO.File]::WriteAllText($full, $new, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  ~ $RelPath (import insertado)" -ForegroundColor Green
}

# 1) proxy.ts: ProxyKind admite "transcode"
Edit-Replace 'src/services/proxy.ts' `
  'export type ProxyKind = "playlist" | "stream" | "image";' `
  'export type ProxyKind = "playlist" | "stream" | "image" | "transcode";' `
  '"transcode"'

# 2) parser.ts: garantizar el import de appFetchPlaylist
Ensure-Import 'src/services/m3u/parser.ts' `
  'import { proxify } from "../proxy";' `
  'import { appFetchPlaylist } from "../net";'

# 3) net.ts: reescrito con @vite-ignore (Vite no empaqueta el plugin en el build web)
Write-NewFile 'src/services/net.ts' @'
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
'@

# 4) declaracion de modulo: el build pasa aunque el paquete no este instalado
Write-NewFile 'src/types/tauri-http.d.ts' @'
declare module "@tauri-apps/plugin-http" {
  export function fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>;
}
'@

Write-Host ""
Write-Host "Cambios aplicados. Ahora instala el plugin (necesario para Tauri):" -ForegroundColor Green
Write-Host "  npm install" -ForegroundColor White
Write-Host "  npm run build" -ForegroundColor White
Write-Host ""
Write-Host "Si 'npm install' falla (sin red), el build igualmente pasa gracias" -ForegroundColor Yellow
Write-Host "a la declaracion de modulo; solo 'npx tauri dev' no usara red directa." -ForegroundColor Yellow
Write-Host ""
Write-Host "AVISO sobre 'transcode': tu usePlayer.ts pide /proxy/transcode." -ForegroundColor Yellow
Write-Host "El server/index.js actual no tiene ese endpoint, asi que esos canales" -ForegroundColor Yellow
Write-Host "fallbackan al siguiente formato (no rompen, pero no transcodifican)." -ForegroundColor Yellow
Write-Host "Para transcodificacion real hace falta ffmpeg + endpoint aparte." -ForegroundColor Yellow