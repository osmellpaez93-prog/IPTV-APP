<#
  StreamBox - fix-guia.ps1
  Sobre ui-zonix-netflix.ps1 (Qwen):
   - Guia: un clic en un canal lo reproduce en la MINIATURA superior; otro clic (o doble clic / "Ampliar") abre el modo teatro.
     La lista y el menu siguen donde estaban. Al cambiar de pagina el reproductor pasa a mini flotante.
   - En vivo: MPEG-TS se prueba PRIMERO (o el formato que funciono la ultima vez en ese servidor).
   - Navegacion con flechas tambien en las vistas nuevas (data-sbfocus) y sin doble salto en la rejilla EPG.
   - Alturas/anchos de la guia ajustados para que no se corte ni tape.
   - La guia usa appFetch (Tauri, Fase 2) si existe; si no, el proxy.
  Requisitos: haber aplicado fix-merge (store con playNow) y update-audio2 (usePlayer v3). Es seguro repetirlo.
  Uso (raiz del repo):  powershell -ExecutionPolicy Bypass -File .\fix-guia.ps1
#>
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "src\pages\TvGuide.tsx"))) {
    Write-Host "Primero aplica ui-zonix-netflix.ps1 (no encuentro TvGuide.tsx)." -ForegroundColor Red
    return
}
Write-Host "Aplicando guia en linea en: $root" -ForegroundColor Cyan
$utf8 = New-Object System.Text.UTF8Encoding($false)
$backedUp = @{}
function Norm([string]$s) { return $s.Replace("`r`n", "`n") }

function Write-ProjectFile {
    param([string]$RelPath, [string]$B64)
    $bytes = [Convert]::FromBase64String(($B64 -replace '\s', ''))
    $full = Join-Path $root $RelPath
    if (Test-Path $full) {
        $old = [System.IO.File]::ReadAllBytes($full)
        if (-not [System.Linq.Enumerable]::SequenceEqual($old, $bytes)) { Copy-Item $full "$full.bak" -Force }
    }
    [System.IO.File]::WriteAllBytes($full, $bytes)
    Write-Host "  + $RelPath (reescrito)" -ForegroundColor Green
}

function Edit-File {
    param([string]$Rel, [string]$Old, [string]$New, [string]$Marker, [switch]$All)
    $full = Join-Path $root $Rel
    if (-not (Test-Path $full)) { Write-Host "  ! No existe $Rel" -ForegroundColor Yellow; return }
    $t = Norm ([System.IO.File]::ReadAllText($full, $utf8))
    if ($t.Contains($Marker)) { Write-Host "  = ya aplicado en $Rel" -ForegroundColor DarkGray; return }
    $Old = Norm $Old; $New = Norm $New
    if (-not $t.Contains($Old)) { Write-Host "  ! No encontre el texto en $Rel (avisame): $Old" -ForegroundColor Yellow; return }
    if (-not $backedUp.ContainsKey($full)) { Copy-Item $full "$full.bak" -Force; $backedUp[$full] = $true }
    if ($All) { $t = $t.Replace($Old, $New) }
    else { $i = $t.IndexOf($Old); $t = $t.Substring(0, $i) + $New + $t.Substring($i + $Old.Length) }
    [System.IO.File]::WriteAllText($full, $t, $utf8)
    Write-Host "  + $Rel" -ForegroundColor Green
}

function Replace-Region {
    param([string]$Rel, [string]$Start, [string]$End, [string]$New, [string]$Marker)
    $full = Join-Path $root $Rel
    if (-not (Test-Path $full)) { Write-Host "  ! No existe $Rel" -ForegroundColor Yellow; return }
    $t = Norm ([System.IO.File]::ReadAllText($full, $utf8))
    if ($t.Contains($Marker)) { Write-Host "  = ya aplicado en $Rel" -ForegroundColor DarkGray; return }
    $s = $t.IndexOf($Start); $e = $t.IndexOf($End)
    if ($s -lt 0 -or $e -lt 0 -or $e -lt $s) { Write-Host "  ! No encontre las marcas en $Rel (avisame)" -ForegroundColor Yellow; return }
    if (-not $backedUp.ContainsKey($full)) { Copy-Item $full "$full.bak" -Force; $backedUp[$full] = $true }
    [System.IO.File]::WriteAllText($full, $t.Substring(0, $s) + (Norm $New) + $t.Substring($e), $utf8)
    Write-Host "  + $Rel" -ForegroundColor Green
}

# ---- 1) Estado: modo 'inline' + hueco donde se dibuja el reproductor
Edit-File 'src/store/index.ts' @'
export type ViewMode = "mini" | "theater" | "full";
'@ @'
export type ViewMode = "mini" | "theater" | "full" | "inline";
'@ '| "inline"'
Edit-File 'src/store/index.ts' @'
setQueue: (list: Channel[]) => void;
'@ @'
setQueue: (list: Channel[]) => void;
  /** Reproduce dentro de la miniatura de la guia (modo inline). */
  playInline: (c: Channel, list?: Channel[]) => void;
  inlineSlot: HTMLElement | null;
  setInlineSlot: (el: HTMLElement | null) => void;
