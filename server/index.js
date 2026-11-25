// Proxy minimo para evitar CORS y mixed content (HTTP dentro de HTTPS).
// - Sigue redirecciones en el servidor (el navegador nunca ve la URL original).
// - Reescribe manifiestos HLS (.m3u8) para que segmentos y claves tambien pasen por el proxy.
// - Soporta Range. En produccion tambien sirve la carpeta dist/.
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
const DEFAULT_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) StreamBox/0.1";

app.use(cors({ exposedHeaders: ["Content-Range", "Accept-Ranges", "Content-Length"] }));
app.get("/health", (_req, res) => res.json({ ok: true }));

const toProxy = (kind, absoluteUrl) => `/proxy/${kind}?url=${encodeURIComponent(absoluteUrl)}`;

function rewriteHls(text, base) {
  const abs = (u) => {
    if (/^data:/i.test(u)) return u;
    try {
      return toProxy("stream", new URL(u, base).toString());
    } catch {
      return u;
    }
  };
  return text
    .split(/\r?\n/)
    .map((line) => {
      const t = line.trim();
      if (!t) return line;
      if (t.startsWith("#")) return line.replace(/URI="([^"]+)"/g, (_m, u) => `URI="${abs(u)}"`);
      return abs(t);
    })
    .join("\n");
}

function makeHandler(kind) {
  return (req, res) => {
    const target = req.query.url;
    if (!target || typeof target !== "string") return res.status(400).json({ error: "Missing url query" });

    let current = null;
    // Usar res (no req): en Node >= 16 req emite 'close' nada mas leer la peticion.
    res.on("close", () => current && current.destroy());

    const fail = (code, msg) => {
      if (!res.headersSent) res.status(code).json({ error: msg });
      else res.end();
    };

    const go = (urlStr, hops) => {
      let parsed;
      try {
        parsed = new URL(urlStr);
      } catch {
        return fail(400, "Invalid url");
      }
      if (!/^https?:$/.test(parsed.protocol)) return fail(400, "Unsupported protocol");

      const isHttps = parsed.protocol === "https:";
      const headers = {
        "User-Agent": "VLC/3.0.20 LibVLC/3.0.20",
        Accept: "*/*",
        "Accept-Encoding": "identity",
      };
      if (req.headers.range) headers.Range = req.headers.range;

      current = (isHttps ? httpsRequest : httpRequest)(
        {
          method: req.method === "HEAD" ? "HEAD" : "GET",
          hostname: parsed.hostname,
          port: parsed.port || (isHttps ? 443 : 80),
          path: parsed.pathname + parsed.search,
          headers,
          timeout: kind === "playlist" ? 180000 : 20000,
        },
        (upRes) => {
          const code = upRes.statusCode || 200;

          if ([301, 302, 303, 307, 308].includes(code) && upRes.headers.location) {
            upRes.resume();
            if (hops >= MAX_REDIRECTS) return fail(508, "Too many redirects");
            return go(new URL(upRes.headers.location, parsed).toString(), hops + 1);
          }

          const ct = String(upRes.headers["content-type"] || "").toLowerCase();
          const looksLikeManifest =
            kind === "stream" && (ct.includes("mpegurl") || /\.m3u8?$/i.test(parsed.pathname));

          if (looksLikeManifest && req.method !== "HEAD") {
            const chunks = [];
            upRes.on("data", (c) => chunks.push(c));
            upRes.on("end", () => {
              const text = Buffer.concat(chunks).toString("utf8");
              const body = text.includes("#EXT-X-") ? rewriteHls(text, parsed) : text;
              res.status(code);
              res.setHeader("Content-Type", ct || "application/vnd.apple.mpegurl");
              res.setHeader("Cache-Control", "no-store");
              res.end(body);
            });
            upRes.on("error", () => fail(502, "Upstream error"));
            return;
          }

          for (const h of ["content-type", "content-length", "content-range", "accept-ranges", "etag", "last-modified"]) {
            if (upRes.headers[h]) res.setHeader(h, upRes.headers[h]);
          }
          res.status(code);
          upRes.pipe(res);
          upRes.on("error", () => res.end());
        }
      );

      current.on("timeout", () => current.destroy(new Error("Upstream timeout")));
      current.on("error", (err) => {
        const why = err.code || (err.errors && err.errors.map((e) => e.code + " " + e.address + ":" + e.port).join(", ")) || err.message || "desconocido";
        console.error("[proxy] fallo:", why);
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

// Produccion: servir la app compilada
if (existsSync(DIST)) {
  app.use(express.static(DIST));
  app.get("*", (_req, res) => res.sendFile(path.join(DIST, "index.html")));
}

app.listen(PORT, () => {
  console.log(`StreamBox proxy escuchando en http://localhost:${PORT}`);
});
