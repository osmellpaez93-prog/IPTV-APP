<#
  StreamBox - fix-merge.ps1
  Despues de aplicar update-zonix-ui.ps1 (Qwen): recupera lo que ese script piso y arregla estilos.
    - Colores/sombras que usan las pantallas anteriores (bg-card, bg-soft, bg-hover, aqua, shadow-card)
    - Carateulas + ficha de pelicula (fase 6), guia EPG (fase 5) y "Continuar viendo"
    - Regla de apertura: si no hay nada sonando abre en TEATRO; si ya suena algo, respeta el modo actual
    - El panel de canales (rail) cambia de canal sin abrir fichas escondidas
  Es seguro repetirlo. Guarda .bak. Todo en UTF-8 sin BOM (no corrompe acentos).
  Uso (raiz del repo):  powershell -ExecutionPolicy Bypass -File .\fix-merge.ps1
#>
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "src\components\PlayerDock.tsx"))) {
    Write-Host "Primero aplica update-zonix-ui.ps1 (no encuentro PlayerDock.tsx)." -ForegroundColor Red
    return
}
Write-Host "Fusionando en: $root" -ForegroundColor Cyan
$utf8 = New-Object System.Text.UTF8Encoding($false)
$backedUp = @{}
function Norm([string]$s) { return $s.Replace("`r`n", "`n") }
function Has([string]$rel) { return (Test-Path (Join-Path $root $rel)) }

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
    Write-Host "  + $RelPath (reescrito)" -ForegroundColor Green
}

function Edit-File {
    param([string]$Rel, [string]$Old, [string]$New, [string]$Marker)
    $full = Join-Path $root $Rel
    if (-not (Test-Path $full)) { Write-Host "  ! No existe $Rel" -ForegroundColor Yellow; return }
    $t = Norm ([System.IO.File]::ReadAllText($full, $utf8))
    if ($t.Contains($Marker)) { Write-Host "  = ya aplicado en $Rel" -ForegroundColor DarkGray; return }
    $Old = Norm $Old; $New = Norm $New
    if (-not $t.Contains($Old)) { Write-Host "  ! No encontre el texto en $Rel (avisame): $Old" -ForegroundColor Yellow; return }
    if (-not $backedUp.ContainsKey($full)) { Copy-Item $full "$full.bak" -Force; $backedUp[$full] = $true }
    $i = $t.IndexOf($Old)
    $t = $t.Substring(0, $i) + $New + $t.Substring($i + $Old.Length)
    [System.IO.File]::WriteAllText($full, $t, $utf8)
    Write-Host "  + $Rel" -ForegroundColor Green
}

# ---- 1) Colores y sombras que usan las pantallas anteriores
Edit-File 'tailwind.config.js' @'
raised: "#18233c",
'@ @'
raised: "#18233c",
          soft: "#111a2e",
          card: "#111a2e",
          hover: "#18233c",
'@ 'card: "#111a2e"'
Edit-File 'tailwind.config.js' @'
signal: { DEFAULT: "#22d3ee", soft: "#7ee7f7", deep: "#0e7490" },
'@ @'
signal: { DEFAULT: "#22d3ee", soft: "#7ee7f7", deep: "#0e7490" },
        aqua: { DEFAULT: "#22d3ee", soft: "#7ee7f7" },
