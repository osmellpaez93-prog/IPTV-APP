<#
StreamBox - fix-tauri-http.ps1
Repara la config del plugin http en Tauri (Fase 2):
  1. capabilities/default.json -> JSON valido con permiso http y scope http(s)
  2. Cargo.toml                -> asegura tauri-plugin-http
  3. src/lib.rs                -> asegura .plugin(tauri_plugin_http::init())
Idempotente. Guarda .bak. UTF-8 sin BOM.
#>
param([switch]$Force)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "package.json"))) {
  Write-Host "ERROR: ejecuta en la raiz del repo." -ForegroundColor Red; return
}
Write-Host ""
Write-Host "Reparando config Tauri http -> $root" -ForegroundColor Cyan
if (-not $Force) {
  $r = Read-Host "Continuar? (S/N)"
  if ($r -notmatch '^[sSyY]') { Write-Host "Cancelado."; return }
}

function Get-NL([string]$t) { if ($t.Contains("`r`n")) { "`r`n" } else { "`n" } }

function Save-Text {
  param([string]$RelPath, [string]$Content)
  $full = Join-Path $root $RelPath
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if (-not $Content.EndsWith("`n")) { $Content += "`n" }
  if (Test-Path $full) {
    $old = [System.IO.File]::ReadAllText($full)
    if ($old -eq $Content) { Write-Host "  = $RelPath (sin cambios)" -ForegroundColor Gray; return }
    Copy-Item $full "$full.bak" -Force
  }
  [System.IO.File]::WriteAllText($full, $Content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  ~ $RelPath" -ForegroundColor Green
}

function Add-After {
  param([string]$RelPath, [string]$Anchor, [string]$Insert, [string]$Marker)
  $full = Join-Path $root $RelPath
  if (-not (Test-Path $full)) { Write-Host "  ! $RelPath no existe" -ForegroundColor Yellow; return }
  $c = [System.IO.File]::ReadAllText($full)
  if ($c.Contains($Marker)) { Write-Host "  = $RelPath (ya aplicado)" -ForegroundColor Gray; return }
  $i = $c.IndexOf($Anchor)
  if ($i -lt 0) { Write-Host "  ! ancla no encontrada en ${RelPath}" -ForegroundColor Yellow; return }
  Copy-Item $full "$full.bak" -Force
  $nl = Get-NL $c
  $p = $i + $Anchor.Length
  $new = $c.Substring(0, $p) + $nl + $Insert + $c.Substring($p)
  [System.IO.File]::WriteAllText($full, $new, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  ~ $RelPath" -ForegroundColor Green
}

# 1) capabilities: JSON valido (reescrito; es archivo de config creado en Fase 1)
Save-Text 'src-tauri/capabilities/default.json' @'
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Permisos de la ventana principal de StreamBox",
  "windows": ["main"],
  "permissions": [
    "core:default",
    {
      "identifier": "http:default",
      "allow": [{ "url": "http://**" }, { "url": "https://**" }]
    }
  ]
}
'@

# 2) Cargo.toml: dependencia del plugin
Add-After 'src-tauri/Cargo.toml' 'serde_json = "1"' 'tauri-plugin-http = "2"' 'tauri-plugin-http'

# 3) lib.rs: registrar el plugin
Add-After 'src-tauri/src/lib.rs' 'tauri::Builder::default()' '        .plugin(tauri_plugin_http::init())' 'tauri_plugin_http'

Write-Host ""
Write-Host "Ahora ejecuta:" -ForegroundColor Green
Write-Host "  npm install @tauri-apps/plugin-http" -ForegroundColor White
Write-Host "  npm run build" -ForegroundColor White
Write-Host "  npx tauri dev" -ForegroundColor White