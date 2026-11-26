<#
StreamBox - FASE 1: envolver la app en Tauri v2 (sin tocar React).
Uso (raiz del repo):  powershell -ExecutionPolicy Bypass -File .\tauri-fase1.ps1
Idempotente. Ediciones por ancla + marcador. Archivos nuevos sin acentos (ASCII).
#>
param([switch]$Force)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "package.json"))) {
  Write-Host "ERROR: ejecuta en la raiz del repo (donde esta package.json)." -ForegroundColor Red
  return
}
Write-Host ""
Write-Host "StreamBox FASE 1 (Tauri) -> $root" -ForegroundColor Cyan
if (-not $Force) {
  $r = Read-Host "Continuar? (S/N)"
  if ($r -notmatch '^[sSyY]') { Write-Host "Cancelado."; return }
}

function Get-NL([string]$t) { if ($t.Contains("`r`n")) { "`r`n" } else { "`n" } }

function Edit-File {
  param([string]$RelPath, [string]$Anchor, [string]$Insert, [string]$Marker)
  $full = Join-Path $root $RelPath
  if (-not (Test-Path $full)) { Write-Host "  ! $RelPath no existe (omitido)" -ForegroundColor Yellow; return }
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
  param([string]$RelPath, [string]$Content, [switch]$OnlyIfMissing)
  $full = Join-Path $root $RelPath
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if ((Test-Path $full) -and $OnlyIfMissing) {
    Write-Host "  = $RelPath (ya existe, no se toca)" -ForegroundColor Gray; return
  }
  if (-not $Content.EndsWith("`n")) { $Content += "`n" }
  if (Test-Path $full) {
    $old = [System.IO.File]::ReadAllText($full)
    if ($old -ne $Content) { Copy-Item $full "$full.bak" -Force }
  }
  [System.IO.File]::WriteAllText($full, $Content, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  + $RelPath" -ForegroundColor Green
}

# ---------------- Ediciones minimas ----------------
Edit-File 'package.json' '"preview": "vite preview",' '"tauri": "tauri",' '"tauri": "tauri",'
Edit-File 'package.json' '"tauri": "tauri",' '"tauri:dev": "tauri dev",' '"tauri:dev"'
Edit-File 'package.json' '"clsx": "^2.1.1",' '"@tauri-apps/api": "^2.1.1",' '"@tauri-apps/api"'
Edit-File 'package.json' '"autoprefixer": "^10.4.20",' '"@tauri-apps/cli": "^2.1.0",' '"@tauri-apps/cli"'
Edit-File 'vite.config.ts' 'plugins: [' 'clearScreen: false,' 'clearScreen'
Edit-File '.gitignore' '*.bak' ('src-tauri/target' + (Get-NL ([System.IO.File]::ReadAllText((Join-Path $root ".gitignore")))) + 'src-tauri/gen') 'src-tauri/target'

# ---------------- src-tauri (nuevos) ----------------
Write-NewFile 'src-tauri/Cargo.toml' @'
[package]
name = "streambox"
version = "0.1.0"
description = "StreamBox IPTV Player"
authors = ["Osmel"]
edition = "2021"

[lib]
name = "streambox_lib"
crate-type = ["staticlib", "cdylib", "rlib"]

[build-dependencies]
tauri-build = { version = "2", features = [] }

[dependencies]
tauri = { version = "2", features = [] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
'@

Write-NewFile 'src-tauri/build.rs' @'
fn main() {
    tauri_build::build()
}
'@

Write-NewFile 'src-tauri/src/main.rs' @'
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    streambox_lib::run()
}
'@

Write-NewFile 'src-tauri/src/lib.rs' @'
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
'@

Write-NewFile 'src-tauri/tauri.conf.json' @'
{
  "$schema": "https://schema.tauri.app/config/2",
  "productName": "StreamBox",
  "version": "0.1.0",
  "identifier": "es.raellstudio.streambox",
  "build": {
    "beforeDevCommand": "npm run dev",
    "devUrl": "http://localhost:5173",
    "beforeBuildCommand": "npm run build",
    "frontendDist": "../dist"
  },
  "app": {
    "windows": [
      {
        "title": "StreamBox",
        "width": 1280,
        "height": 800,
        "resizable": true
      }
    ],
    "security": {
      "csp": null
    }
  },
  "bundle": {
    "active": true,
    "targets": "all",
    "icon": [
      "icons/32x32.png",
      "icons/128x128.png",
      "icons/128x128@2x.png",
      "icons/icon.icns",
      "icons/icon.ico"
    ]
  }
}
'@

Write-NewFile 'src-tauri/capabilities/default.json' @'
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Capacidades basicas de la ventana principal de StreamBox",
  "windows": ["main"],
  "permissions": [
    "core:default"
  ]
}
'@

# target-dir en disco local (el repo esta en externo lento). Solo si no existe.
Write-NewFile '.cargo/config.toml' @'
[build]
target-dir = "C:/cargo-target/streambox"
'@ -OnlyIfMissing

Write-Host ""
Write-Host "Cambios aplicados. Pasos siguientes:" -ForegroundColor Green
Write-Host "  1. npm install" -ForegroundColor White
Write-Host "  2. npx tauri icon public/icons/icon-512.png" -ForegroundColor White
Write-Host "  3. npm run build   (debe seguir pasando)" -ForegroundColor White
Write-Host "  4. npx tauri dev   (abre la app en ventana nativa)" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANTE: para 'tauri dev' NO tengas 'npm start' corriendo a la vez" -ForegroundColor Yellow
Write-Host "(Vite ocuparia el 5173 y la ventana abriria una pagina vacia)." -ForegroundColor Yellow