'@ 'aqua: { DEFAULT'
Edit-File 'tailwind.config.js' @'
dock: "0 24px 60px -18px rgba(0,0,0,.9), 0 0 0 1px rgba(38,49,79,.9)",
'@ @'
dock: "0 24px 60px -18px rgba(0,0,0,.9), 0 0 0 1px rgba(38,49,79,.9)",
        card: "0 10px 30px -12px rgba(0,0,0,.85)",
'@ 'card: "0 10px 30px'

# ---- 2) Estado: recupera ficha de pelicula y reproduccion directa
Write-ProjectFile 'src/store/index.ts' @'
aW1wb3J0IHsgY3JlYXRlIH0gZnJvbSAienVzdGFuZCI7CmltcG9ydCB7IHBlcnNpc3QgfSBmcm9tICJ6dXN0YW5kL21pZGRsZXdh
cmUiOwppbXBvcnQgdHlwZSB7IENoYW5uZWwgfSBmcm9tICIuLi90eXBlcyI7CgpleHBvcnQgdHlwZSBWaWV3TW9kZSA9ICJtaW5p
IiB8ICJ0aGVhdGVyIiB8ICJmdWxsIjsKZXhwb3J0IHR5cGUgTWluaVNpemUgPSAicyIgfCAibSIgfCAibCI7CmV4cG9ydCB0eXBl
IENvcm5lciA9ICJ0bCIgfCAidHIiIHwgImJsIiB8ICJiciI7CmV4cG9ydCB0eXBlIERlbnNpdHkgPSAiY29tcGFjdCIgfCAibm9y
bWFsIiB8ICJjb21meSI7CmV4cG9ydCB0eXBlIEFzcGVjdCA9ICJjb250YWluIiB8ICJjb3ZlciIgfCAiZmlsbCI7CmV4cG9ydCB0
eXBlIEFjY2VudCA9ICJzaWduYWwiIHwgImJyYW5kIiB8ICJnb2xkIiB8ICJpcmlzIiB8ICJsaW1lIjsKCmV4cG9ydCBpbnRlcmZh
Y2UgTWluaVByZWZzIHsgc2l6ZTogTWluaVNpemU7IGNvcm5lcjogQ29ybmVyOyBvcGFjaXR5OiBudW1iZXIgfQpleHBvcnQgaW50
ZXJmYWNlIFVJUHJlZnMgewogIHNjYWxlOiBudW1iZXI7CiAgZGVuc2l0eTogRGVuc2l0eTsKICBjb2x1bW5zOiAwIHwgMSB8IDIg
fCAzOwogIHBvc3RlclNjYWxlOiBudW1iZXI7CiAgYWNjZW50OiBBY2NlbnQ7CiAgaGlkZGVuR3JvdXBzOiBzdHJpbmdbXTsKfQpl
eHBvcnQgaW50ZXJmYWNlIFZpZGVvUHJlZnMgeyBicmlnaHRuZXNzOiBudW1iZXI7IGNvbnRyYXN0OiBudW1iZXI7IHNhdHVyYXRl
OiBudW1iZXI7IHpvb206IG51bWJlcjsgYXNwZWN0OiBBc3BlY3QgfQoKZXhwb3J0IGNvbnN0IERFRkFVTFRfVUk6IFVJUHJlZnMg
PSB7IHNjYWxlOiAxLCBkZW5zaXR5OiAibm9ybWFsIiwgY29sdW1uczogMCwgcG9zdGVyU2NhbGU6IDEsIGFjY2VudDogInNpZ25h
bCIsIGhpZGRlbkdyb3VwczogW10gfTsKZXhwb3J0IGNvbnN0IERFRkFVTFRfVklERU86IFZpZGVvUHJlZnMgPSB7IGJyaWdodG5l
c3M6IDEwMCwgY29udHJhc3Q6IDEwMCwgc2F0dXJhdGU6IDEwMCwgem9vbTogMTAwLCBhc3BlY3Q6ICJjb250YWluIiB9OwpleHBv
cnQgY29uc3QgREVGQVVMVF9NSU5JOiBNaW5pUHJlZnMgPSB7IHNpemU6ICJtIiwgY29ybmVyOiAiYnIiLCBvcGFjaXR5OiAxMDAg
fTsKCmV4cG9ydCBjb25zdCBBQ0NFTlRTOiBSZWNvcmQ8QWNjZW50LCB7IGhleDogc3RyaW5nOyBzb2Z0OiBzdHJpbmc7IGxhYmVs
OiBzdHJpbmcgfT4gPSB7CiAgc2lnbmFsOiB7IGhleDogIiMyMmQzZWUiLCBzb2Z0OiAiIzdlZTdmNyIsIGxhYmVsOiAiQ2lhbiIg
fSwKICBicmFuZDogeyBoZXg6ICIjZTUwOTE0Iiwgc29mdDogIiNmZjZiNzAiLCBsYWJlbDogIlJvam8iIH0sCiAgZ29sZDogeyBo
ZXg6ICIjZmZiMDIwIiwgc29mdDogIiNmZmQyN2EiLCBsYWJlbDogIkFtYmFyIiB9LAogIGlyaXM6IHsgaGV4OiAiIzhiNWNmNiIs
IHNvZnQ6ICIjYjc5YmZmIiwgbGFiZWw6ICJWaW9sZXRhIiB9LAogIGxpbWU6IHsgaGV4OiAiI2EzZTYzNSIsIHNvZnQ6ICIjZDBm
NThhIiwgbGFiZWw6ICJMaW1hIiB9LAp9OwoKZXhwb3J0IGNvbnN0IFJPV19IRUlHSFQ6IFJlY29yZDxEZW5zaXR5LCBudW1iZXI+
ID0geyBjb21wYWN0OiA1Niwgbm9ybWFsOiA3MiwgY29tZnk6IDkyIH07Cgpjb25zdCBUSEVBVEVSOiBWaWV3TW9kZSA9ICJ0aGVh
dGVyIjsKY29uc3QgTUlOSTogVmlld01vZGUgPSAibWluaSI7CgppbnRlcmZhY2UgVUlTdGF0ZSB7CiAgc2lkZWJhck9wZW46IGJv
b2xlYW47CiAgc2V0U2lkZWJhck9wZW46ICh2OiBib29sZWFuKSA9PiB2b2lkOwogIHRvZ2dsZVNpZGViYXI6ICgpID0+IHZvaWQ7
CgogIGFjdGl2ZVBsYXlsaXN0SWQ6IHN0cmluZyB8IG51bGw7CiAgc2V0QWN0aXZlUGxheWxpc3RJZDogKGlkOiBzdHJpbmcgfCBu
dWxsKSA9PiB2b2lkOwoKICBub3dQbGF5aW5nOiBDaGFubmVsIHwgbnVsbDsKICBxdWV1ZTogQ2hhbm5lbFtdOwogIC8qKiBTZXJp
ZXMgLT4gZGV0YWxsZSBkZSBzZXJpZSwgcGVsaWN1bGFzIC0+IGZpY2hhLCByZXN0byAtPiByZXByb2R1Y2UuICovCiAgc2V0Tm93
UGxheWluZzogKGM6IENoYW5uZWwgfCBudWxsKSA9PiB2b2lkOwogIHBsYXk6IChjOiBDaGFubmVsLCBsaXN0PzogQ2hhbm5lbFtd
KSA9PiB2b2lkOwogIC8qKiBSZXByb2R1Y2UgZGlyZWN0YW1lbnRlIChib3RvbiBSZXByb2R1Y2lyIGRlIGxhIGZpY2hhLCBjb250
aW51YXIgdmllbmRvLCBwYW5lbCBkZSBjYW5hbGVzKS4gKi8KICBwbGF5Tm93OiAoYzogQ2hhbm5lbCwgbGlzdD86IENoYW5uZWxb
XSkgPT4gdm9pZDsKICBzZXRRdWV1ZTogKGxpc3Q6IENoYW5uZWxbXSkgPT4gdm9pZDsKICB6YXA6IChkZWx0YTogbnVtYmVyKSA9
PiB2b2lkOwogIHphcFRvOiAoaW5kZXg6IG51bWJlcikgPT4gdm9pZDsKCiAgb3BlblNlcmllczogQ2hhbm5lbCB8IG51bGw7CiAg
Y2xvc2VTZXJpZXM6ICgpID0+IHZvaWQ7CiAgb3Blbk1vdmllOiBDaGFubmVsIHwgbnVsbDsKICBjbG9zZU1vdmllOiAoKSA9PiB2
b2lkOwoKICB2aWV3TW9kZTogVmlld01vZGU7CiAgc2V0Vmlld01vZGU6IChtOiBWaWV3TW9kZSkgPT4gdm9pZDsKICBtaW5pOiBN
aW5pUHJlZnM7CiAgc2V0TWluaTogKHBhdGNoOiBQYXJ0aWFsPE1pbmlQcmVmcz4pID0+IHZvaWQ7CgogIG11bHRpdmlldzogQ2hh
bm5lbFtdOwogIG12QWN0aXZlOiBudW1iZXI7CiAgYWRkTXVsdGl2aWV3OiAoYzogQ2hhbm5lbCkgPT4gdm9pZDsKICByZW1vdmVN
dWx0aXZpZXc6IChpbmRleDogbnVtYmVyKSA9PiB2b2lkOwogIHNldE12QWN0aXZlOiAoaW5kZXg6IG51bWJlcikgPT4gdm9pZDsK
ICBjbGVhck11bHRpdmlldzogKCkgPT4gdm9pZDsKCiAgdWk6IFVJUHJlZnM7CiAgc2V0VUk6IChwYXRjaDogUGFydGlhbDxVSVBy
ZWZzPikgPT4gdm9pZDsKICB0b2dnbGVHcm91cDogKGdyb3VwOiBzdHJpbmcpID0+IHZvaWQ7CiAgcmVzZXRVSTogKCkgPT4gdm9p
ZDsKCiAgdmlkZW86IFZpZGVvUHJlZnM7CiAgc2V0VmlkZW86IChwYXRjaDogUGFydGlhbDxWaWRlb1ByZWZzPikgPT4gdm9pZDsK
ICByZXNldFZpZGVvOiAoKSA9PiB2b2lkOwoKICBzZXR0aW5nc09wZW46IGJvb2xlYW47CiAgc2V0U2V0dGluZ3NPcGVuOiAodjog
Ym9vbGVhbikgPT4gdm9pZDsKfQoKZXhwb3J0IGNvbnN0IHVzZVN0b3JlID0gY3JlYXRlPFVJU3RhdGU+KCkoCiAgcGVyc2lzdCgK
ICAgIChzZXQsIGdldCkgPT4gKHsKICAgICAgc2lkZWJhck9wZW46IGZhbHNlLAogICAgICBzZXRTaWRlYmFyT3BlbjogKHYpID0+
IHNldCh7IHNpZGViYXJPcGVuOiB2IH0pLAogICAgICB0b2dnbGVTaWRlYmFyOiAoKSA9PiBzZXQoKHMpID0+ICh7IHNpZGViYXJP
cGVuOiAhcy5zaWRlYmFyT3BlbiB9KSksCgogICAgICBhY3RpdmVQbGF5bGlzdElkOiBudWxsLAogICAgICBzZXRBY3RpdmVQbGF5
bGlzdElkOiAoaWQpID0+IHNldCh7IGFjdGl2ZVBsYXlsaXN0SWQ6IGlkIH0pLAoKICAgICAgbm93UGxheWluZzogbnVsbCwKICAg
ICAgcXVldWU6IFtdLAoKICAgICAgLy8gUmVnbGEgZGUgdmlzdGE6IHNpIG5vIGhhYmlhIG5hZGEgc29uYW5kbywgYWJyZSBlbiBU
RUFUUk87IHNpIHlhIGhhYmlhIGFsZ28sIHJlc3BldGEgZWwgbW9kbyBhY3R1YWwuCiAgICAgIHNldE5vd1BsYXlpbmc6IChjKSA9
PgogICAgICAgIHNldCgocykgPT4gewogICAgICAgICAgaWYgKCFjKSByZXR1cm4geyBub3dQbGF5aW5nOiBudWxsLCB2aWV3TW9k
ZTogTUlOSSB9OwogICAgICAgICAgaWYgKGMuc2VyaWVzSWQpIHJldHVybiB7IG9wZW5TZXJpZXM6IGMgfTsKICAgICAgICAgIGlm
IChjLmNhdGVnb3J5ID09PSAibW92aWVzIikgcmV0dXJuIHsgb3Blbk1vdmllOiBjIH07CiAgICAgICAgICBjb25zdCBpblF1ZXVl
ID0gcy5xdWV1ZS5zb21lKCh4KSA9PiB4LmlkID09PSBjLmlkKTsKICAgICAgICAgIHJldHVybiB7IG5vd1BsYXlpbmc6IGMsIHF1
ZXVlOiBpblF1ZXVlID8gcy5xdWV1ZSA6IFtjXSwgdmlld01vZGU6IHMubm93UGxheWluZyA/IHMudmlld01vZGUgOiBUSEVBVEVS
IH07CiAgICAgICAgfSksCgogICAgICBwbGF5OiAoYywgbGlzdCkgPT4KICAgICAgICBzZXQoKHMpID0+IHsKICAgICAgICAgIGlm
IChjLnNlcmllc0lkKSByZXR1cm4geyBvcGVuU2VyaWVzOiBjIH07CiAgICAgICAgICBpZiAoYy5jYXRlZ29yeSA9PT0gIm1vdmll
cyIpIHJldHVybiB7IG9wZW5Nb3ZpZTogYyB9OwogICAgICAgICAgcmV0dXJuIHsKICAgICAgICAgICAgbm93UGxheWluZzogYywK
ICAgICAgICAgICAgcXVldWU6IGxpc3QgJiYgbGlzdC5sZW5ndGggPyBsaXN0IDogW2NdLAogICAgICAgICAgICB2aWV3TW9kZTog
cy5ub3dQbGF5aW5nID8gcy52aWV3TW9kZSA6IFRIRUFURVIsCiAgICAgICAgICB9OwogICAgICAgIH0pLAoKICAgICAgcGxheU5v
dzogKGMsIGxpc3QpID0+CiAgICAgICAgc2V0KChzKSA9PiAoewogICAgICAgICAgbm93UGxheWluZzogYywKICAgICAgICAgIHF1
ZXVlOiBsaXN0ICYmIGxpc3QubGVuZ3RoID8gbGlzdCA6IFtjXSwKICAgICAgICAgIG9wZW5Nb3ZpZTogbnVsbCwKICAgICAgICAg
IG9wZW5TZXJpZXM6IG51bGwsCiAgICAgICAgICB2aWV3TW9kZTogcy5ub3dQbGF5aW5nID8gcy52aWV3TW9kZSA6IFRIRUFURVIs
CiAgICAgICAgfSkpLAoKICAgICAgc2V0UXVldWU6IChsaXN0KSA9PiBzZXQoeyBxdWV1ZTogbGlzdCB9KSwKICAgICAgemFwOiAo
ZGVsdGEpID0+IHsKICAgICAgICBjb25zdCB7IHF1ZXVlLCBub3dQbGF5aW5nIH0gPSBnZXQoKTsKICAgICAgICBpZiAoIW5vd1Bs
YXlpbmcgfHwgcXVldWUubGVuZ3RoIDwgMikgcmV0dXJuOwogICAgICAgIGNvbnN0IGkgPSBxdWV1ZS5maW5kSW5kZXgoKHgpID0+
IHguaWQgPT09IG5vd1BsYXlpbmcuaWQpOwogICAgICAgIGlmIChpIDwgMCkgcmV0dXJuOwogICAgICAgIHNldCh7IG5vd1BsYXlp
bmc6IHF1ZXVlWyhpICsgZGVsdGEgKyBxdWV1ZS5sZW5ndGgpICUgcXVldWUubGVuZ3RoXSB9KTsKICAgICAgfSwKICAgICAgemFw
VG86IChpbmRleCkgPT4gewogICAgICAgIGNvbnN0IHsgcXVldWUgfSA9IGdldCgpOwogICAgICAgIGlmIChpbmRleCA+PSAwICYm
IGluZGV4IDwgcXVldWUubGVuZ3RoKSBzZXQoeyBub3dQbGF5aW5nOiBxdWV1ZVtpbmRleF0gfSk7CiAgICAgIH0sCgogICAgICBv
cGVuU2VyaWVzOiBudWxsLAogICAgICBjbG9zZVNlcmllczogKCkgPT4gc2V0KHsgb3BlblNlcmllczogbnVsbCB9KSwKICAgICAg
b3Blbk1vdmllOiBudWxsLAogICAgICBjbG9zZU1vdmllOiAoKSA9PiBzZXQoeyBvcGVuTW92aWU6IG51bGwgfSksCgogICAgICB2
aWV3TW9kZTogTUlOSSwKICAgICAgc2V0Vmlld01vZGU6IChtKSA9PiBzZXQoeyB2aWV3TW9kZTogbSB9KSwKICAgICAgbWluaTog
REVGQVVMVF9NSU5JLAogICAgICBzZXRNaW5pOiAocGF0Y2gpID0+IHNldCgocykgPT4gKHsgbWluaTogeyAuLi5zLm1pbmksIC4u
LnBhdGNoIH0gfSkpLAoKICAgICAgbXVsdGl2aWV3OiBbXSwKICAgICAgbXZBY3RpdmU6IDAsCiAgICAgIGFkZE11bHRpdmlldzog
KGMpID0+CiAgICAgICAgc2V0KChzKSA9PiB7CiAgICAgICAgICBpZiAocy5tdWx0aXZpZXcubGVuZ3RoID49IDQgfHwgcy5tdWx0
aXZpZXcuc29tZSgoeCkgPT4geC5pZCA9PT0gYy5pZCkpIHJldHVybiB7fTsKICAgICAgICAgIGNvbnN0IG5leHQgPSBbLi4ucy5t
dWx0aXZpZXcsIGNdOwogICAgICAgICAgcmV0dXJuIHsgbXVsdGl2aWV3OiBuZXh0LCBtdkFjdGl2ZTogbmV4dC5sZW5ndGggLSAx
LCBub3dQbGF5aW5nOiBudWxsIH07CiAgICAgICAgfSksCiAgICAgIHJlbW92ZU11bHRpdmlldzogKGluZGV4KSA9PgogICAgICAg
IHNldCgocykgPT4gewogICAgICAgICAgY29uc3QgbmV4dCA9IHMubXVsdGl2aWV3LmZpbHRlcigoXywgaSkgPT4gaSAhPT0gaW5k
ZXgpOwogICAgICAgICAgcmV0dXJuIHsgbXVsdGl2aWV3OiBuZXh0LCBtdkFjdGl2ZTogTWF0aC5tYXgoMCwgTWF0aC5taW4ocy5t
dkFjdGl2ZSwgbmV4dC5sZW5ndGggLSAxKSkgfTsKICAgICAgICB9KSwKICAgICAgc2V0TXZBY3RpdmU6IChpbmRleCkgPT4gc2V0
KHsgbXZBY3RpdmU6IGluZGV4IH0pLAogICAgICBjbGVhck11bHRpdmlldzogKCkgPT4gc2V0KHsgbXVsdGl2aWV3OiBbXSwgbXZB
Y3RpdmU6IDAgfSksCgogICAgICB1aTogREVGQVVMVF9VSSwKICAgICAgc2V0VUk6IChwYXRjaCkgPT4gc2V0KChzKSA9PiAoeyB1
aTogeyAuLi5zLnVpLCAuLi5wYXRjaCB9IH0pKSwKICAgICAgdG9nZ2xlR3JvdXA6IChncm91cCkgPT4KICAgICAgICBzZXQoKHMp
ID0+ICh7CiAgICAgICAgICB1aTogewogICAgICAgICAgICAuLi5zLnVpLAogICAgICAgICAgICBoaWRkZW5Hcm91cHM6IHMudWku
aGlkZGVuR3JvdXBzLmluY2x1ZGVzKGdyb3VwKQogICAgICAgICAgICAgID8gcy51aS5oaWRkZW5Hcm91cHMuZmlsdGVyKChnKSA9
PiBnICE9PSBncm91cCkKICAgICAgICAgICAgICA6IFsuLi5zLnVpLmhpZGRlbkdyb3VwcywgZ3JvdXBdLAogICAgICAgICAgfSwK
ICAgICAgICB9KSksCiAgICAgIHJlc2V0VUk6ICgpID0+IHNldCh7IHVpOiBERUZBVUxUX1VJLCBtaW5pOiBERUZBVUxUX01JTkkg
fSksCgogICAgICB2aWRlbzogREVGQVVMVF9WSURFTywKICAgICAgc2V0VmlkZW86IChwYXRjaCkgPT4gc2V0KChzKSA9PiAoeyB2
aWRlbzogeyAuLi5zLnZpZGVvLCAuLi5wYXRjaCB9IH0pKSwKICAgICAgcmVzZXRWaWRlbzogKCkgPT4gc2V0KHsgdmlkZW86IERF
RkFVTFRfVklERU8gfSksCgogICAgICBzZXR0aW5nc09wZW46IGZhbHNlLAogICAgICBzZXRTZXR0aW5nc09wZW46ICh2KSA9PiBz
ZXQoeyBzZXR0aW5nc09wZW46IHYgfSksCiAgICB9KSwKICAgIHsKICAgICAgbmFtZTogInN0cmVhbWJveC11aSIsCiAgICAgIHBh
cnRpYWxpemU6IChzKSA9PiAoeyBhY3RpdmVQbGF5bGlzdElkOiBzLmFjdGl2ZVBsYXlsaXN0SWQsIHVpOiBzLnVpLCBtaW5pOiBz
Lm1pbmksIHZpZGVvOiBzLnZpZGVvIH0pLAogICAgfQogICkKKTsK
'@

# ---- 3) Peliculas y series con caratulas + ficha
if (Has 'src\components\PosterGrid.tsx') {
Write-ProjectFile 'src/pages/CategoryPage.tsx' @'
aW1wb3J0IHsgdXNlQ2FsbGJhY2ssIHVzZURlZmVycmVkVmFsdWUsIHVzZU1lbW8sIHVzZVN0YXRlIH0gZnJvbSAicmVhY3QiOwpp
bXBvcnQgeyBMaW5rIH0gZnJvbSAicmVhY3Qtcm91dGVyLWRvbSI7CmltcG9ydCB7IHVzZUxpdmVRdWVyeSB9IGZyb20gImRleGll
LXJlYWN0LWhvb2tzIjsKaW1wb3J0IHsgU2VhcmNoIH0gZnJvbSAibHVjaWRlLXJlYWN0IjsKaW1wb3J0IHsgZGIgfSBmcm9tICIu
Li9kYiI7CmltcG9ydCB7IHVzZVN0b3JlIH0gZnJvbSAiLi4vc3RvcmUiOwppbXBvcnQgeyB1c2VGYXZvcml0ZXMgfSBmcm9tICIu
Li9ob29rcy91c2VGYXZvcml0ZXMiOwppbXBvcnQgeyBDaGFubmVsR3JpZCB9IGZyb20gIi4uL2NvbXBvbmVudHMvQ2hhbm5lbEdy
aWQiOwppbXBvcnQgeyBQb3N0ZXJHcmlkIH0gZnJvbSAiLi4vY29tcG9uZW50cy9Qb3N0ZXJHcmlkIjsKaW1wb3J0IHsgQ2hhbm5l
bENhcmRTa2VsZXRvbiB9IGZyb20gIi4uL2NvbXBvbmVudHMvU2tlbGV0b25Mb2FkZXIiOwppbXBvcnQgdHlwZSB7IENoYW5uZWwg
fSBmcm9tICIuLi90eXBlcyI7CgppbnRlcmZhY2UgUHJvcHMgewogIGNhdGVnb3J5OiBDaGFubmVsWyJjYXRlZ29yeSJdOwogIHRp
dGxlOiBzdHJpbmc7CiAgcGxhY2Vob2xkZXI6IHN0cmluZzsKICBub3VuOiBzdHJpbmc7Cn0KCmV4cG9ydCBmdW5jdGlvbiBDYXRl
Z29yeVBhZ2UoeyBjYXRlZ29yeSwgdGl0bGUsIHBsYWNlaG9sZGVyLCBub3VuIH06IFByb3BzKSB7CiAgY29uc3QgYWN0aXZlUGxh
eWxpc3RJZCA9IHVzZVN0b3JlKChzKSA9PiBzLmFjdGl2ZVBsYXlsaXN0SWQpOwogIGNvbnN0IHBsYXkgPSB1c2VTdG9yZSgocykg
PT4gcy5wbGF5KTsKICBjb25zdCBoaWRkZW5Hcm91cHMgPSB1c2VTdG9yZSgocykgPT4gcy51aS5oaWRkZW5Hcm91cHMpOwogIGNv
bnN0IHsgZmF2U2V0LCB0b2dnbGUgfSA9IHVzZUZhdm9yaXRlcygpOwogIGNvbnN0IFtncm91cCwgc2V0R3JvdXBdID0gdXNlU3Rh
dGUoIlRvZGFzIik7CiAgY29uc3QgW3F1ZXJ5LCBzZXRRdWVyeV0gPSB1c2VTdGF0ZSgiIik7CiAgY29uc3QgZGVmZXJyZWRRdWVy
eSA9IHVzZURlZmVycmVkVmFsdWUocXVlcnkpOwoKICBjb25zdCBpdGVtcyA9IHVzZUxpdmVRdWVyeSgKICAgICgpID0+CiAgICAg
IGFjdGl2ZVBsYXlsaXN0SWQKICAgICAgICA/IGRiLmNoYW5uZWxzLndoZXJlKCJbcGxheWxpc3RJZCtjYXRlZ29yeV0iKS5lcXVh
bHMoW2FjdGl2ZVBsYXlsaXN0SWQsIGNhdGVnb3J5XSkudG9BcnJheSgpCiAgICAgICAgOiBQcm9taXNlLnJlc29sdmUoW10gYXMg
Q2hhbm5lbFtdKSwKICAgIFthY3RpdmVQbGF5bGlzdElkLCBjYXRlZ29yeV0KICApOwoKICBjb25zdCBncm91cHMgPSB1c2VNZW1v
KAogICAgKCkgPT4KICAgICAgQXJyYXkuZnJvbShuZXcgU2V0KChpdGVtcyA/PyBbXSkubWFwKChjKSA9PiBjLmdyb3VwIHx8ICJT
aW4gY2F0ZWdvcsOtYSIpKSkKICAgICAgICAuZmlsdGVyKChnKSA9PiAhaGlkZGVuR3JvdXBzLmluY2x1ZGVzKGcpKQogICAgICAg
IC5zb3J0KChhLCBiKSA9PiBhLmxvY2FsZUNvbXBhcmUoYikpLAogICAgW2l0ZW1zLCBoaWRkZW5Hcm91cHNdCiAgKTsKICBjb25z
dCBhY3RpdmVHcm91cCA9IGdyb3Vwcy5pbmNsdWRlcyhncm91cCkgPyBncm91cCA6ICJUb2RhcyI7CgogIGNvbnN0IGZpbHRlcmVk
ID0gdXNlTWVtbygoKSA9PiB7CiAgICBjb25zdCBxID0gZGVmZXJyZWRRdWVyeS50cmltKCkudG9Mb3dlckNhc2UoKTsKICAgIHJl
dHVybiAoaXRlbXMgPz8gW10pLmZpbHRlcigKICAgICAgKGMpID0+CiAgICAgICAgIWhpZGRlbkdyb3Vwcy5pbmNsdWRlcyhjLmdy
b3VwIHx8ICJTaW4gY2F0ZWdvcsOtYSIpICYmCiAgICAgICAgKGFjdGl2ZUdyb3VwID09PSAiVG9kYXMiIHx8IChjLmdyb3VwIHx8
ICJTaW4gY2F0ZWdvcsOtYSIpID09PSBhY3RpdmVHcm91cCkgJiYKICAgICAgICAoIXEgfHwgYy5uYW1lLnRvTG93ZXJDYXNlKCku
aW5jbHVkZXMocSkpCiAgICApOwogIH0sIFtpdGVtcywgYWN0aXZlR3JvdXAsIGRlZmVycmVkUXVlcnksIGhpZGRlbkdyb3Vwc10p
OwoKICBjb25zdCBvblBsYXkgPSB1c2VDYWxsYmFjaygoYzogQ2hhbm5lbCkgPT4gcGxheShjLCBmaWx0ZXJlZCksIFtwbGF5LCBm
aWx0ZXJlZF0pOwoKICBpZiAoIWFjdGl2ZVBsYXlsaXN0SWQpIHsKICAgIHJldHVybiAoCiAgICAgIDxkaXYgY2xhc3NOYW1lPSJw
eS0yMCB0ZXh0LWNlbnRlciB0ZXh0LWluay1tdXRlZCI+CiAgICAgICAgPHAgY2xhc3NOYW1lPSJtYi0yIj5ObyBoYXkgbmluZ3Vu
YSBsaXN0YSBjYXJnYWRhLjwvcD4KICAgICAgICA8TGluayB0bz0iL3BsYXlsaXN0cyIgY2xhc3NOYW1lPSJ0ZXh0LXNpZ25hbCBo
b3Zlcjp1bmRlcmxpbmUiPklyIGEgTWlzIGxpc3RhczwvTGluaz4KICAgICAgPC9kaXY+CiAgICApOwogIH0KCiAgY29uc3QgcG9z
dGVyID0gY2F0ZWdvcnkgPT09ICJtb3ZpZXMiIHx8IGNhdGVnb3J5ID09PSAic2VyaWVzIjsKCiAgcmV0dXJuICgKICAgIDxkaXYg
Y2xhc3NOYW1lPSJhbmltYXRlLWZhZGUtaW4gc3BhY2UteS01Ij4KICAgICAgPGRpdj4KICAgICAgICA8aDEgY2xhc3NOYW1lPSJ0
ZXh0LTJ4bCBmb250LWJvbGQgbWQ6dGV4dC0zeGwiPnt0aXRsZX08L2gxPgogICAgICAgIDxwIGNsYXNzTmFtZT0ibXQtMSB0ZXh0
LWluay1tdXRlZCI+e2l0ZW1zID8gYCR7ZmlsdGVyZWQubGVuZ3RoLnRvTG9jYWxlU3RyaW5nKCl9ICR7bm91bn1gIDogIkNhcmdh
bmRv4oCmIn08L3A+CiAgICAgIDwvZGl2PgoKICAgICAgPGRpdiBjbGFzc05hbWU9ImZsZXggZmxleC1jb2wgZ2FwLTMgbWQ6Zmxl
eC1yb3ciPgogICAgICAgIDxkaXYgY2xhc3NOYW1lPSJyZWxhdGl2ZSBmbGV4LTEiPgogICAgICAgICAgPFNlYXJjaCBjbGFzc05h
bWU9ImFic29sdXRlIGxlZnQtMyB0b3AtMS8yIGgtNCB3LTQgLXRyYW5zbGF0ZS15LTEvMiB0ZXh0LWluay1kaW0iIC8+CiAgICAg
ICAgICA8aW5wdXQKICAgICAgICAgICAgdmFsdWU9e3F1ZXJ5fQogICAgICAgICAgICBvbkNoYW5nZT17KGUpID0+IHNldFF1ZXJ5
KGUudGFyZ2V0LnZhbHVlKX0KICAgICAgICAgICAgcGxhY2Vob2xkZXI9e3BsYWNlaG9sZGVyfQogICAgICAgICAgICBjbGFzc05h
bWU9InctZnVsbCByb3VuZGVkLWxnIGJvcmRlciBib3JkZXItYmctbGluZSBiZy1iZy1zdXJmYWNlIHB5LTIgcGwtOSBwci0zIGZv
Y3VzOmJvcmRlci1zaWduYWwgZm9jdXM6b3V0bGluZS1ub25lIgogICAgICAgICAgLz4KICAgICAgICA8L2Rpdj4KICAgICAgICA8
c2VsZWN0CiAgICAgICAgICB2YWx1ZT17YWN0aXZlR3JvdXB9CiAgICAgICAgICBvbkNoYW5nZT17KGUpID0+IHNldEdyb3VwKGUu
dGFyZ2V0LnZhbHVlKX0KICAgICAgICAgIGNsYXNzTmFtZT0icm91bmRlZC1sZyBib3JkZXIgYm9yZGVyLWJnLWxpbmUgYmctYmct
c3VyZmFjZSBweC0zIHB5LTIgZm9jdXM6Ym9yZGVyLXNpZ25hbCBmb2N1czpvdXRsaW5lLW5vbmUiCiAgICAgICAgPgogICAgICAg
ICAgPG9wdGlvbiB2YWx1ZT0iVG9kYXMiPlRvZGFzIGxhcyBjYXRlZ29yw61hczwvb3B0aW9uPgogICAgICAgICAge2dyb3Vwcy5t
YXAoKGcpID0+IDxvcHRpb24ga2V5PXtnfSB2YWx1ZT17Z30+e2d9PC9vcHRpb24+KX0KICAgICAgICA8L3NlbGVjdD4KICAgICAg
PC9kaXY+CgogICAgICB7IWl0ZW1zID8gKAogICAgICAgIDxkaXYgY2xhc3NOYW1lPSJncmlkIGdhcC0yIG1kOmdyaWQtY29scy0y
Ij57QXJyYXkuZnJvbSh7IGxlbmd0aDogOCB9KS5tYXAoKF8sIGkpID0+IDxDaGFubmVsQ2FyZFNrZWxldG9uIGtleT17aX0gLz4p
fTwvZGl2PgogICAgICApIDogcG9zdGVyID8gKAogICAgICAgIDxQb3N0ZXJHcmlkIGNoYW5uZWxzPXtmaWx0ZXJlZH0gZmF2U2V0
PXtmYXZTZXR9IG9uVG9nZ2xlRmF2b3JpdGU9e3RvZ2dsZX0gb25QbGF5PXtvblBsYXl9IGVtcHR5VGV4dD17YE5vIGhheSAke25v
dW59IGNvbiBlc2UgZmlsdHJvLmB9IC8+CiAgICAgICkgOiAoCiAgICAgICAgPENoYW5uZWxHcmlkIGNoYW5uZWxzPXtmaWx0ZXJl
ZH0gZmF2U2V0PXtmYXZTZXR9IG9uVG9nZ2xlRmF2b3JpdGU9e3RvZ2dsZX0gb25QbGF5PXtvblBsYXl9IGVtcHR5VGV4dD17YE5v
IGhheSAke25vdW59IGNvbiBlc2UgZmlsdHJvLmB9IC8+CiAgICAgICl9CiAgICA8L2Rpdj4KICApOwp9Cg==
'@
} else { Write-Host '  - Sin PosterGrid.tsx (fase 6 no aplicada): se deja CategoryPage de Qwen' -ForegroundColor DarkGray }
if (Has 'src\components\MovieDetail.tsx') {
Edit-File 'src/components/Layout.tsx' @'
import { SeriesDetail } from "./SeriesDetail";
'@ @'
import { SeriesDetail } from "./SeriesDetail";
import { MovieDetail } from "./MovieDetail";
'@ 'import { MovieDetail }'
Edit-File 'src/components/Layout.tsx' @'
const openSeries = useStore((s) => s.openSeries);
'@ @'
const openSeries = useStore((s) => s.openSeries);
  const openMovie = useStore((s) => s.openMovie);
'@ 'const openMovie'
Edit-File 'src/components/Layout.tsx' @'
{...(openSeries ? { "data-nav-lock": "series" } : {})}
'@ @'
{...(openSeries || openMovie ? { "data-nav-lock": "modal" } : {})}
'@ 'openSeries || openMovie'
Edit-File 'src/components/Layout.tsx' @'
<SeriesDetail />
'@ @'
<SeriesDetail />
        <MovieDetail />
'@ '<MovieDetail />'
}

# ---- 4) Continuar viendo y panel de canales
if (Has 'src\components\ContinueWatching.tsx') {
Edit-File 'src/components/ContinueWatching.tsx' @'
const setNowPlaying = useStore((s) => s.setNowPlaying);
'@ @'
const playNow = useStore((s) => s.playNow);
'@ 'const playNow'
Edit-File 'src/components/ContinueWatching.tsx' @'
setNowPlaying(channel);
'@ @'
playNow(channel);
'@ 'playNow(channel)'
Edit-File 'src/pages/Home.tsx' @'
import { imgUrl } from "../services/proxy";
'@ @'
import { imgUrl } from "../services/proxy";
import { ContinueWatching } from "../components/ContinueWatching";
'@ 'import { ContinueWatching }'
Edit-File 'src/pages/Home.tsx' @'
<Row title="Canales en vivo"
'@ @'
<ContinueWatching />

      <Row title="Canales en vivo"
'@ '<ContinueWatching />'
}
Edit-File 'src/components/ChannelRail.tsx' @'
const play = useStore((s) => s.play);
'@ @'
const playNow = useStore((s) => s.playNow);
'@ 'const playNow'
Edit-File 'src/components/ChannelRail.tsx' @'
else play(c, filtered);
'@ @'
else playNow(c, filtered);
'@ 'playNow(c, filtered)'

# ---- 5) Guia de programacion (EPG)
if ((Has 'src\hooks\useEpg.ts') -and (Has 'src\components\Epg.tsx')) {
Edit-File 'src/components/ChannelCard.tsx' @'
import { ROW_HEIGHT, useStore } from "../store";
'@ @'
import { ROW_HEIGHT, useStore } from "../store";
import { useEpg } from "../hooks/useEpg";
'@ 'import { useEpg }'
Edit-File 'src/components/ChannelCard.tsx' @'
const logo = imgUrl(channel.logo);
'@ @'
const logo = imgUrl(channel.logo);
  const { current, now } = useEpg(channel.category === "live" ? channel : null, 400);
  const pct = current ? Math.min(100, Math.max(0, ((now - current.start) / (current.end - current.start)) * 100)) : 0;
'@ 'useEpg(channel.category'
Edit-File 'src/components/ChannelCard.tsx' @'
{channel.group || "Sin categoria"}
'@ @'
{current ? <span className="text-ink">{current.title}</span> : channel.group || "Sin categoria"}
'@ 'current.title'
Edit-File 'src/components/ChannelCard.tsx' @'
{channel.category === "live" && (
'@ @'
{current && (
        <span className="absolute inset-x-0 bottom-0 h-[3px] bg-white/5">
          <span className="block h-full bg-brand/80" style={{ width: `${pct}%` }} />
        </span>
      )}

      {channel.category === "live" && (
'@ 'bg-brand/80'
Edit-File 'src/components/Player.tsx' @'
import { SubtitleDialog } from "./SubtitleDialog";
'@ @'
import { SubtitleDialog } from "./SubtitleDialog";
import { NowNext, EpgPanel, EpgMenuButton } from "./Epg";
'@ 'EpgPanel, EpgMenuButton'
Edit-File 'src/components/Player.tsx' @'
const [subs, setSubs] = useState(false);
'@ @'
const [subs, setSubs] = useState(false);
  const [epg, setEpg] = useState(false);
'@ 'setEpg] = useState'
Edit-File 'src/components/Player.tsx' @'
<p className={clsx("truncate font-semibold", compact ? "text-xs" : "text-sm")}>{channel.name}</p>
'@ @'
<p className={clsx("truncate font-semibold", compact ? "text-xs" : "text-sm")}>{channel.name}</p>
            {!compact && <NowNext channel={channel} />}
'@ '<NowNext'
Edit-File 'src/components/Player.tsx' @'
{subs && !compact && (
'@ @'
{epg && !compact && <EpgPanel channel={channel} onClose={() => setEpg(false)} />}

        {subs && !compact && (
'@ '<EpgPanel channel'
Edit-File 'src/components/Player.tsx' @'
<button onClick={() => setSubs(true)} className="flex items-center gap-1.5 rounded-lg border border-bg-line px-2.5 py-1.5 text-xs hover:bg-bg-raised">
'@ @'
<EpgMenuButton channel={channel} onClick={() => setEpg(true)} className="flex items-center gap-1.5 rounded-lg border border-bg-line px-2.5 py-1.5 text-xs hover:bg-bg-raised" />
            <button onClick={() => setSubs(true)} className="flex items-center gap-1.5 rounded-lg border border-bg-line px-2.5 py-1.5 text-xs hover:bg-bg-raised">
'@ '<EpgMenuButton'
} else { Write-Host '  - Sin guia EPG (fase 5 no aplicada): se omite' -ForegroundColor DarkGray }

Write-Host ""
Write-Host "Listo. Ejecuta npm run build (comprueba tipos) y luego npm start." -ForegroundColor Green