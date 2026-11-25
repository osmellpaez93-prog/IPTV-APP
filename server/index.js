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

const app = express();
const PORT = process.env.PORT || 3001;
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DIST = path.join(__dirname, "..", "dist");
const MAX_REDIRECTS = 5;
const UA_VLC = "VLC/3.0.20 LibVLC/3.0.20";

app.use(cors({ exposedHeaders: ["Content-Range", "Accept-Ranges", "Content-Length"], allowedHeaders: ["Range", "Content-Type", "Accept"] }));
app.get("/health", (_req, res) => res.json({ ok: true, uptime: process.uptime() }));

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

for (const kind of ["playlist", "stream", "image"]) {
  app.get(`/proxy/${kind}`, makeHandler(kind));
  app.head(`/proxy/${kind}`, makeHandler(kind));
}

if (existsSync(DIST)) {
  app.use(express.static(DIST));
  app.get("*", (_req, res) => res.sendFile(path.join(DIST, "index.html")));
}

app.listen(PORT, () => { console.log(`StreamBox proxy escuchando en http://localhost:${PORT}`); });
