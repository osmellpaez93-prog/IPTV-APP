<#
  StreamBox - fix-fase4.ps1
  Ejecutalo DESPUES de update-fase4.ps1. Corrige errores del script de la fase 4:
    - restaura la busqueda/descarga de subtitulos (OpenSubtitles) en el servidor
    - las series vuelven a abrir su detalle al pulsarlas
    - "continuar viendo" ya no guarda el progreso en la pelicula equivocada
    - evita errores falsos de "no responde" en peliculas lentas
    - tipos para que "npm run build" compile
  Uso (raiz del repo):  powershell -ExecutionPolicy Bypass -File .\fix-fase4.ps1
  Guarda .bak de los archivos que cambia.
#>
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root "src\hooks\useSpatialNav.ts"))) {
    Write-Host "Primero ejecuta update-fase4.ps1 (no encuentro src\hooks\useSpatialNav.ts)." -ForegroundColor Red
    return
}
Write-Host "Aplicando correcciones en: $root" -ForegroundColor Cyan
$utf8 = New-Object System.Text.UTF8Encoding($false)
$backedUp = @{}

function Norm([string]$s) { return $s.Replace("`r`n", "`n") }

function Edit-File {
    param([string]$Rel, [string]$Old, [string]$New)
    $full = Join-Path $root $Rel
    if (-not (Test-Path $full)) { Write-Host "  ! No existe $Rel" -ForegroundColor Yellow; return }
    $t = Norm ([System.IO.File]::ReadAllText($full))
    $Old = Norm $Old; $New = Norm $New
    if ($t.Contains($New) -and -not $New.Contains($Old)) { Write-Host "  = ya aplicado en $Rel" -ForegroundColor DarkGray; return }
    if (-not $t.Contains($Old)) { Write-Host "  ! No encontre el texto a cambiar en $Rel (avisame): $($Old.Substring(0, [Math]::Min(60, $Old.Length)))" -ForegroundColor Yellow; return }
    if (-not $backedUp.ContainsKey($full)) { Copy-Item $full "$full.fix.bak" -Force; $backedUp[$full] = $true }
    $i = $t.IndexOf($Old)
    $t = $t.Substring(0, $i) + $New + $t.Substring($i + $Old.Length)
    [System.IO.File]::WriteAllText($full, $t, $utf8)
    Write-Host "  + $Rel" -ForegroundColor Green
}

function Write-New {
    param([string]$Rel, [string]$Content)
    $full = Join-Path $root $Rel
    if (Test-Path $full) { Copy-Item $full "$full.fix.bak" -Force }
    [System.IO.File]::WriteAllText($full, (Norm $Content) + "`n", $utf8)
    Write-Host "  + $Rel (reescrito)" -ForegroundColor Green
}

Write-New 'src/hooks/useHistory.ts' @'
import { useCallback } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { db } from "../db";
import type { Channel, WatchHistory } from "../types";

export interface ResumeItem {
  history: WatchHistory;
  channel: Channel;
  percent: number;
}

/** "Continuar viendo": empezados y no terminados, mas recientes primero.
 *  Usa la copia guardada en el historial (sirve tambien para episodios de series,
 *  que no existen en la tabla de canales). */
export function useContinueWatching(limit = 14): ResumeItem[] {
  const rows = useLiveQuery(async () => {
    const hist = await db.history.orderBy("updatedAt").reverse().limit(limit * 3).toArray();
    const usable = hist.filter((h) => h.duration > 0 && h.position > 30 && h.position / h.duration < 0.97);
    const missing = usable.filter((h) => !h.item);
    const found = missing.length ? await db.channels.bulkGet(missing.map((h) => h.id)) : [];
    const byId = new Map<string, Channel | undefined>(missing.map((h, i) => [h.id, found[i]]));
    const out: ResumeItem[] = [];
    for (const h of usable) {
      const ch = h.item ?? byId.get(h.id);
      if (ch) out.push({ history: h, channel: ch, percent: Math.min(99, (h.position / h.duration) * 100) });
    }
    return out.slice(0, limit);
  }, [limit]);
  return rows ?? [];
}

export function useRemoveResume() {
  return useCallback((id: string) => { void db.history.delete(id).catch(() => {}); }, []);
}

'@

Edit-File 'src/types/index.ts' @'
  updatedAt: number;
}

export interface Settings
'@ @'
  updatedAt: number;
  item?: Channel; // copia reproducible: permite continuar episodios de series
}

export interface Settings
'@

Edit-File 'src/store/index.ts' @'
play: (c, list) => set({ nowPlaying: c, queue: list && list.length ? list : [c] }),
'@ @'
play: (c, list) =>
        set(c.seriesId ? { openSeries: c } : { nowPlaying: c, queue: list && list.length ? list : [c] }),
'@

Edit-File 'src/hooks/usePlayer.ts' @'
channelRef.current = channel;
'@ @'
useEffect(() => { channelRef.current = channel; });
'@

Edit-File 'src/hooks/usePlayer.ts' @'
name: ch.name, logo: ch.logo, group: ch.group,
'@ @'
item: ch,
'@

Edit-File 'src/hooks/usePlayer.ts' @'
playlistId: ch.playlistId, category: ch.category,
'@ @'

'@

