// Proxy StreamBox: evita CORS y mixed content (HTTP dentro de HTTPS).
// - Sigue redirecciones en el servidor (el navegador nunca ve la URL original).
// - Reescribe manifiestos HLS para que segmentos y claves pasen por el proxy.
// - Soporta Range y streaming. En produccion sirve tambien dist/.
import express from "express";
import cors from "cors";
import path from "node:path";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { request as httpRequest } from "node:http";
import { request as httpsRequest } from "node:https";
import { spawn } from "node:child_process";

const app = express();
const PORT = process.env.PORT || 3001;
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DIST = path.join(__dirname, "..", "dist");
const MAX_REDIRECTS = 5;
const UA_VLC = "VLC/3.0.20 LibVLC/3.0.20";

app.use(cors({ exposedHeaders: ["Content-Range", "Accept-Ranges", "Content-Length"], allowedHeaders: ["Range", "Content-Type", "Accept"] }));
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

const toProxy = (kind, absoluteUrl) => `/proxy/${kind}?url=${encodeURIComponent(absoluteUrl)}`;

function rewriteHls(text, base) {
  const abs = (u) => {
    if (!u) return u;
    if (/^data:/i.test(u)) return u;
    if (u.startsWith("/proxy/")) return u;
    try { return toProxy("stream", new URL(u, base).toString()); } catch { return u; }
  };
  return text.split(/\r?\n/).map((line) => {
    const t = line.trim();
    if (!t) return line;
    if (t.startsWith("#")) return line.replace(/URI="([^"]+)"/g, (_m, u) => `URI="${abs(u)}"`);
    return abs(t);
  }).join("\n");
}

function makeHandler(kind) {
  return (req, res) => {
    const target = req.query.url;
    if (!target || typeof target !== "string") return res.status(400).json({ error: "Missing url query" });

    let current = null;
    let finished = false;
    res.on("close", () => { if (!finished && current) current.destroy(); });

    const fail = (code, msg) => { finished = true; if (!res.headersSent) res.status(code).json({ error: msg }); else res.end(); };

    const go = (urlStr, hops) => {
      let parsed;
      try { parsed = new URL(urlStr); } catch { return fail(400, "Invalid url"); }
      if (!/^https?:$/.test(parsed.protocol)) return fail(400, "Unsupported protocol");

      const isHttps = parsed.protocol === "https:";
      const headers = { "User-Agent": UA_VLC, Accept: "*/*", "Accept-Encoding": "identity", Connection: "keep-alive" };
      if (req.headers.range) headers.Range = req.headers.range;

      current = (isHttps ? httpsRequest : httpRequest)(
        { method: req.method === "HEAD" ? "HEAD" : "GET", hostname: parsed.hostname, port: parsed.port || (isHttps ? 443 : 80),
          path: parsed.pathname + parsed.search, headers, timeout: kind === "playlist" ? 180000 : 30000 },
        (upRes) => {
          const code = upRes.statusCode || 200;
          if (kind === "stream" && (code >= 400 || code < 200)) console.warn("[proxy] stream HTTP", code, parsed.host + parsed.pathname.replace(/\/[^/]+\/[^/]+\/(\d+)/, "/***/***/$1"));

          if ([301, 302, 303, 307, 308].includes(code) && upRes.headers.location) {
            upRes.resume();
            if (hops >= MAX_REDIRECTS) return fail(508, "Too many redirects");
            return go(new URL(upRes.headers.location, parsed).toString(), hops + 1);
          }

          const ct = String(upRes.headers["content-type"] || "").toLowerCase();

          // Un .ts/.m3u8 que devuelve HTML suele ser una pagina de error/login.
          if (kind === "stream" && ct.includes("text/html")) {
            upRes.resume();
            return fail(502, "El servidor devolvio una pagina HTML en lugar del stream (credenciales o limite de conexiones).");
          }

          const looksLikeManifest = kind === "stream" && (ct.includes("mpegurl") || /\.m3u8?$/i.test(parsed.pathname));

          if (looksLikeManifest && req.method !== "HEAD") {
            const chunks = [];
            upRes.on("data", (c) => chunks.push(c));
            upRes.on("end", () => {
              finished = true;
              const text = Buffer.concat(chunks).toString("utf8");
              const body = text.includes("#EXT-X-") ? rewriteHls(text, parsed) : text;
              res.status(code);
              res.setHeader("Content-Type", ct || "application/vnd.apple.mpegurl");
              res.setHeader("Cache-Control", "no-store");
              res.setHeader("Content-Length", Buffer.byteLength(body));
              res.end(body);
            });
            upRes.on("error", () => fail(502, "Upstream error"));
            return;
          }

          for (const h of ["content-type", "content-length", "content-range", "accept-ranges", "etag", "last-modified"]) {
            if (upRes.headers[h]) res.setHeader(h, upRes.headers[h]);
          }
          if (kind === "image") res.setHeader("Cache-Control", "public, max-age=86400");
          res.status(code);
          upRes.pipe(res);
          upRes.on("error", () => { finished = true; res.end(); });
          res.on("finish", () => { finished = true; });
        }
      );

      current.on("timeout", () => current.destroy(new Error("Upstream timeout")));
      current.on("error", (err) => {
        const why = err.code || (err.errors && err.errors.map((e) => `${e.code} ${e.address}:${e.port}`).join(", ")) || err.message || "desconocido";
        console.error("[proxy] fallo:", why, parsed.host);
        fail(502, "No se pudo conectar con el servidor: " + why);
      });
      current.end();
    };

    go(target, 0);
  };
}

