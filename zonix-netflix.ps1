<#
StreamBox - fix-epg-overlap.ps1
Arregla la rejilla EPG: la celda del canal debe ser OPAICA y quedar por encima
de los bloques de programacion (antes el degradado semitransparente de la fila
seleccionada dejaba ver la cartelera a traves del nombre).
Edita solo src/components/tv/EpgTimeline.tsx (2 anclas). Idempotente, .bak, UTF-8 sin BOM.
Uso (raiz del repo):  powershell -ExecutionPolicy Bypass -File .\fix-epg-overlap.ps1
#>
param([switch]$Force)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "src\components\tv\EpgTimeline.tsx"))) {
  Write-Host "ERROR: no encuentro src\components\tv\EpgTimeline.tsx." -ForegroundColor Red; return
}
Write-Host ""
Write-Host "Fix EPG overlap -> $root" -ForegroundColor Cyan
if (-not $Force) {
  $r = Read-Host "Continuar? (S/N)"
  if ($r -notmatch '^[sSyY]') { Write-Host "Cancelado."; return }
}

function Edit-Replace {
  param([string]$RelPath, [string]$Find, [string]$Replace, [string]$Marker)
  $full = Join-Path $root $RelPath
  $c = [System.IO.File]::ReadAllText($full)
  if ($c.Contains($Marker)) { Write-Host "  = $RelPath (ya aplicado)" -ForegroundColor Gray; return }
  $i = $c.IndexOf($Find)
  if ($i -lt 0) { Write-Host "  ! ANCLA no encontrada en ${RelPath}:" -ForegroundColor Yellow
    Write-Host "    $Find" -ForegroundColor Yellow
    Write-Host "    -> pegame el archivo actual y ajusto el ancla" -ForegroundColor Yellow; return }
  Copy-Item $full "$full.bak" -Force
  $new = $c.Substring(0, $i) + $Replace + $c.Substring($i + $Find.Length)
  [System.IO.File]::WriteAllText($full, $new, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "  ~ $RelPath" -ForegroundColor Green
}

# 1) Celda del canal por encima de todo (bloques + linea de ahora)
Edit-Replace 'src/components/tv/EpgTimeline.tsx' `
  '"group sticky left-0 z-20 flex shrink-0 cursor-pointer items-center gap-2 border-r border-[#22304a] px-2",' `
  '"group sticky left-0 z-30 flex shrink-0 cursor-pointer items-center gap-2 border-r border-[#22304a] px-2",' `
  'z-30 flex shrink-0 cursor-pointer'

# 2) Fondo OPACO en la fila seleccionada (antes sb-row-on era semitransparente)
Edit-Replace 'src/components/tv/EpgTimeline.tsx' `
  'on ? "sb-row-on" : "bg-[#0d1320] hover:bg-[#141d2e]"' `
  'on ? "bg-[#16233f] shadow-[inset_0_0_0_2px_#4c8dff]" : "bg-[#0d1320] hover:bg-[#141d2e]"' `
  'inset_0_0_0_2px_#4c8dff'

Write-Host ""
Write-Host "Listo. Verifica:" -ForegroundColor Green
Write-Host "  npm run build" -ForegroundColor White
Write-Host "  npm start   -> TV en vivo -> selecciona un canal -> scroll horizontal" -ForegroundColor White