Edit-File 'src/hooks/usePlayer.ts' @'
const onWaiting = () => {
'@ @'
const onWaiting = () => {
      if (!isLive) return;
'@

Edit-File 'src/hooks/usePlayer.ts' @'
isLive ? 14000 : 22000
'@ @'
isLive ? 14000 : 60000
'@

Edit-File 'src/hooks/usePlayer.ts' @'
setState((s) => ({ ...s, blocked: err.name === "NotAllowedError", loading: false }));
'@ @'
if (err.name === "NotAllowedError") clearWatchdog();
            setState((s) => ({ ...s, blocked: err.name === "NotAllowedError", loading: false }));
'@

Edit-File 'src/components/Layout.tsx' @'
bg-brand/18
'@ @'
bg-brand/20
'@

Edit-File 'src/components/Layout.tsx' @'
bg-iris/14
'@ @'
bg-iris/15
'@

Edit-File 'server/index.js' @'
app.get("/health", (_req, res) => res.json({ ok: true, uptime: process.uptime() }));
'@ @'
app.get("/health", (_req, res) => res.json({ ok: true, uptime: process.uptime() }));

// ---------------------------------------------------------------- OpenSubtitles
app.use("/api", express.json({ limit: "1mb" }));

const OS_API = "https://api.opensubtitles.com/api/v1";
const OS_UA = "StreamBox v0.1";
const osTokens = new Map();

const osHeaders = (apiKey, extra = {}) => ({
  "Api-Key": apiKey,
  "User-Agent": OS_UA,
  Accept: "application/json",
  "Content-Type": "application/json",
  ...extra,
});

function decodeText(buf) {
  const utf8 = new TextDecoder("utf-8").decode(buf);
  if (!utf8.includes("\uFFFD")) return utf8;
  return new TextDecoder("windows-1252").decode(buf);
}

function srtToVtt(srt) {
  const text = srt.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n").trim();
  return "WEBVTT\n\n" + text.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, "$1.$2") + "\n";
}

async function osLogin(apiKey, username, password) {
  const key = apiKey + ":" + username;
  const cached = osTokens.get(key);
  if (cached && Date.now() - cached.at < 20 * 3600 * 1000) return cached;
  const r = await fetch(`${OS_API}/login`, {
    method: "POST",
    headers: osHeaders(apiKey),
    body: JSON.stringify({ username, password }),
  });
  const d = await r.json().catch(() => ({}));
  if (!r.ok || !d.token) {
    const err = new Error(d.message || "Usuario o contrasena de OpenSubtitles incorrectos.");
    err.status = r.ok ? 401 : r.status;
    throw err;
  }
  const entry = { token: d.token, host: d.base_url || "api.opensubtitles.com", at: Date.now() };
  osTokens.set(key, entry);
  return entry;
}

app.post("/api/subs/search", async (req, res) => {
  const { apiKey, query, year, languages, season, episode } = req.body || {};
  if (!apiKey) return res.status(400).json({ error: "Falta la API key de OpenSubtitles (en Ajustes)." });
  if (!query) return res.status(400).json({ error: "Escribe el titulo a buscar." });

  const p = new URLSearchParams();
  p.set("query", String(query).toLowerCase());
  if (languages) p.set("languages", String(languages).toLowerCase());
  if (season && episode) {
    p.set("season_number", String(season));
    p.set("episode_number", String(episode));
    p.set("type", "episode");
  } else {
    p.set("type", "movie");
    if (year) p.set("year", String(year));
  }
  p.set("order_by", "download_count");
  const qs = new URLSearchParams([...p.entries()].sort(([a], [b]) => a.localeCompare(b))).toString();

  try {
    const r = await fetch(`${OS_API}/subtitles?${qs}`, { headers: osHeaders(apiKey) });
    const data = await r.json().catch(() => ({}));
    if (!r.ok) return res.status(r.status).json({ error: data.message || `OpenSubtitles respondio ${r.status}` });
    const items = (data.data || [])
      .map((d) => {
        const a = d.attributes || {};
        const f = (a.files || [])[0] || {};
        return {
          fileId: f.file_id,
          release: a.release || f.file_name || a.feature_details?.title || "",
          language: a.language || "",
          downloads: a.download_count || 0,
          hearingImpaired: !!a.hearing_impaired,
          trusted: !!a.from_trusted,
          ai: !!a.ai_translated,
          title: a.feature_details?.title,
          year: a.feature_details?.year,
        };
      })
      .filter((x) => x.fileId);
    res.json({ items });
  } catch (e) {
    res.status(502).json({ error: "No se pudo contactar con OpenSubtitles: " + e.message });
  }
});

app.post("/api/subs/download", async (req, res) => {
  const { apiKey, username, password, fileId } = req.body || {};
  if (!apiKey || !fileId) return res.status(400).json({ error: "Faltan datos (API key o subtitulo)." });
  try {
    let host = "api.opensubtitles.com";
    let auth = {};
    if (username && password) {
      const l = await osLogin(apiKey, username, password);
      host = l.host;
      auth = { Authorization: `Bearer ${l.token}` };
    }
    const r = await fetch(`https://${host}/api/v1/download`, {
      method: "POST",
      headers: osHeaders(apiKey, auth),
      body: JSON.stringify({ file_id: Number(fileId), sub_format: "srt" }),
    });
    const d = await r.json().catch(() => ({}));
    if (!r.ok || !d.link) {
      return res.status(r.ok ? 502 : r.status).json({ error: d.message || `OpenSubtitles respondio ${r.status}`, remaining: d.remaining });
    }
    const f = await fetch(d.link, { headers: { "User-Agent": OS_UA } });
    if (!f.ok) return res.status(502).json({ error: "No se pudo bajar el archivo de subtitulos." });
    const text = decodeText(Buffer.from(await f.arrayBuffer()));
    res.json({ vtt: srtToVtt(text), remaining: d.remaining, fileName: d.file_name });
  } catch (e) {
    res.status(e.status || 502).json({ error: e.message });
  }
});
'@


Write-Host ""
Write-Host "Listo. Ahora comprueba que compila y reinicia:" -ForegroundColor Green
Write-Host "  npm run build      (si hay errores de TypeScript, pegamelos)"
Write-Host "  npm start"