// ---------------------------------------------------------------- transcodificacion de audio (ffmpeg)
// Muchos canales llevan audio AC-3 / E-AC-3, que Chrome y Edge no reproducen.
// Copiamos el video tal cual y convertimos solo el audio a AAC. Requiere ffmpeg en el PATH
// (o la variable FFMPEG_PATH). Maximo 4 transcodificaciones simultaneas.
//   fmt=mp4 (por defecto): MP4 fragmentado, lo reproduce el <video> nativo (sin MSE)
//   fmt=ts               : MPEG-TS para mpegts.js
const FFMPEG = process.env.FFMPEG_PATH || "ffmpeg";
let ffActive = 0;

app.get("/proxy/ffmpeg", (_req, res) => {
  let out = "";
  const p = spawn(FFMPEG, ["-version"], { windowsHide: true });
  p.on("error", () => { if (!res.headersSent) res.json({ available: false }); });
  if (p.stdout) p.stdout.on("data", (d) => { out += d.toString(); });
  p.on("close", (code) => { if (!res.headersSent) res.json({ available: code === 0, version: out.split("\n")[0] }); });
});

app.get("/proxy/transcode", (req, res) => {
  const target = req.query.url;
  if (!target || typeof target !== "string") return res.status(400).json({ error: "Missing url query" });
  let parsed;
  try { parsed = new URL(target); } catch { return res.status(400).json({ error: "Invalid url" }); }
  if (!/^https?:$/.test(parsed.protocol)) return res.status(400).json({ error: "Unsupported protocol" });
  if (ffActive >= 4) return res.status(429).json({ error: "Demasiadas transcodificaciones simultaneas" });

  const fmt = req.query.fmt === "ts" ? "ts" : "mp4";
  const output = fmt === "mp4"
    ? ["-movflags", "frag_keyframe+empty_moov+default_base_moof", "-f", "mp4", "pipe:1"]
    : ["-flush_packets", "1", "-f", "mpegts", "pipe:1"];

  const args = [
    "-hide_banner", "-loglevel", "error", "-nostdin",
    "-user_agent", UA_VLC,
    "-fflags", "+genpts+discardcorrupt",
    "-probesize", "1500000", "-analyzeduration", "2000000",
    "-reconnect", "1", "-reconnect_streamed", "1", "-reconnect_delay_max", "5",
    "-i", target,
    "-map", "0:v:0?", "-map", "0:a:0?",
    "-c:v", "copy", "-c:a", "aac", "-b:a", "160k", "-ac", "2",
    ...output,
  ];

  const ff = spawn(FFMPEG, args, { stdio: ["ignore", "pipe", "pipe"], windowsHide: true });
  ffActive++;
  let started = false;
  let done = false;
  let tail = "";
  const release = () => { if (!done) { done = true; ffActive--; } };

  ff.on("error", (e) => {
    release();
    if (!res.headersSent) res.status(501).json({ error: e.code === "ENOENT" ? "ffmpeg no esta instalado" : e.message });
    else res.end();
  });
  if (ff.stderr) ff.stderr.on("data", (d) => { tail = (tail + d.toString()).slice(-400); });
  if (ff.stdout) {
    ff.stdout.on("data", (chunk) => {
      if (!started) {
        started = true;
        res.status(200);
        res.setHeader("Content-Type", fmt === "mp4" ? "video/mp4" : "video/mp2t");
        res.setHeader("Cache-Control", "no-store");
      }
      if (!res.write(chunk)) {
        ff.stdout.pause();
        res.once("drain", () => ff.stdout.resume());
      }
    });
  }
  ff.on("close", () => {
    release();
    if (!started && !res.headersSent) res.status(502).json({ error: "ffmpeg: " + (tail.trim() || "sin salida") });
    else res.end();
  });
  res.on("close", () => { try { ff.kill("SIGKILL"); } catch {} });
});
for (const kind of ["playlist", "stream", "image"]) {
  app.get(`/proxy/${kind}`, makeHandler(kind));
  app.head(`/proxy/${kind}`, makeHandler(kind));
}

if (existsSync(DIST)) {
  app.use(express.static(DIST));
  app.get("*", (_req, res) => res.sendFile(path.join(DIST, "index.html")));
}

app.listen(PORT, () => { console.log(`StreamBox proxy escuchando en http://localhost:${PORT}`); });
