<#
StreamBox - fix-transcode.ps1
Arregla el error TS2345 en usePlayer.ts linea 256:
  "transcode" no es asignable a ProxyKind.
Solucion: ampliar el tipo en proxy.ts para aceptar "transcode".
Idempotente. Guarda .bak. UTF-8 sin BOM.
#>
param([switch]$Force)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "package.json"))) {
  Write-Host "ERROR: ejecuta en la raiz del repo." -ForegroundColor Red; return
}
Write-Host ""
Write-Host "Reparando tipo ProxyKind -> $root" -ForegroundColor Cyan
if (-not $Force) {
  $r = Read-Host "Continuar? (S/N)"
  if ($r -notmatch '^[sSyY]') { Write-Host "Cancelado."; return }
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

# proxy.ts: ampliar ProxyKind para aceptar "transcode"
Edit-Replace 'src/services/proxy.ts' `
  'export async function proxify(url: string, kind: "playlist" | "stream" | "image" = "stream"): Promise<string> {' `
  'export async function proxify(url: string, kind: "playlist" | "stream" | "image" | "transcode" = "stream"): Promise<string> {' `
  '"transcode"'

Write-Host ""
Write-Host "Listo. Verifica con:" -ForegroundColor Green
Write-Host "  npm run build" -ForegroundColor White