'@ 'playInline: (c: Channel, list?'
Edit-File 'src/store/index.ts' @'
setQueue: (list) => set({ queue: list }),
'@ @'
playInline: (c, list) =>
        set({ nowPlaying: c, queue: list && list.length ? list : [c], viewMode: "inline" as ViewMode }),
      inlineSlot: null,
      setInlineSlot: (el) => set({ inlineSlot: el }),
      setQueue: (list) => set({ queue: list }),
'@ 'playInline: (c, list) =>'

# ---- 2) PlayerDock: dibuja el reproductor dentro de la miniatura y vuelve a ella al reducir
Edit-File 'src/components/PlayerDock.tsx' @'
import { useEffect, useRef, useState } from "react";
'@ @'
import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
'@ 'import { createPortal }'
Edit-File 'src/components/PlayerDock.tsx' @'
const multiview = useStore((s) => s.multiview);
'@ @'
const multiview = useStore((s) => s.multiview);
  const inlineSlot = useStore((s) => s.inlineSlot);
'@ 'inlineSlot = useStore'
Edit-File 'src/components/PlayerDock.tsx' @'
mode={viewMode}
'@ @'
mode={viewMode === "inline" ? (inlineSlot ? "cell" : "mini") : viewMode}
'@ 'inlineSlot ? "cell"'
Edit-File 'src/components/PlayerDock.tsx' @'
onMode={setViewMode}
'@ @'
onMode={(m) => setViewMode(m === "mini" && inlineSlot ? "inline" : m)}
'@ 'onMode={(m) =>'
Edit-File 'src/components/PlayerDock.tsx' @'
// ---- Mini flotante ----
'@ @'
// ---- En linea: dentro de la miniatura de la guia (si no esta visible, cae a mini flotante) ----
  if (viewMode === "inline" && inlineSlot) {
    return createPortal(<div className="h-full w-full">{player}</div>, inlineSlot);
  }

  // ---- Mini flotante ----
'@ 'createPortal(<div'
Edit-File 'src/components/Player.tsx' @'
useEffect(() => { boxRef.current?.focus({ preventScroll: true }); }, [channel.id, mode]);
'@ @'
useEffect(() => { if (mode !== "cell") boxRef.current?.focus({ preventScroll: true }); }, [channel.id, mode]);
'@ 'if (mode !== "cell") boxRef'

# ---- 3) Vista de guia: miniatura con reproductor + un clic / segundo clic
Write-ProjectFile 'src/components/tv/ChannelPreview.tsx' @'
aW1wb3J0IHsgdXNlRWZmZWN0LCB1c2VTdGF0ZSB9IGZyb20gInJlYWN0IjsKaW1wb3J0IHsgUGxheSwgU3RhciwgQ2FsZW5kYXJD
bG9jaywgTWF4aW1pemUyIH0gZnJvbSAibHVjaWRlLXJlYWN0IjsKaW1wb3J0IHsgY2xzeCB9IGZyb20gImNsc3giOwppbXBvcnQg
eyBpbWdVcmwgfSBmcm9tICIuLi8uLi9zZXJ2aWNlcy9wcm94eSI7CmltcG9ydCB7IGdldFByb2dyYW1tZXMsIG5vd05leHQsIGho
bW0sIHR5cGUgUHJvZ3JhbW1lIH0gZnJvbSAiLi4vLi4vc2VydmljZXMvZXBnL2d1aWRlIjsKaW1wb3J0IHsgdXNlU3RvcmUgfSBm
cm9tICIuLi8uLi9zdG9yZSI7CmltcG9ydCB0eXBlIHsgQ2hhbm5lbCB9IGZyb20gIi4uLy4uL3R5cGVzIjsKCmludGVyZmFjZSBQ
cm9wcyB7CiAgY2hhbm5lbDogQ2hhbm5lbCB8IG51bGw7CiAgaXNGYXY6IGJvb2xlYW47CiAgb25GYXY6IChpZDogc3RyaW5nKSA9
PiB2b2lkOwogIC8qKiBVbiBjbGljOiByZXByb2R1Y2UgZW4gZXN0YSBtaW5pYXR1cmEuICovCiAgb25TdGFydDogKGM6IENoYW5u
ZWwpID0+IHZvaWQ7CiAgLyoqIFNlZ3VuZG8gY2xpYyBvIGJvdMOzbjogYW1wbMOtYSBhIG1vZG8gdGVhdHJvLiAqLwogIG9uRXhw
YW5kOiAoYzogQ2hhbm5lbCkgPT4gdm9pZDsKfQoKLyoqCiAqIE1pbmlhdHVyYSBzdXBlcmlvciBkZSBsYSBndcOtYS4gRWwgcmVw
cm9kdWN0b3Igc2UgImVuY2h1ZmEiIGFxdcOtIChQbGF5ZXJEb2NrIGxvCiAqIGRpYnVqYSBkZW50cm8gZGUgZXN0ZSBodWVjbykg
cGFyYSBwb2RlciBtb3ZlcnRlIHBvciBsYSBndcOtYSBzaW4gcGVyZGVyIGVsIGNhbmFsLgogKi8KZXhwb3J0IGZ1bmN0aW9uIENo
YW5uZWxQcmV2aWV3KHsgY2hhbm5lbCwgaXNGYXYsIG9uRmF2LCBvblN0YXJ0LCBvbkV4cGFuZCB9OiBQcm9wcykgewogIGNvbnN0
IG5vd1BsYXlpbmcgPSB1c2VTdG9yZSgocykgPT4gcy5ub3dQbGF5aW5nKTsKICBjb25zdCB2aWV3TW9kZSA9IHVzZVN0b3JlKChz
KSA9PiBzLnZpZXdNb2RlKTsKICBjb25zdCBzZXRJbmxpbmVTbG90ID0gdXNlU3RvcmUoKHMpID0+IHMuc2V0SW5saW5lU2xvdCk7
CgogIGNvbnN0IFtpdGVtcywgc2V0SXRlbXNdID0gdXNlU3RhdGU8UHJvZ3JhbW1lW10+KFtdKTsKICBjb25zdCBbdGljaywgc2V0
VGlja10gPSB1c2VTdGF0ZShEYXRlLm5vdygpKTsKICBjb25zdCBbaW1nQmFkLCBzZXRJbWdCYWRdID0gdXNlU3RhdGUoZmFsc2Up
OwoKICB1c2VFZmZlY3QoKCkgPT4gewogICAgc2V0SW1nQmFkKGZhbHNlKTsKICAgIHNldEl0ZW1zKFtdKTsKICAgIGlmICghY2hh
bm5lbCkgcmV0dXJuOwogICAgbGV0IGFsaXZlID0gdHJ1ZTsKICAgIGdldFByb2dyYW1tZXMoY2hhbm5lbCwgNikudGhlbigocikg
PT4geyBpZiAoYWxpdmUpIHNldEl0ZW1zKHIpOyB9KTsKICAgIHJldHVybiAoKSA9PiB7IGFsaXZlID0gZmFsc2U7IH07CiAgfSwg
W2NoYW5uZWw/LmlkXSk7CgogIHVzZUVmZmVjdCgoKSA9PiB7CiAgICBjb25zdCB0ID0gd2luZG93LnNldEludGVydmFsKCgpID0+
IHNldFRpY2soRGF0ZS5ub3coKSksIDMwMDAwKTsKICAgIHJldHVybiAoKSA9PiB3aW5kb3cuY2xlYXJJbnRlcnZhbCh0KTsKICB9
LCBbXSk7CgogIGNvbnN0IGlubGluZSA9ICEhbm93UGxheWluZyAmJiB2aWV3TW9kZSA9PT0gImlubGluZSI7CiAgY29uc3Qgc2Ft
ZUNoYW5uZWwgPSAhIWNoYW5uZWwgJiYgISFub3dQbGF5aW5nICYmIG5vd1BsYXlpbmcuaWQgPT09IGNoYW5uZWwuaWQ7CiAgY29u
c3QgeyBub3csIG5leHQgfSA9IG5vd05leHQoaXRlbXMsIHRpY2spOwogIGNvbnN0IHBjdCA9IG5vdyA/IE1hdGgubWluKDEwMCwg
TWF0aC5tYXgoMCwgKCh0aWNrIC0gbm93LnN0YXJ0KSAvIChub3cuZW5kIC0gbm93LnN0YXJ0KSkgKiAxMDApKSA6IDA7CiAgY29u
c3QgbG9nbyA9IGltZ1VybChjaGFubmVsPy5sb2dvKTsKCiAgcmV0dXJuICgKICAgIDxkaXYgY2xhc3NOYW1lPSJmbGV4IGgtWzE3
MnB4XSBzaHJpbmstMCBpdGVtcy1zdHJldGNoIGdhcC00IGJvcmRlci1iIGJvcmRlci1bIzIyMzA0YV0gYmctWyMwZDEzMjBdIHAt
MyI+CiAgICAgIHsvKiBIdWVjbyBkZSB2w61kZW8gKi99CiAgICAgIDxkaXYgY2xhc3NOYW1lPSJyZWxhdGl2ZSBhc3BlY3Qtdmlk
ZW8gaC1mdWxsIHNocmluay0wIG92ZXJmbG93LWhpZGRlbiByb3VuZGVkLWxnIGJvcmRlciBib3JkZXItWyMyMjMwNGFdIGJnLWJs
YWNrIj4KICAgICAgICA8ZGl2IHJlZj17c2V0SW5saW5lU2xvdH0gY2xhc3NOYW1lPSJhYnNvbHV0ZSBpbnNldC0wIiAvPgoKICAg
ICAgICB7IWlubGluZSAmJiAoCiAgICAgICAgICA8YnV0dG9uCiAgICAgICAgICAgIGRhdGEtc2Jmb2N1cz0iMSIKICAgICAgICAg
ICAgZGlzYWJsZWQ9eyFjaGFubmVsfQogICAgICAgICAgICBvbkNsaWNrPXsoKSA9PiBjaGFubmVsICYmIG9uU3RhcnQoY2hhbm5l
bCl9CiAgICAgICAgICAgIGNsYXNzTmFtZT0iZ3JvdXAgYWJzb2x1dGUgaW5zZXQtMCIKICAgICAgICAgICAgYXJpYS1sYWJlbD17
Y2hhbm5lbCA/IGBSZXByb2R1Y2lyICR7Y2hhbm5lbC5uYW1lfWAgOiAiU2luIGNhbmFsIn0KICAgICAgICAgID4KICAgICAgICAg
ICAge2xvZ28gJiYgIWltZ0JhZCA/ICgKICAgICAgICAgICAgICA8aW1nIHNyYz17bG9nb30gYWx0PSIiIG9uRXJyb3I9eygpID0+
IHNldEltZ0JhZCh0cnVlKX0gY2xhc3NOYW1lPSJoLWZ1bGwgdy1mdWxsIG9iamVjdC1jb250YWluIHAtNCBvcGFjaXR5LTgwIiAv
PgogICAgICAgICAgICApIDogKAogICAgICAgICAgICAgIDxzcGFuIGNsYXNzTmFtZT0iZmxleCBoLWZ1bGwgdy1mdWxsIGl0ZW1z
LWNlbnRlciBqdXN0aWZ5LWNlbnRlciBiZy1ncmFkaWVudC10by1iciBmcm9tLVsjMTQxZDJlXSB0by1bIzA3MGExMl0gcHgtMyB0
ZXh0LWNlbnRlciB0ZXh0LXhzIHRleHQtWyM1ZDZkODhdIj4KICAgICAgICAgICAgICAgIHtjaGFubmVsID8gY2hhbm5lbC5uYW1l
LnNsaWNlKDAsIDI2KSA6ICJFbGlnZSB1biBjYW5hbCJ9CiAgICAgICAgICAgICAgPC9zcGFuPgogICAgICAgICAgICApfQogICAg
ICAgICAgICB7Y2hhbm5lbCAmJiAoCiAgICAgICAgICAgICAgPHNwYW4gY2xhc3NOYW1lPSJhYnNvbHV0ZSBpbnNldC0wIGZsZXgg
aXRlbXMtY2VudGVyIGp1c3RpZnktY2VudGVyIGJnLWJsYWNrLzQ1IG9wYWNpdHktMCB0cmFuc2l0aW9uLW9wYWNpdHkgZ3JvdXAt
aG92ZXI6b3BhY2l0eS0xMDAiPgogICAgICAgICAgICAgICAgPHNwYW4gY2xhc3NOYW1lPSJmbGV4IGgtMTIgdy0xMiBpdGVtcy1j
ZW50ZXIganVzdGlmeS1jZW50ZXIgcm91bmRlZC1mdWxsIGJnLVsjNGM4ZGZmXSI+CiAgICAgICAgICAgICAgICAgIDxQbGF5IGNs
YXNzTmFtZT0iaC01IHctNSB0ZXh0LXdoaXRlIiBmaWxsPSJjdXJyZW50Q29sb3IiIC8+CiAgICAgICAgICAgICAgICA8L3NwYW4+
CiAgICAgICAgICAgICAgPC9zcGFuPgogICAgICAgICAgICApfQogICAgICAgICAgPC9idXR0b24+CiAgICAgICAgKX0KCiAgICAg
ICAge2lubGluZSAmJiBjaGFubmVsICYmICgKICAgICAgICAgIDxidXR0b24KICAgICAgICAgICAgb25DbGljaz17KCkgPT4gb25F
eHBhbmQobm93UGxheWluZyEpfQogICAgICAgICAgICBjbGFzc05hbWU9ImFic29sdXRlIGJvdHRvbS0yIHJpZ2h0LTIgei0zMCBm
bGV4IGl0ZW1zLWNlbnRlciBnYXAtMSByb3VuZGVkLW1kIGJnLWJsYWNrLzcwIHB4LTIgcHktMSB0ZXh0LVsxMXB4XSBmb250LXNl
bWlib2xkIHRleHQtd2hpdGUgaG92ZXI6YmctWyM0YzhkZmZdIgogICAgICAgICAgICB0aXRsZT0iQW1wbGlhciAobW9kbyB0ZWF0
cm8pIgogICAgICAgICAgICBhcmlhLWxhYmVsPSJBbXBsaWFyIHJlcHJvZHVjdG9yIgogICAgICAgICAgPgogICAgICAgICAgICA8
TWF4aW1pemUyIGNsYXNzTmFtZT0iaC0zLjUgdy0zLjUiIC8+IEFtcGxpYXIKICAgICAgICAgIDwvYnV0dG9uPgogICAgICAgICl9
CiAgICAgIDwvZGl2PgoKICAgICAgey8qIEluZm9ybWFjacOzbiBkZWwgY2FuYWwgc2VsZWNjaW9uYWRvICovfQogICAgICA8ZGl2
IGNsYXNzTmFtZT0iZmxleCBtaW4tdy0wIGZsZXgtMSBmbGV4LWNvbCBqdXN0aWZ5LWNlbnRlciBnYXAtMSI+CiAgICAgICAgeyFj
aGFubmVsID8gKAogICAgICAgICAgPHAgY2xhc3NOYW1lPSJ0ZXh0LXNtIHRleHQtWyM1ZDZkODhdIj5TZWxlY2Npb25hIHVuIGNh
bmFsIGRlIGxhIGd1w61hPC9wPgogICAgICAgICkgOiAoCiAgICAgICAgICA8PgogICAgICAgICAgICA8ZGl2IGNsYXNzTmFtZT0i
ZmxleCBpdGVtcy1zdGFydCBnYXAtMiI+CiAgICAgICAgICAgICAgPGgzIGNsYXNzTmFtZT0ibWluLXctMCBmbGV4LTEgdHJ1bmNh
dGUgdGV4dC1sZyBmb250LWJvbGQiPntjaGFubmVsLm5hbWV9PC9oMz4KICAgICAgICAgICAgICA8YnV0dG9uCiAgICAgICAgICAg
ICAgICBvbkNsaWNrPXsoKSA9PiBvbkZhdihjaGFubmVsLmlkKX0KICAgICAgICAgICAgICAgIGNsYXNzTmFtZT0icm91bmRlZC1s
ZyBwLTEuNSBob3ZlcjpiZy1bIzE0MWQyZV0iCiAgICAgICAgICAgICAgICBhcmlhLWxhYmVsPXtpc0ZhdiA/ICJRdWl0YXIgZGUg
ZmF2b3JpdG9zIiA6ICJBw7FhZGlyIGEgZmF2b3JpdG9zIn0KICAgICAgICAgICAgICA+CiAgICAgICAgICAgICAgICA8U3RhciBj
bGFzc05hbWU9e2Nsc3goImgtNCB3LTQiLCBpc0ZhdiA/ICJmaWxsLVsjZmZiMDIwXSB0ZXh0LVsjZmZiMDIwXSIgOiAidGV4dC1b
IzVkNmQ4OF0iKX0gLz4KICAgICAgICAgICAgICA8L2J1dHRvbj4KICAgICAgICAgICAgPC9kaXY+CiAgICAgICAgICAgIDxwIGNs
YXNzTmFtZT0idHJ1bmNhdGUgdGV4dC14cyB0ZXh0LVsjNWQ2ZDg4XSI+CiAgICAgICAgICAgICAge2NoYW5uZWwuZ3JvdXB9CiAg
ICAgICAgICAgICAgeyIgwrcgIn0KICAgICAgICAgICAgICB7c2FtZUNoYW5uZWwgJiYgaW5saW5lID8gIkNsaWMgZGUgbnVldm8g
cGFyYSBhbXBsaWFyIiA6ICJDbGljIHBhcmEgdmVyIGFxdcOtIMK3IGRvYmxlIGNsaWMgcGFyYSBhbXBsaWFyIn0KICAgICAgICAg
ICAgPC9wPgoKICAgICAgICAgICAge2lubGluZSAmJiBub3dQbGF5aW5nICYmICFzYW1lQ2hhbm5lbCAmJiAoCiAgICAgICAgICAg
ICAgPHAgY2xhc3NOYW1lPSJ0cnVuY2F0ZSB0ZXh0LXhzIHRleHQtWyMzOGJkZjhdIj5SZXByb2R1Y2llbmRvOiB7bm93UGxheWlu
Zy5uYW1lfTwvcD4KICAgICAgICAgICAgKX0KCiAgICAgICAgICAgIHtub3cgPyAoCiAgICAgICAgICAgICAgPGRpdiBjbGFzc05h
bWU9Im10LTEgc3BhY2UteS0xIj4KICAgICAgICAgICAgICAgIDxkaXYgY2xhc3NOYW1lPSJmbGV4IGl0ZW1zLWJhc2VsaW5lIGdh
cC0yIj4KICAgICAgICAgICAgICAgICAgPHNwYW4gY2xhc3NOYW1lPSJmbGV4IGl0ZW1zLWNlbnRlciBnYXAtMSByb3VuZGVkIGJn
LVsjZmYyZDU1XS8xNSBweC0xLjUgcHktMC41IHRleHQtWzEwcHhdIGZvbnQtYm9sZCB1cHBlcmNhc2UgdGV4dC1bI2ZmMmQ1NV0i
PgogICAgICAgICAgICAgICAgICAgIDxzcGFuIGNsYXNzTmFtZT0ic2ItcHVsc2UgaC0xLjUgdy0xLjUgcm91bmRlZC1mdWxsIGJn
LVsjZmYyZDU1XSIgLz4gQWhvcmEKICAgICAgICAgICAgICAgICAgPC9zcGFuPgogICAgICAgICAgICAgICAgICA8c3BhbiBjbGFz
c05hbWU9Im1pbi13LTAgZmxleC0xIHRydW5jYXRlIHRleHQtc20gZm9udC1zZW1pYm9sZCI+e25vdy50aXRsZX08L3NwYW4+CiAg
ICAgICAgICAgICAgICAgIDxzcGFuIGNsYXNzTmFtZT0ic2ItdG51bSBzaHJpbmstMCB0ZXh0LXhzIHRleHQtWyM5M2EzYmRdIj57
aGhtbShub3cuc3RhcnQpfSAtIHtoaG1tKG5vdy5lbmQpfTwvc3Bhbj4KICAgICAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAg
ICAgICAgPGRpdiBjbGFzc05hbWU9ImgtMSB3LWZ1bGwgb3ZlcmZsb3ctaGlkZGVuIHJvdW5kZWQtZnVsbCBiZy1bIzIyMzA0YV0i
PgogICAgICAgICAgICAgICAgICA8ZGl2IGNsYXNzTmFtZT0iaC1mdWxsIHJvdW5kZWQtZnVsbCBiZy1ncmFkaWVudC10by1yIGZy
b20tWyM0YzhkZmZdIHRvLVsjMzhiZGY4XSIgc3R5bGU9e3sgd2lkdGg6IGAke3BjdH0lYCB9fSAvPgogICAgICAgICAgICAgICAg
PC9kaXY+CiAgICAgICAgICAgICAgICB7bmV4dCAmJiAoCiAgICAgICAgICAgICAgICAgIDxwIGNsYXNzTmFtZT0idHJ1bmNhdGUg
dGV4dC14cyB0ZXh0LVsjOTNhM2JkXSI+CiAgICAgICAgICAgICAgICAgICAgPHNwYW4gY2xhc3NOYW1lPSJ0ZXh0LVsjNWQ2ZDg4
XSI+QSBjb250aW51YWNpw7NuIHtoaG1tKG5leHQuc3RhcnQpfTo8L3NwYW4+IHtuZXh0LnRpdGxlfQogICAgICAgICAgICAgICAg
ICA8L3A+CiAgICAgICAgICAgICAgICApfQogICAgICAgICAgICAgIDwvZGl2PgogICAgICAgICAgICApIDogKAogICAgICAgICAg
ICAgIDxwIGNsYXNzTmFtZT0ibXQtMSBmbGV4IGl0ZW1zLWNlbnRlciBnYXAtMS41IHRleHQteHMgdGV4dC1bIzVkNmQ4OF0iPgog
ICAgICAgICAgICAgICAgPENhbGVuZGFyQ2xvY2sgY2xhc3NOYW1lPSJoLTMuNSB3LTMuNSIgLz4gU2luIGd1w61hIHBhcmEgZXN0
ZSBjYW5hbAogICAgICAgICAgICAgIDwvcD4KICAgICAgICAgICAgKX0KICAgICAgICAgIDwvPgogICAgICAgICl9CiAgICAgIDwv
ZGl2PgogICAgPC9kaXY+CiAgKTsKfQo=
'@
Write-ProjectFile 'src/pages/TvGuide.tsx' @'
aW1wb3J0IHsgdXNlRGVmZXJyZWRWYWx1ZSwgdXNlRWZmZWN0LCB1c2VNZW1vLCB1c2VTdGF0ZSB9IGZyb20gInJlYWN0IjsKaW1w
b3J0IHsgdXNlTGl2ZVF1ZXJ5IH0gZnJvbSAiZGV4aWUtcmVhY3QtaG9va3MiOwppbXBvcnQgeyBMaXN0LCBDYWxlbmRhckNsb2Nr
LCBab29tSW4sIFpvb21PdXQsIExvY2F0ZSwgUGFuZWxMZWZ0Q2xvc2UsIFBhbmVsTGVmdE9wZW4gfSBmcm9tICJsdWNpZGUtcmVh
Y3QiOwppbXBvcnQgeyBkYiB9IGZyb20gIi4uL2RiIjsKaW1wb3J0IHsgdXNlU3RvcmUgfSBmcm9tICIuLi9zdG9yZSI7CmltcG9y
dCB7IHVzZUZhdm9yaXRlcyB9IGZyb20gIi4uL2hvb2tzL3VzZUZhdm9yaXRlcyI7CmltcG9ydCB7IENhdGVnb3J5Q29sdW1uLCB0
eXBlIENhdEtleSB9IGZyb20gIi4uL2NvbXBvbmVudHMvdHYvQ2F0ZWdvcnlDb2x1bW4iOwppbXBvcnQgeyBDaGFubmVsUHJldmll
dyB9IGZyb20gIi4uL2NvbXBvbmVudHMvdHYvQ2hhbm5lbFByZXZpZXciOwppbXBvcnQgeyBFcGdUaW1lbGluZSB9IGZyb20gIi4u
L2NvbXBvbmVudHMvdHYvRXBnVGltZWxpbmUiOwppbXBvcnQgeyBDYXRlZ29yeVBhZ2UgfSBmcm9tICIuL0NhdGVnb3J5UGFnZSI7
CmltcG9ydCB0eXBlIHsgQ2hhbm5lbCB9IGZyb20gIi4uL3R5cGVzIjsKaW1wb3J0ICIuLi9zdHlsZXMvc3RyZWFtYm94LXVpLmNz
cyI7Cgpjb25zdCBNSU5VVEVTID0gMzYwOwoKZnVuY3Rpb24gaGFsZkhvdXJTdGFydCgpIHsKICBjb25zdCBkID0gbmV3IERhdGUo
KTsKICBkLnNldE1pbnV0ZXMoZC5nZXRNaW51dGVzKCkgPCAzMCA/IDAgOiAzMCwgMCwgMCk7CiAgcmV0dXJuIGQuZ2V0VGltZSgp
IC0gMzAgKiA2MDAwMDsKfQoKZXhwb3J0IGZ1bmN0aW9uIFR2R3VpZGUoKSB7CiAgY29uc3QgYWN0aXZlUGxheWxpc3RJZCA9IHVz
ZVN0b3JlKChzKSA9PiBzLmFjdGl2ZVBsYXlsaXN0SWQpOwogIGNvbnN0IG5vd1BsYXlpbmcgPSB1c2VTdG9yZSgocykgPT4gcy5u
b3dQbGF5aW5nKTsKICBjb25zdCBzZXRWaWV3TW9kZSA9IHVzZVN0b3JlKChzKSA9PiBzLnNldFZpZXdNb2RlKTsKICBjb25zdCBw
bGF5SW5saW5lID0gdXNlU3RvcmUoKHMpID0+IHMucGxheUlubGluZSk7CiAgY29uc3QgeyBmYXZTZXQsIHRvZ2dsZSB9ID0gdXNl
RmF2b3JpdGVzKCk7CgogIGNvbnN0IFttb2RlLCBzZXRNb2RlXSA9IHVzZVN0YXRlPCJndWlkZSIgfCAibGlzdCI+KCJndWlkZSIp
OwogIGNvbnN0IFtjYXQsIHNldENhdF0gPSB1c2VTdGF0ZTxDYXRLZXk+KCJfX2FsbCIpOwogIGNvbnN0IFtzaG93Q2F0cywgc2V0
U2hvd0NhdHNdID0gdXNlU3RhdGUoKCkgPT4gd2luZG93LmlubmVyV2lkdGggPj0gMTUwMCk7CiAgY29uc3QgW3F1ZXJ5LCBzZXRR
dWVyeV0gPSB1c2VTdGF0ZSgiIik7CiAgY29uc3QgcSA9IHVzZURlZmVycmVkVmFsdWUocXVlcnkpOwogIGNvbnN0IFtweFBlck1p
biwgc2V0UHhQZXJNaW5dID0gdXNlU3RhdGUoNik7CiAgY29uc3QgW3NlbGVjdGVkLCBzZXRTZWxlY3RlZF0gPSB1c2VTdGF0ZTxD
aGFubmVsIHwgbnVsbD4obnVsbCk7CiAgY29uc3QgW3N0YXJ0TXMsIHNldFN0YXJ0TXNdID0gdXNlU3RhdGUoaGFsZkhvdXJTdGFy
dCk7CgogIGNvbnN0IHJlY2VudCA9IHVzZUxpdmVRdWVyeShhc3luYyAoKSA9PiB7CiAgICBjb25zdCByb3dzID0gYXdhaXQgZGIu
aGlzdG9yeS5vcmRlckJ5KCJ1cGRhdGVkQXQiKS5yZXZlcnNlKCkubGltaXQoNjApLnRvQXJyYXkoKTsKICAgIHJldHVybiBuZXcg
U2V0KHJvd3MubWFwKChyKSA9PiByLmlkKSk7CiAgfSwgW10pOwoKICBjb25zdCBhbGwgPSB1c2VMaXZlUXVlcnkoCiAgICAoKSA9
PgogICAgICBhY3RpdmVQbGF5bGlzdElkCiAgICAgICAgPyBkYi5jaGFubmVscy53aGVyZSgiW3BsYXlsaXN0SWQrY2F0ZWdvcnld
IikuZXF1YWxzKFthY3RpdmVQbGF5bGlzdElkLCAibGl2ZSJdKS50b0FycmF5KCkKICAgICAgICA6IFByb21pc2UucmVzb2x2ZShb
XSBhcyBDaGFubmVsW10pLAogICAgW2FjdGl2ZVBsYXlsaXN0SWRdCiAgKTsKCiAgY29uc3QgZ3JvdXBzID0gdXNlTWVtbygKICAg
ICgpID0+IEFycmF5LmZyb20obmV3IFNldCgoYWxsID8/IFtdKS5tYXAoKGMpID0+IGMuZ3JvdXAgfHwgIlNpbiBjYXRlZ29yw61h
IikpKS5zb3J0KChhLCBiKSA9PiBhLmxvY2FsZUNvbXBhcmUoYikpLAogICAgW2FsbF0KICApOwoKICBjb25zdCB2aXNpYmxlID0g
dXNlTWVtbygoKSA9PiB7CiAgICBjb25zdCBuZWVkbGUgPSBxLnRyaW0oKS50b0xvd2VyQ2FzZSgpOwogICAgcmV0dXJuIChhbGwg
Pz8gW10pLmZpbHRlcigoYykgPT4gewogICAgICBjb25zdCBnID0gYy5ncm91cCB8fCAiU2luIGNhdGVnb3LDrWEiOwogICAgICBp
ZiAoY2F0ID09PSAiX19mYXYiICYmICFmYXZTZXQuaGFzKGMuaWQpKSByZXR1cm4gZmFsc2U7CiAgICAgIGlmIChjYXQgPT09ICJf
X3JlY2VudCIgJiYgIXJlY2VudD8uaGFzKGMuaWQpKSByZXR1cm4gZmFsc2U7CiAgICAgIGlmIChjYXQgIT09ICJfX2FsbCIgJiYg
Y2F0ICE9PSAiX19mYXYiICYmIGNhdCAhPT0gIl9fcmVjZW50IiAmJiBnICE9PSBjYXQgJiYgYy5ncm91cCAhPT0gY2F0KSByZXR1
cm4gZmFsc2U7CiAgICAgIGlmIChuZWVkbGUgJiYgIWMubmFtZS50b0xvd2VyQ2FzZSgpLmluY2x1ZGVzKG5lZWRsZSkpIHJldHVy
biBmYWxzZTsKICAgICAgcmV0dXJuIHRydWU7CiAgICB9KTsKICB9LCBbYWxsLCBjYXQsIHEsIGZhdlNldCwgcmVjZW50XSk7Cgog
IHVzZUVmZmVjdCgoKSA9PiB7CiAgICBpZiAodmlzaWJsZS5sZW5ndGggPT09IDApIHsgc2V0U2VsZWN0ZWQobnVsbCk7IHJldHVy
bjsgfQogICAgaWYgKCFzZWxlY3RlZCB8fCAhdmlzaWJsZS5zb21lKChjKSA9PiBjLmlkID09PSBzZWxlY3RlZC5pZCkpIHNldFNl
bGVjdGVkKHZpc2libGVbMF0pOwogIH0sIFt2aXNpYmxlXSk7IC8vIGVzbGludC1kaXNhYmxlLWxpbmUgcmVhY3QtaG9va3MvZXho
YXVzdGl2ZS1kZXBzCgogIC8vIFVuIGNsaWM6IHJlcHJvZHVjZSBlbiBsYSBtaW5pYXR1cmEuIFNpIHlhIGVzdMOhIHNvbmFuZG8g
ZXNlIGNhbmFsOiBsbyBhbXBsw61hLgogIGNvbnN0IHBpY2sgPSAoYzogQ2hhbm5lbCkgPT4gewogICAgc2V0U2VsZWN0ZWQoYyk7
CiAgICBpZiAobm93UGxheWluZz8uaWQgPT09IGMuaWQpIHsgc2V0Vmlld01vZGUoInRoZWF0ZXIiKTsgcmV0dXJuOyB9CiAgICBw
bGF5SW5saW5lKGMsIHZpc2libGUpOwogIH07CiAgLy8gRG9ibGUgY2xpYyAvIGJvdMOzbiBkZSBsYSBmaWxhIC8gIkFtcGxpYXIi
OiBtb2RvIHRlYXRyby4KICBjb25zdCBlbmxhcmdlID0gKGM6IENoYW5uZWwpID0+IHsKICAgIHNldFNlbGVjdGVkKGMpOwogICAg
aWYgKG5vd1BsYXlpbmc/LmlkICE9PSBjLmlkKSBwbGF5SW5saW5lKGMsIHZpc2libGUpOwogICAgc2V0Vmlld01vZGUoInRoZWF0
ZXIiKTsKICB9OwoKICBpZiAobW9kZSA9PT0gImxpc3QiKSB7CiAgICByZXR1cm4gKAogICAgICA8ZGl2IGNsYXNzTmFtZT0ic2It
c2NvcGUiPgogICAgICAgIDxidXR0b24KICAgICAgICAgIG9uQ2xpY2s9eygpID0+IHNldE1vZGUoImd1aWRlIil9CiAgICAgICAg
ICBjbGFzc05hbWU9Im1iLTQgZmxleCBpdGVtcy1jZW50ZXIgZ2FwLTIgcm91bmRlZC1sZyBib3JkZXIgYm9yZGVyLVsjMjIzMDRh
XSBiZy1bIzBkMTMyMF0gcHgtMyBweS0xLjUgdGV4dC1zbSBob3ZlcjpiZy1bIzE0MWQyZV0iCiAgICAgICAgPgogICAgICAgICAg
PENhbGVuZGFyQ2xvY2sgY2xhc3NOYW1lPSJoLTQgdy00IHRleHQtWyM0YzhkZmZdIiAvPiBWb2x2ZXIgYSBsYSBndcOtYQogICAg
ICAgIDwvYnV0dG9uPgogICAgICAgIDxDYXRlZ29yeVBhZ2UgY2F0ZWdvcnk9ImxpdmUiIHRpdGxlPSJUViBlbiB2aXZvIiBwbGFj
ZWhvbGRlcj0iQnVzY2FyIGNhbmFsLi4uIiBub3VuPSJjYW5hbGVzIiAvPgogICAgICA8L2Rpdj4KICAgICk7CiAgfQoKICBpZiAo
IWFjdGl2ZVBsYXlsaXN0SWQpIHsKICAgIHJldHVybiA8ZGl2IGNsYXNzTmFtZT0icHktMjAgdGV4dC1jZW50ZXIgdGV4dC1bIzkz
YTNiZF0iPkNhcmdhIHVuYSBsaXN0YSBlbiBNaXMgbGlzdGFzIHBhcmEgdmVyIGxhIGd1w61hLjwvZGl2PjsKICB9CgogIHJldHVy
biAoCiAgICA8ZGl2IGNsYXNzTmFtZT0ic2Itc2NvcGUgc2ItaW4gZmxleCBoLVtjYWxjKDEwMHZoLTdyZW0pXSBtaW4taC1bNTIw
cHhdIG92ZXJmbG93LWhpZGRlbiByb3VuZGVkLXhsIGJvcmRlciBib3JkZXItWyMyMjMwNGFdIGJnLVsjMDcwYTEyXSI+CiAgICAg
IHtzaG93Q2F0cyAmJiAoCiAgICAgICAgPGFzaWRlIGNsYXNzTmFtZT0iaGlkZGVuIHctWzI1MHB4XSBzaHJpbmstMCBsZzpibG9j
ayI+CiAgICAgICAgICA8Q2F0ZWdvcnlDb2x1bW4gY2hhbm5lbHM9e2FsbCA/PyBbXX0gdmFsdWU9e2NhdH0gb25DaGFuZ2U9e3Nl
dENhdH0gcXVlcnk9e3F1ZXJ5fSBvblF1ZXJ5PXtzZXRRdWVyeX0gLz4KICAgICAgICA8L2FzaWRlPgogICAgICApfQoKICAgICAg
PHNlY3Rpb24gY2xhc3NOYW1lPSJmbGV4IG1pbi13LTAgZmxleC0xIGZsZXgtY29sIj4KICAgICAgICA8Q2hhbm5lbFByZXZpZXcK
ICAgICAgICAgIGNoYW5uZWw9e3NlbGVjdGVkfQogICAgICAgICAgaXNGYXY9eyEhc2VsZWN0ZWQgJiYgZmF2U2V0LmhhcyhzZWxl
Y3RlZC5pZCl9CiAgICAgICAgICBvbkZhdj17dG9nZ2xlfQogICAgICAgICAgb25TdGFydD17cGlja30KICAgICAgICAgIG9uRXhw
YW5kPXtlbmxhcmdlfQogICAgICAgIC8+CgogICAgICAgIDxkaXYgY2xhc3NOYW1lPSJmbGV4IHNocmluay0wIGZsZXgtd3JhcCBp
dGVtcy1jZW50ZXIgZ2FwLTIgYm9yZGVyLWIgYm9yZGVyLVsjMjIzMDRhXSBiZy1bIzBkMTMyMF0gcHgtMyBweS0yIj4KICAgICAg
ICAgIDxidXR0b24KICAgICAgICAgICAgb25DbGljaz17KCkgPT4gc2V0U2hvd0NhdHMoKHYpID0+ICF2KX0KICAgICAgICAgICAg
Y2xhc3NOYW1lPSJoaWRkZW4gaXRlbXMtY2VudGVyIGdhcC0xLjUgcm91bmRlZC1sZyBib3JkZXIgYm9yZGVyLVsjMjIzMDRhXSBw
eC0yLjUgcHktMS41IHRleHQteHMgaG92ZXI6YmctWyMxNDFkMmVdIGxnOmZsZXgiCiAgICAgICAgICAgIHRpdGxlPSJNb3N0cmFy
IHUgb2N1bHRhciBjYXRlZ29yw61hcyIKICAgICAgICAgID4KICAgICAgICAgICAge3Nob3dDYXRzID8gPFBhbmVsTGVmdENsb3Nl
IGNsYXNzTmFtZT0iaC0zLjUgdy0zLjUiIC8+IDogPFBhbmVsTGVmdE9wZW4gY2xhc3NOYW1lPSJoLTMuNSB3LTMuNSIgLz59CiAg
ICAgICAgICAgIENhdGVnb3LDrWFzCiAgICAgICAgICA8L2J1dHRvbj4KCiAgICAgICAgICA8c2VsZWN0CiAgICAgICAgICAgIHZh
bHVlPXtjYXR9CiAgICAgICAgICAgIG9uQ2hhbmdlPXsoZSkgPT4gc2V0Q2F0KGUudGFyZ2V0LnZhbHVlKX0KICAgICAgICAgICAg
Y2xhc3NOYW1lPXtgbWF4LXctWzIyMHB4XSByb3VuZGVkLWxnIGJvcmRlciBib3JkZXItWyMyMjMwNGFdIGJnLVsjMDcwYTEyXSBw
eC0yIHB5LTEuNSB0ZXh0LXhzIGZvY3VzOmJvcmRlci1bIzRjOGRmZl0gZm9jdXM6b3V0bGluZS1ub25lICR7c2hvd0NhdHMgPyAi
bGc6aGlkZGVuIiA6ICIifWB9CiAgICAgICAgICA+CiAgICAgICAgICAgIDxvcHRpb24gdmFsdWU9Il9fYWxsIj5Ub2RvcyAoeyhh
bGwgPz8gW10pLmxlbmd0aH0pPC9vcHRpb24+CiAgICAgICAgICAgIDxvcHRpb24gdmFsdWU9Il9fZmF2Ij5GYXZvcml0b3M8L29w
dGlvbj4KICAgICAgICAgICAgPG9wdGlvbiB2YWx1ZT0iX19yZWNlbnQiPlJlY2llbnRlczwvb3B0aW9uPgogICAgICAgICAgICB7
Z3JvdXBzLm1hcCgoZykgPT4gPG9wdGlvbiBrZXk9e2d9IHZhbHVlPXtnfT57Z308L29wdGlvbj4pfQogICAgICAgICAgPC9zZWxl
Y3Q+CgogICAgICAgICAgeyFzaG93Q2F0cyAmJiAoCiAgICAgICAgICAgIDxpbnB1dAogICAgICAgICAgICAgIHZhbHVlPXtxdWVy
eX0KICAgICAgICAgICAgICBvbkNoYW5nZT17KGUpID0+IHNldFF1ZXJ5KGUudGFyZ2V0LnZhbHVlKX0KICAgICAgICAgICAgICBw
bGFjZWhvbGRlcj0iQnVzY2FyIGNhbmFsLi4uIgogICAgICAgICAgICAgIGNsYXNzTmFtZT0idy00MCByb3VuZGVkLWxnIGJvcmRl
ciBib3JkZXItWyMyMjMwNGFdIGJnLVsjMDcwYTEyXSBweC0yIHB5LTEuNSB0ZXh0LXhzIGZvY3VzOmJvcmRlci1bIzRjOGRmZl0g
Zm9jdXM6b3V0bGluZS1ub25lIgogICAgICAgICAgICAvPgogICAgICAgICAgKX0KCiAgICAgICAgICA8c3BhbiBjbGFzc05hbWU9
InNiLXRudW0gcm91bmRlZC1mdWxsIGJnLVsjMTQxZDJlXSBweC0yLjUgcHktMSB0ZXh0LVsxMXB4XSBmb250LXNlbWlib2xkIHRl
eHQtWyM5M2EzYmRdIj4KICAgICAgICAgICAge3Zpc2libGUubGVuZ3RoLnRvTG9jYWxlU3RyaW5nKCl9IGNhbmFsZXMKICAgICAg
ICAgIDwvc3Bhbj4KCiAgICAgICAgICA8ZGl2IGNsYXNzTmFtZT0iZmxleC0xIiAvPgoKICAgICAgICAgIDxidXR0b24KICAgICAg
ICAgICAgb25DbGljaz17KCkgPT4gc2V0U3RhcnRNcyhoYWxmSG91clN0YXJ0KCkpfQogICAgICAgICAgICBjbGFzc05hbWU9ImZs
ZXggaXRlbXMtY2VudGVyIGdhcC0xLjUgcm91bmRlZC1sZyBib3JkZXIgYm9yZGVyLVsjMjIzMDRhXSBweC0yLjUgcHktMS41IHRl
eHQteHMgaG92ZXI6YmctWyMxNDFkMmVdIgogICAgICAgICAgPgogICAgICAgICAgICA8TG9jYXRlIGNsYXNzTmFtZT0iaC0zLjUg
dy0zLjUgdGV4dC1bIzM4YmRmOF0iIC8+IEFob3JhCiAgICAgICAgICA8L2J1dHRvbj4KICAgICAgICAgIDxkaXYgY2xhc3NOYW1l
PSJmbGV4IGl0ZW1zLWNlbnRlciBnYXAtMSByb3VuZGVkLWxnIGJvcmRlciBib3JkZXItWyMyMjMwNGFdIHB4LTEgcHktMC41Ij4K
ICAgICAgICAgICAgPGJ1dHRvbiBvbkNsaWNrPXsoKSA9PiBzZXRQeFBlck1pbigodikgPT4gTWF0aC5tYXgoMywgdiAtIDEuNSkp
fSBjbGFzc05hbWU9InJvdW5kZWQgcC0xIGhvdmVyOmJnLVsjMTQxZDJlXSIgYXJpYS1sYWJlbD0iQWxlamFyIj4KICAgICAgICAg
ICAgICA8Wm9vbU91dCBjbGFzc05hbWU9ImgtMy41IHctMy41IiAvPgogICAgICAgICAgICA8L2J1dHRvbj4KICAgICAgICAgICAg
PHNwYW4gY2xhc3NOYW1lPSJzYi10bnVtIHctOCB0ZXh0LWNlbnRlciB0ZXh0LVsxMXB4XSB0ZXh0LVsjOTNhM2JkXSI+e3B4UGVy
TWluLnRvRml4ZWQoMSl9PC9zcGFuPgogICAgICAgICAgICA8YnV0dG9uIG9uQ2xpY2s9eygpID0+IHNldFB4UGVyTWluKCh2KSA9
PiBNYXRoLm1pbigxNiwgdiArIDEuNSkpfSBjbGFzc05hbWU9InJvdW5kZWQgcC0xIGhvdmVyOmJnLVsjMTQxZDJlXSIgYXJpYS1s
YWJlbD0iQWNlcmNhciI+CiAgICAgICAgICAgICAgPFpvb21JbiBjbGFzc05hbWU9ImgtMy41IHctMy41IiAvPgogICAgICAgICAg
ICA8L2J1dHRvbj4KICAgICAgICAgIDwvZGl2PgogICAgICAgICAgPGJ1dHRvbgogICAgICAgICAgICBvbkNsaWNrPXsoKSA9PiBz
ZXRNb2RlKCJsaXN0Iil9CiAgICAgICAgICAgIGNsYXNzTmFtZT0iZmxleCBpdGVtcy1jZW50ZXIgZ2FwLTEuNSByb3VuZGVkLWxn
IGJvcmRlciBib3JkZXItWyMyMjMwNGFdIHB4LTIuNSBweS0xLjUgdGV4dC14cyBob3ZlcjpiZy1bIzE0MWQyZV0iCiAgICAgICAg
ICA+CiAgICAgICAgICAgIDxMaXN0IGNsYXNzTmFtZT0iaC0zLjUgdy0zLjUiIC8+IExpc3RhCiAgICAgICAgICA8L2J1dHRvbj4K
ICAgICAgICA8L2Rpdj4KCiAgICAgICAgPEVwZ1RpbWVsaW5lCiAgICAgICAgICBjaGFubmVscz17dmlzaWJsZX0KICAgICAgICAg
IHNlbGVjdGVkSWQ9e3NlbGVjdGVkPy5pZCA/PyBudWxsfQogICAgICAgICAgb25TZWxlY3Q9e3NldFNlbGVjdGVkfQogICAgICAg
ICAgb25QaWNrPXtwaWNrfQogICAgICAgICAgb25QbGF5PXtlbmxhcmdlfQogICAgICAgICAgcHhQZXJNaW49e3B4UGVyTWlufQog
ICAgICAgICAgc3RhcnRNcz17c3RhcnRNc30KICAgICAgICAgIG1pbnV0ZXM9e01JTlVURVN9CiAgICAgICAgLz4KICAgICAgPC9z
ZWN0aW9uPgogICAgPC9kaXY+CiAgKTsKfQo=
'@
Edit-File 'src/components/tv/EpgTimeline.tsx' @'
onSelect: (c: Channel) => void;
'@ @'
onSelect: (c: Channel) => void;
  onPick?: (c: Channel) => void;
'@ 'onPick?:'
Edit-File 'src/components/tv/EpgTimeline.tsx' @'
export function EpgTimeline({ channels, selectedId, onSelect, onPlay, pxPerMin, startMs, minutes }: Props) {
'@ @'
export function EpgTimeline({ channels, selectedId, onSelect, onPick, onPlay, pxPerMin, startMs, minutes }: Props) {
'@ 'onSelect, onPick, onPlay'
Edit-File 'src/components/tv/EpgTimeline.tsx' @'
onClick={() => onSelect(ch)}
'@ @'
onClick={() => (onPick ?? onSelect)(ch)}
'@ '(onPick ?? onSelect)(ch)'
Edit-File 'src/components/tv/EpgTimeline.tsx' @'
onPlay(channels[i]);
'@ @'
(onPick ?? onPlay)(channels[i]);
'@ '(onPick ?? onPlay)(channels[i])'

# ---- 4) Formato de TV en vivo: TS primero (o el que funciono la ultima vez)
if (-not ((Get-Content (Join-Path $root "src\hooks\usePlayer.ts") -Raw) -match "const my = \+\+seq")) {
  Write-Host "  ! usePlayer.ts no es la version v3 (aplica update-audio2.ps1 primero); se omite el orden de formatos" -ForegroundColor Yellow
} else {
Edit-File 'src/hooks/usePlayer.ts' @'
function buildCandidates(ch: Channel): Source[] {
'@ @'
// Formato preferido para TV en vivo: el que funciono la ultima vez en ese servidor.
// Sin dato previo, MPEG-TS primero (casi todos los paneles Xtream lo sirven y HLS suele
// tardar o no existir, lo que anade segundos de espera antes del siguiente intento).
const PREF_PREFIX = "streambox-fmt:";
function hostOf(u: string): string {
  try { return new URL(u).host; } catch { return ""; }
}
function readPref(host: string): EngineKind | null {
  try {
    const v = localStorage.getItem(PREF_PREFIX + host);
    return v === "ts" || v === "hls" ? v : null;
  } catch { return null; }
}
function writePref(host: string, kind: EngineKind) {
  try { if (host && (kind === "ts" || kind === "hls")) localStorage.setItem(PREF_PREFIX + host, kind); } catch {}
}
function preferTs(urls: string[], ch: Channel): string[] {
  if (ch.category !== "live") return urls;
  const pref = readPref(hostOf(ch.url)) ?? "ts";
  const rank = (u: string) => {
    const k = detectKind(u);
    return k === pref ? 0 : k === "ts" || k === "hls" ? 1 : 2;
  };
  return [...urls].sort((a, b) => rank(a) - rank(b));
}

function buildCandidates(ch: Channel): Source[] {
'@ 'streambox-fmt:'
Edit-File 'src/hooks/usePlayer.ts' @'
const direct = Array.from(new Set(urls));
'@ @'
const direct = preferTs(Array.from(new Set(urls)), ch);
'@ 'preferTs(Array.from'
Edit-File 'src/hooks/usePlayer.ts' @'
setState((s) => ({ ...s, engine: kind }));
'@ @'
setState((s) => ({ ...s, engine: kind }));
      // Recuerda el formato que funciona en este servidor (solo si ESTE intento llega a reproducir)
      if (isLive && !src.tx && (kind === "ts" || kind === "hls")) {
        video.addEventListener("playing", () => { if (my === seq) writePref(hostOf(src.url), kind); }, { once: true });
      }
'@ 'writePref(hostOf(src.url)'
}

# ---- 5) Navegacion por flechas en las vistas nuevas
Edit-File 'src/hooks/useSpatialNav.ts' @'
const SELECTOR = '[data-focusable="true"]';
'@ @'
const SELECTOR = '[data-focusable="true"], [data-sbfocus="1"]';
'@ 'data-sbfocus'
Edit-File 'src/hooks/useSpatialNav.ts' @'
if (e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
'@ @'
if (e.defaultPrevented || e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
'@ 'e.defaultPrevented'

# ---- 6) EPG: usa appFetch (Tauri) si existe, si no el proxy
Replace-Region 'src/services/epg/guide.ts' 'async function httpGet(url: string): Promise<Response> {' '// Cola de concurrencia limitada' @'
// Si existe src/services/net.ts (Fase 2 de Tauri: appFetch) se usa; si no, el proxy de siempre.
const netModules = import.meta.glob("../net.ts");

async function httpGet(url: string): Promise<Response> {
  const load = netModules["../net.ts"];
  if (load) {
    try {
      const m: any = await load();
      if (typeof m.appFetch === "function") return await m.appFetch(url, { headers: { Accept: "*/*" } });
    } catch {}
  }
  return fetch(await proxify(url, "playlist"));
}

'@ 'import.meta.glob'

Write-Host ""
Write-Host "Listo. Comprueba tipos y arranca:" -ForegroundColor Green
Write-Host "  npm run build"
Write-Host "  npm start   (o npm run server + npx tauri dev)"
Write-Host "Prueba: TV en vivo -> un clic en un canal (suena en la miniatura) -> otro clic (teatro) -> Esc (vuelve a la miniatura)." -ForegroundColor Cyan
