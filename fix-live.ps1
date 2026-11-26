<#
  StreamBox - fix-live.ps1  (diagnostico de canales en vivo)
  - El error del reproductor lista el motivo de CADA fuente probada
  - HLS muestra el codigo HTTP del servidor
  - El proxy registra en la terminal las respuestas 4xx/5xx de los streams (credenciales ocultas)
  Uso (raiz del repo):  powershell -ExecutionPolicy Bypass -File .\fix-live.ps1
  Guarda copia .bak de lo que cambia. No requiere npm install.
#>
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "src\components\Layout.tsx"))) {
    Write-Host "ERROR: ejecuta esto en la raiz del proyecto." -ForegroundColor Red
    return
}
Write-Host "Aplicando diagnostico en: $root" -ForegroundColor Cyan
$utf8 = New-Object System.Text.UTF8Encoding($false)
$backedUp = @{}
function Norm([string]$s) { return $s.Replace("`r`n", "`n") }

function Write-ProjectFile {
    param([string]$RelPath, [string]$B64)
    $bytes = [Convert]::FromBase64String(($B64 -replace '\s', ''))
    $full = Join-Path $root $RelPath
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (Test-Path $full) {
        $old = [System.IO.File]::ReadAllBytes($full)
        if (-not [System.Linq.Enumerable]::SequenceEqual($old, $bytes)) { Copy-Item $full "$full.bak" -Force }
    }
    [System.IO.File]::WriteAllBytes($full, $bytes)
    Write-Host "  + $RelPath" -ForegroundColor Green
}

function Edit-File {
    param([string]$Rel, [string]$Old, [string]$New, [string]$Marker)
    $full = Join-Path $root $Rel
    if (-not (Test-Path $full)) { Write-Host "  ! No existe $Rel" -ForegroundColor Yellow; return }
    $t = Norm ([System.IO.File]::ReadAllText($full))
    if ($t.Contains($Marker)) { Write-Host "  = ya aplicado ($Marker) en $Rel" -ForegroundColor DarkGray; return }
    $Old = Norm $Old; $New = Norm $New
    if (-not $t.Contains($Old)) { Write-Host "  ! No encontre el texto a cambiar en $Rel (avisame): $Old" -ForegroundColor Yellow; return }
    if (-not $backedUp.ContainsKey($full)) { Copy-Item $full "$full.bak" -Force; $backedUp[$full] = $true }
    $i = $t.IndexOf($Old)
    $t = $t.Substring(0, $i) + $New + $t.Substring($i + $Old.Length)
    [System.IO.File]::WriteAllText($full, $t, $utf8)
    Write-Host "  + $Rel" -ForegroundColor Green
}

Edit-File 'server/index.js' @'
const code = upRes.statusCode || 200;
'@ @'
const code = upRes.statusCode || 200;
          if (kind === "stream" && (code >= 400 || code < 200)) console.warn("[proxy] stream HTTP", code, parsed.host + parsed.pathname.replace(/\/[^/]+\/[^/]+\/(\d+)/, "/***/***/$1"));
'@ '[proxy] stream HTTP'

Edit-File 'src/hooks/usePlayer.ts' @'
const failFinal = (msg: string) => {
'@ @'
const failures: string[] = [];
    const failFinal = (msg: string) => {
'@ 'const failures'

Edit-File 'src/hooks/usePlayer.ts' @'
setState((s) => ({ ...s, error: msg + tried, loading: false, stalled: false }));
'@ @'
setState((s) => ({ ...s, error: failures.length > 1 ? failures.join("\n") : msg + tried, loading: false, stalled: false }));
'@ 'failures.length > 1'

Edit-File 'src/hooks/usePlayer.ts' @'
if (idx + 1 < candidates.length) { idx++; void start(); }
'@ @'
failures.push(`${idx + 1}. ${detectKind(candidates[idx])}: ${msg}`);
      if (idx + 1 < candidates.length) { idx++; void start(); }
'@ 'failures.push'

Edit-File 'src/hooks/usePlayer.ts' @'
} else next(`HLS: ${data.details}`);
'@ @'
} else next(`HLS: ${data.details}${data.response?.code ? ` (HTTP ${data.response.code})` : ""}`);
'@ 'data.response?.code'

Edit-File 'src/components/Player.tsx' @'
<p className="max-w-md text-sm text-ink">{state.error}</p>
'@ @'
<p className="max-w-md whitespace-pre-line text-sm text-ink">{state.error}</p>
'@ 'whitespace-pre-line'

Write-Host ""
Write-Host "Listo. Reinicia (Ctrl+C y npm start), abre un canal en vivo y pasame el error y la linea [proxy] de la terminal." -ForegroundColor Green