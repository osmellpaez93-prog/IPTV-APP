<#
  StreamBox - script de instalacion (Fase 1)
  Uso (en la RAIZ de tu repo, en la terminal de Visual Studio / PowerShell):
      powershell -ExecutionPolicy Bypass -File .\setup-streambox.ps1
  Opciones:  -SkipInstall (no ejecuta npm install)   -Force (no pregunta)
  Si un archivo ya existe y es distinto, guarda una copia .bak.
#>
param([switch]$SkipInstall, [switch]$Force)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path

Write-Host ""
Write-Host "StreamBox - se crearan los archivos en:" -ForegroundColor Cyan
Write-Host "  $root"
if (-not $Force) {
    $r = Read-Host "Continuar? (S/N)"
    if ($r -notmatch '^[sSyY]') { Write-Host "Cancelado."; return }
}

function Write-ProjectFile {
    param([string]$RelPath, [string]$Content)
    $full = Join-Path $root $RelPath
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if (-not $Content.EndsWith("`n")) { $Content += "`n" }
    if (Test-Path $full) {
        $old = [System.IO.File]::ReadAllText($full)
        if ($old -ne $Content) { Copy-Item $full "$full.bak" -Force }
    }
    [System.IO.File]::WriteAllText($full, $Content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  + $RelPath" -ForegroundColor Green
}

Write-ProjectFile 'package.json' @'
{
  "name": "streambox",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "server": "node server/index.js",
    "start": "concurrently -n server,web \"npm run server\" \"npm run dev\""
  },
  "dependencies": {
    "@fontsource/inter": "^5.1.0",
    "clsx": "^2.1.1",
    "cors": "^2.8.5",
    "dexie": "^4.0.8",
    "dexie-react-hooks": "^1.1.7",
    "express": "^4.21.0",
    "hls.js": "^1.5.15",
    "lucide-react": "^0.447.0",
    "mpegts.js": "^1.7.3",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.26.2",
    "zustand": "^4.5.5"
  },
  "devDependencies": {
    "@types/react": "^18.3.10",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.2",
    "autoprefixer": "^10.4.20",
    "concurrently": "^9.0.1",
    "postcss": "^8.4.47",
    "tailwindcss": "^3.4.13",
    "typescript": "^5.6.2",
    "vite": "^5.4.8",
    "vite-plugin-pwa": "^0.20.5"
  }
}
'@

Write-ProjectFile '.gitignore' @'
node_modules
dist
*.local
*.bak
.DS_Store
'@

Write-ProjectFile 'README.md' @'
# StreamBox

Reproductor IPTV moderno (PWA). No incluye contenido: cada usuario agrega su propia lista M3U/M3U8.

## Uso

```
npm install
npm start          # proxy (3001) + app (5173)
```

Abre http://localhost:5173. En el movil (misma red wifi): http://IP-DE-TU-PC:5173

## Produccion

```
npm run build
npm run server     # sirve dist/ y el proxy en http://localhost:3001
```

Para instalar la PWA en el movil necesitas HTTPS (un hosting con certificado o un tunel).

## Notas

- El proxy (`server/index.js`) evita CORS y mixed content y reescribe los .m3u8 para que los segmentos pasen por el proxy.
- No lo expongas publicamente sin autenticacion: es un proxy abierto.
'@

Write-ProjectFile 'vite.config.ts' @'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["icons/*.png"],
      manifest: {
        name: "StreamBox",
        short_name: "StreamBox",
        description: "Reproductor IPTV moderno. Trae tu propia lista.",
        theme_color: "#0b0b0f",
        background_color: "#0b0b0f",
        display: "standalone",
        orientation: "any",
        start_url: "/",
        icons: [
          { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
          { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any maskable" },
        ],
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,svg,png,ico,woff2}"],
        navigateFallbackDenylist: [/^\/proxy/, /^\/health/],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/image\.tmdb\.org\//,
            handler: "CacheFirst",
            options: { cacheName: "tmdb-images", expiration: { maxEntries: 300, maxAgeSeconds: 60 * 60 * 24 * 30 } },
          },
        ],
      },
    }),
  ],
  server: {
    host: true,
    port: 5173,
    proxy: {
      "/proxy": "http://localhost:3001",
    },
  },
});
'@

Write-ProjectFile 'tsconfig.json' @'
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src", "vite.config.ts"]
}
'@

Write-ProjectFile 'tailwind.config.js' @'
/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: { DEFAULT: "#0b0b0f", soft: "#14141b", card: "#1a1a23", hover: "#23232f" },
        brand: { DEFAULT: "#e50914", hover: "#ff1f2a" },
        ink: { DEFAULT: "#f5f5f7", muted: "#a1a1aa", dim: "#71717a" },
      },
      fontFamily: { sans: ['"Inter"', "system-ui", "sans-serif"] },
      animation: { "fade-in": "fadeIn .3s ease-out" },
      keyframes: { fadeIn: { "0%": { opacity: 0 }, "100%": { opacity: 1 } } },
    },
  },
  plugins: [],
};
'@

Write-ProjectFile 'postcss.config.js' @'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
'@

Write-ProjectFile 'index.html' @'
<!doctype html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
    <meta name="theme-color" content="#0b0b0f" />
    <meta name="description" content="StreamBox - reproductor IPTV moderno. Trae tu propia lista." />
    <link rel="icon" href="/icons/icon-192.png" />
    <link rel="apple-touch-icon" href="/icons/icon-192.png" />
    <title>StreamBox</title>
  </head>
  <body class="bg-bg text-ink antialiased">
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
'@

Write-ProjectFile 'server/index.js' @'
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
        "User-Agent": req.headers["user-agent"] || DEFAULT_UA,
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
          timeout: 20000,
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
        console.error("[proxy]", err.message);
        fail(502, "Upstream error: " + err.message);
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
'@

Write-ProjectFile 'src/vite-env.d.ts' @'
/// <reference types="vite/client" />
/// <reference types="vite-plugin-pwa/client" />
'@

Write-ProjectFile 'src/index.css' @'
@tailwind base;
@tailwind components;
@tailwind utilities;

html, body, #root {
  height: 100%;
  background: #0b0b0f;
  color: #f5f5f7;
}

*::-webkit-scrollbar { width: 10px; height: 10px; }
*::-webkit-scrollbar-track { background: transparent; }
*::-webkit-scrollbar-thumb { background: #2a2a35; border-radius: 8px; }
*::-webkit-scrollbar-thumb:hover { background: #3a3a48; }

/* Foco muy visible para teclado / mando */
[data-focusable="true"]:focus { outline: none; }
[data-focusable="true"]:focus-visible {
  outline: none;
  box-shadow: 0 0 0 3px rgba(229, 9, 20, 0.75), 0 0 24px rgba(229, 9, 20, 0.35);
  transform: scale(1.02);
  transition: transform .15s ease, box-shadow .15s ease;
  z-index: 5;
}

.skeleton {
  background: linear-gradient(90deg, #1a1a23 0%, #23232f 50%, #1a1a23 100%);
  background-size: 200% 100%;
  animation: shimmer 1.4s linear infinite;
}
@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
'@

Write-ProjectFile 'src/main.tsx' @'
import React from "react";
import ReactDOM from "react-dom/client";
import "@fontsource/inter/400.css";
import "@fontsource/inter/600.css";
import "@fontsource/inter/700.css";
import "./index.css";
import { App } from "./App";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
'@

Write-ProjectFile 'src/App.tsx' @'
import { useEffect } from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { useLiveQuery } from "dexie-react-hooks";
import { db } from "./db";
import { useStore } from "./store";
import { Layout } from "./components/Layout";
import { Home } from "./pages/Home";
import { LiveTV } from "./pages/LiveTV";
import { Movies } from "./pages/Movies";
import { Series } from "./pages/Series";
import { Favorites } from "./pages/Favorites";
import { SearchPage } from "./pages/Search";
import { SettingsPage } from "./pages/Settings";
import { PlaylistManager } from "./pages/PlaylistManager";

export function App() {
  const { activePlaylistId, setActivePlaylistId } = useStore();
  const playlists = useLiveQuery(() => db.playlists.toArray(), []);

  // Mantener siempre una lista activa valida (se recuerda entre sesiones)
  useEffect(() => {
    if (!playlists) return;
    const valid = playlists.some((p) => p.id === activePlaylistId);
    if (!valid) setActivePlaylistId(playlists[0]?.id ?? null);
  }, [playlists, activePlaylistId]);

  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route path="/" element={<Home />} />
          <Route path="/live" element={<LiveTV />} />
          <Route path="/movies" element={<Movies />} />
          <Route path="/series" element={<Series />} />
          <Route path="/favorites" element={<Favorites />} />
          <Route path="/search" element={<SearchPage />} />
          <Route path="/playlists" element={<PlaylistManager />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="*" element={<Home />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
'@

Write-ProjectFile 'src/types/index.ts' @'
export type PlaylistType = "m3u-url" | "m3u-file" | "xtream";

export interface Playlist {
  id: string;
  name: string;
  type: PlaylistType;
  url?: string;          // M3U
  server?: string;       // Xtream
  username?: string;
  password?: string;
  createdAt: number;
  updatedAt: number;
}

export interface Channel {
  id: string;
  playlistId: string;
  name: string;
  logo?: string;
  group?: string;
  tvgId?: string;
  url: string;
  category: "live" | "movies" | "series" | "other";
  streamType?: "live" | "movie" | "series";
  streamId?: string;
  containerExtension?: string;
  rating?: string;
  year?: string;
  plot?: string;
}

export interface Favorite {
  id: string;
  addedAt: number;
}

export interface WatchHistory {
  id: string;
  position: number;
  duration: number;
  updatedAt: number;
}

export interface Settings {
  language: "es" | "en";
  theme: "dark";
  proxyUrl: string;
  tmdbApiKey: string;
  parentalPin: string;
  hiddenCategories: string[];
}
'@

Write-ProjectFile 'src/db/index.ts' @'
import Dexie, { type Table } from "dexie";
import type { Playlist, Channel, Favorite, WatchHistory, Settings } from "../types";

export class StreamBoxDB extends Dexie {
  playlists!: Table<Playlist, string>;
  channels!: Table<Channel, string>;
  favorites!: Table<Favorite, string>;
  history!: Table<WatchHistory, string>;
  settings!: Table<Settings & { id: string }, string>;

  constructor() {
    super("streambox");
    this.version(1).stores({
      playlists: "id, createdAt",
      channels: "id, playlistId, group, category, [playlistId+category]",
      favorites: "id, addedAt",
      history: "id, updatedAt",
      settings: "id",
    });
  }
}

export const db = new StreamBoxDB();

export const DEFAULT_SETTINGS: Settings = {
  language: "es",
  theme: "dark",
  proxyUrl: "/proxy",
  tmdbApiKey: "",
  parentalPin: "",
  hiddenCategories: [],
};

export async function getSettings(): Promise<Settings> {
  const s = await db.settings.get("main");
  if (!s) {
    await db.settings.put({ id: "main", ...DEFAULT_SETTINGS });
    return { ...DEFAULT_SETTINGS };
  }
  const { id, ...rest } = s;
  return { ...DEFAULT_SETTINGS, ...rest };
}

export async function saveSettings(patch: Partial<Settings>) {
  const current = await getSettings();
  await db.settings.put({ id: "main", ...current, ...patch });
}
'@

Write-ProjectFile 'src/store/index.ts' @'
import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Channel } from "../types";

interface UIState {
  sidebarOpen: boolean;
  setSidebarOpen: (v: boolean) => void;
  toggleSidebar: () => void;

  activePlaylistId: string | null;
  setActivePlaylistId: (id: string | null) => void;

  nowPlaying: Channel | null;
  setNowPlaying: (c: Channel | null) => void;
}

export const useStore = create<UIState>()(
  persist(
    (set) => ({
      sidebarOpen: false,
      setSidebarOpen: (v) => set({ sidebarOpen: v }),
      toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),

      activePlaylistId: null,
      setActivePlaylistId: (id) => set({ activePlaylistId: id }),

      nowPlaying: null,
      setNowPlaying: (c) => set({ nowPlaying: c }),
    }),
    {
      name: "streambox-ui",
      // Solo se recuerda la lista activa
      partialize: (s) => ({ activePlaylistId: s.activePlaylistId }),
    }
  )
);
'@

Write-ProjectFile 'src/services/proxy.ts' @'
// Construye URLs que pasan por el proxy Node para evitar CORS / mixed content.
import { getSettings } from "../db";

export async function proxify(url: string, kind: "playlist" | "stream" | "image" = "stream"): Promise<string> {
  if (!url) return url;
  const s = await getSettings();
  const base = (s.proxyUrl || "/proxy").replace(/\/$/, "");
  if (url.startsWith(base + "/")) return url;
  return `${base}/${kind}?url=${encodeURIComponent(url)}`;
}

// Logos http:// no cargan dentro de una pagina https://, los pasamos por el proxy.
export function imgUrl(url?: string): string | undefined {
  if (!url) return undefined;
  if (url.startsWith("http://") && typeof location !== "undefined" && location.protocol === "https:") {
    return `/proxy/image?url=${encodeURIComponent(url)}`;
  }
  return url;
}
'@

Write-ProjectFile 'src/services/playlists.ts' @'
import { db } from "../db";
import type { Channel, Playlist } from "../types";

const CHUNK = 2000;

// Guarda la lista y sus canales de forma atomica (si algo falla, no queda a medias)
export async function savePlaylistWithChannels(playlist: Playlist, channels: Channel[]) {
  await db.transaction("rw", db.playlists, db.channels, async () => {
    await db.channels.where("playlistId").equals(playlist.id).delete();
    for (let i = 0; i < channels.length; i += CHUNK) {
      await db.channels.bulkPut(channels.slice(i, i + CHUNK));
    }
    await db.playlists.put(playlist);
  });
}

export async function deletePlaylist(id: string) {
  await db.transaction("rw", db.playlists, db.channels, async () => {
    await db.channels.where("playlistId").equals(id).delete();
    await db.playlists.delete(id);
  });
}
'@

Write-ProjectFile 'src/services/m3u/parser.ts' @'
/**
 * Parser M3U/M3U8.
 * - Atributos key="value" (tvg-id, tvg-logo, group-title, tvg-name...)
 * - IDs estables (hash de la URL): los favoritos sobreviven a recargar la lista
 * - Clasificacion live / movies / series por URL (/movie/, /series/), grupo y nombre
 */
import type { Channel } from "../../types";
import { proxify } from "../proxy";

const ATTR_RE = /([a-zA-Z0-9_-]+)="([^"]*)"/g;

function parseExtInf(line: string) {
  const attrs: Record<string, string> = {};
  let m: RegExpExecArray | null;
  ATTR_RE.lastIndex = 0;
  while ((m = ATTR_RE.exec(line)) !== null) attrs[m[1].toLowerCase()] = m[2];

  // El nombre va tras la primera coma posterior al ultimo atributo entrecomillado
  const lastQuote = line.lastIndexOf('"');
  const commaIdx = line.indexOf(",", lastQuote >= 0 ? lastQuote : 0);
  const name = (commaIdx >= 0 ? line.slice(commaIdx + 1).trim() : "") || attrs["tvg-name"] || "Sin nombre";
  return { name, attrs };
}

function classify(group: string, name: string, url: string): Channel["category"] {
  const u = url.toLowerCase();
  const g = group.toLowerCase();
  if (/\/series\//.test(u)) return "series";
  if (/\/movie\//.test(u)) return "movies";
  if (/\bs\d{1,2}\s?e\d{1,3}\b/i.test(name) || /(serie|temporada|season)/.test(g)) return "series";
  if (/(pel[ií]cula|movie|vod|film)/.test(g)) return "movies";
  if (/\.(mp4|mkv|avi|mov|wmv)(\?|$)/.test(u)) return "movies";
  return "live";
}

// Hash de 53 bits (cyrb53) para ids estables
function hash(str: string): string {
  let h1 = 0xdeadbeef, h2 = 0x41c6ce57;
  for (let i = 0; i < str.length; i++) {
    const ch = str.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(36);
}

export interface ParseResult {
  channels: Channel[];
  groups: string[];
}

export async function parseM3U(rawText: string, playlistId: string): Promise<ParseResult> {
  const text = rawText.replace(/^\uFEFF/, "");
  const lines = text.split(/\r?\n/);
  const channels: Channel[] = [];
  const groupsSet = new Set<string>();
  const seen = new Map<string, number>();

  let pending: ReturnType<typeof parseExtInf> | null = null;
  let pendingGroup: string | undefined;

  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;

    if (line.startsWith("#EXTINF")) {
      pending = parseExtInf(line);
      continue;
    }
    if (line.startsWith("#EXTGRP")) {
      pendingGroup = line.slice(line.indexOf(":") + 1).trim();
      continue;
    }
    if (line.startsWith("#")) continue;

    if (pending) {
      const group = pending.attrs["group-title"] || pendingGroup || "Sin categoría";
      groupsSet.add(group);

      const base = `${playlistId}:${hash(line)}`;
      const n = (seen.get(base) ?? 0) + 1;
      seen.set(base, n);

      channels.push({
        id: n === 1 ? base : `${base}-${n}`,
        playlistId,
        name: pending.name,
        logo: pending.attrs["tvg-logo"] || undefined,
        group,
        tvgId: pending.attrs["tvg-id"] || undefined,
        url: line,
        category: classify(group, pending.name, line),
      });
      pending = null;
      pendingGroup = undefined;
    }
  }

  if (channels.length === 0) throw new Error("No se encontraron canales. Comprueba que sea una lista M3U valida.");
  return { channels, groups: Array.from(groupsSet).sort((a, b) => a.localeCompare(b)) };
}

export async function loadM3UFromUrl(url: string, playlistId: string): Promise<ParseResult> {
  const proxied = await proxify(url, "playlist");
  let res: Response;
  try {
    res = await fetch(proxied);
  } catch {
    throw new Error("No se pudo conectar con el proxy. Ejecuta 'npm start'.");
  }
  if (!res.ok) throw new Error(`HTTP ${res.status} al descargar la lista`);
  return parseM3U(await res.text(), playlistId);
}

export async function loadM3UFromFile(file: File, playlistId: string): Promise<ParseResult> {
  return parseM3U(await file.text(), playlistId);
}
'@

Write-ProjectFile 'src/hooks/useFavorites.ts' @'
import { useCallback, useMemo } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { db } from "../db";

export function useFavorites() {
  const favs = useLiveQuery(() => db.favorites.toArray(), []);
  const favSet = useMemo(() => new Set((favs ?? []).map((f) => f.id)), [favs]);

  const toggle = useCallback(async (id: string) => {
    const exists = await db.favorites.get(id);
    if (exists) await db.favorites.delete(id);
    else await db.favorites.put({ id, addedAt: Date.now() });
  }, []);

  return { favSet, toggle };
}
'@

Write-ProjectFile 'src/hooks/usePlayer.ts' @'
/**
 * Logica del reproductor:
 *  - hls.js para .m3u8
 *  - mpegts.js para MPEG-TS (.ts o URLs Xtream sin extension) y FLV
 *  - <video> nativo para mp4 y similares
 */
import { useCallback, useEffect, useRef, useState } from "react";
import Hls from "hls.js";
import mpegts from "mpegts.js";
import type { Channel } from "../types";
import { proxify } from "../services/proxy";

type MpegtsPlayer = ReturnType<typeof mpegts.createPlayer>;
type Kind = "hls" | "ts" | "flv" | "native";

export interface PlayerState {
  loading: boolean;
  error: string | null;
  isPlaying: boolean;
  currentTime: number;
  duration: number;
  volume: number;
  muted: boolean;
  playbackRate: number;
  audioTracks: { id: number; label: string }[];
  subtitleTracks: { id: number; label: string }[];
  activeAudio: number;
  activeSubtitle: number;
}

const INITIAL: PlayerState = {
  loading: true,
  error: null,
  isPlaying: false,
  currentTime: 0,
  duration: 0,
  volume: 1,
  muted: false,
  playbackRate: 1,
  audioTracks: [],
  subtitleTracks: [],
  activeAudio: -1,
  activeSubtitle: -1,
};

function detectKind(raw: string): Kind {
  const path = raw.split("?")[0].toLowerCase();
  if (path.endsWith(".m3u8") || /[?&]type=m3u8/i.test(raw)) return "hls";
  if (path.endsWith(".flv")) return "flv";
  // .ts, o formato Xtream sin extension: /user/pass/123 o /live/user/pass/123
  let pathname = path;
  try {
    pathname = new URL(raw).pathname.toLowerCase();
  } catch {}
  if (pathname.endsWith(".ts") || /^\/(live\/)?[^/]+\/[^/]+\/\d+$/.test(pathname)) return "ts";
  return "native";
}

export function usePlayer(channel: Channel | null) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const hlsRef = useRef<Hls | null>(null);
  const tsRef = useRef<MpegtsPlayer | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [state, setState] = useState<PlayerState>(INITIAL);

  const destroyEngines = useCallback(() => {
    hlsRef.current?.destroy();
    hlsRef.current = null;
    if (tsRef.current) {
      try {
        tsRef.current.pause();
        tsRef.current.unload();
        tsRef.current.detachMediaElement();
        tsRef.current.destroy();
      } catch {}
      tsRef.current = null;
    }
  }, []);

  useEffect(() => () => destroyEngines(), [destroyEngines]);

  // Cargar stream al cambiar de canal (o al reintentar)
  useEffect(() => {
    const video = videoRef.current;
    if (!video || !channel) return;

    let cancelled = false;
    destroyEngines();
    video.removeAttribute("src");
    video.load();
    setState((s) => ({ ...s, loading: true, error: null, audioTracks: [], subtitleTracks: [], currentTime: 0, duration: 0 }));

    const fail = (msg: string) => setState((s) => ({ ...s, error: msg, loading: false }));

    (async () => {
      try {
        const kind = detectKind(channel.url);
        const url = await proxify(channel.url, "stream");
        if (cancelled) return;

        if (kind === "hls") {
          if (Hls.isSupported()) {
            const hls = new Hls({ enableWorker: true });
            hlsRef.current = hls;
            let retries = 0;
            hls.loadSource(url);
            hls.attachMedia(video);
            hls.on(Hls.Events.MANIFEST_PARSED, () => {
              if (cancelled) return;
              const audio = hls.audioTracks.map((t, i) => ({ id: i, label: t.name || t.lang || `Audio ${i + 1}` }));
              const subs = hls.subtitleTracks.map((t, i) => ({ id: i, label: t.name || t.lang || `Sub ${i + 1}` }));
              setState((s) => ({ ...s, audioTracks: audio, subtitleTracks: subs, activeAudio: 0, activeSubtitle: -1 }));
              video.play().catch(() => {});
            });
            hls.on(Hls.Events.ERROR, (_e, data) => {
              if (!data.fatal) return;
              if (data.type === Hls.ErrorTypes.NETWORK_ERROR && retries < 3) {
                retries++;
                hls.startLoad();
              } else if (data.type === Hls.ErrorTypes.MEDIA_ERROR && retries < 3) {
                retries++;
                hls.recoverMediaError();
              } else {
                fail(`Error HLS: ${data.details}`);
              }
            });
          } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
            video.src = url;
            video.play().catch(() => {});
          } else {
            fail("HLS no soportado en este navegador");
          }
        } else if (kind === "ts" || kind === "flv") {
          if (mpegts.isSupported()) {
            const player = mpegts.createPlayer(
              { type: kind === "flv" ? "flv" : "mpegts", url, isLive: true },
              { enableWorker: true, liveBufferLatencyChasing: true }
            );
            tsRef.current = player;
            player.attachMediaElement(video);
            player.load();
            player.on(mpegts.Events.ERROR, (_type: string, detail: string) => fail(`Error TS/FLV: ${detail}`));
            video.play().catch(() => {});
          } else {
            video.src = url;
            video.play().catch(() => {});
          }
        } else {
          video.src = url;
          video.play().catch(() => {});
        }
      } catch (e: any) {
        fail(e?.message || "Error al cargar el stream");
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [channel?.id, reloadKey]);

  // Eventos del <video>
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    const onPlay = () => setState((s) => ({ ...s, isPlaying: true, loading: false }));
    const onPause = () => setState((s) => ({ ...s, isPlaying: false }));
    const onWaiting = () => setState((s) => ({ ...s, loading: true }));
    const onCanPlay = () => setState((s) => ({ ...s, loading: false }));
    const onTime = () =>
      setState((s) => ({ ...s, currentTime: video.currentTime, duration: isFinite(video.duration) ? video.duration : 0 }));
    const onVolume = () => setState((s) => ({ ...s, volume: video.volume, muted: video.muted }));
    const onError = () => {
      if (!video.getAttribute("src") && !hlsRef.current && !tsRef.current) return;
      setState((s) => ({ ...s, error: "Error de reproducción", loading: false }));
    };

    video.addEventListener("play", onPlay);
    video.addEventListener("pause", onPause);
    video.addEventListener("waiting", onWaiting);
    video.addEventListener("canplay", onCanPlay);
    video.addEventListener("timeupdate", onTime);
    video.addEventListener("volumechange", onVolume);
    video.addEventListener("error", onError);
    return () => {
      video.removeEventListener("play", onPlay);
      video.removeEventListener("pause", onPause);
      video.removeEventListener("waiting", onWaiting);
      video.removeEventListener("canplay", onCanPlay);
      video.removeEventListener("timeupdate", onTime);
      video.removeEventListener("volumechange", onVolume);
      video.removeEventListener("error", onError);
    };
  }, []);

  const actions = {
    playPause: () => {
      const v = videoRef.current;
      if (!v) return;
      if (v.paused) v.play().catch(() => {});
      else v.pause();
    },
    seek: (t: number) => {
      const v = videoRef.current;
      if (v && isFinite(v.duration) && v.duration > 0) v.currentTime = Math.max(0, Math.min(v.duration, t));
    },
    setVolume: (vol: number) => {
      const v = videoRef.current;
      if (v) v.volume = Math.max(0, Math.min(1, vol));
    },
    setMuted: (m: boolean) => {
      const v = videoRef.current;
      if (v) v.muted = m;
    },
    setPlaybackRate: (r: number) => {
      const v = videoRef.current;
      if (v) v.playbackRate = r;
      setState((s) => ({ ...s, playbackRate: r }));
    },
    setAudioTrack: (id: number) => {
      if (hlsRef.current) {
        hlsRef.current.audioTrack = id;
        setState((s) => ({ ...s, activeAudio: id }));
      }
    },
    setSubtitleTrack: (id: number) => {
      if (hlsRef.current) {
        hlsRef.current.subtitleTrack = id;
        setState((s) => ({ ...s, activeSubtitle: id }));
      }
    },
    requestPiP: async () => {
      const v = videoRef.current;
      if (!v) return;
      try {
        if (document.pictureInPictureElement) await document.exitPictureInPicture();
        else if (v.requestPictureInPicture) await v.requestPictureInPicture();
      } catch {}
    },
    retry: () => setReloadKey((k) => k + 1),
  };

  return { videoRef, state, actions };
}
'@

Write-ProjectFile 'src/components/SkeletonLoader.tsx' @'
import { clsx } from "clsx";

export function Skeleton({ className }: { className?: string }) {
  return <div className={clsx("skeleton rounded-lg", className)} />;
}

export function ChannelCardSkeleton() {
  return (
    <div className="flex items-center gap-3 p-3 rounded-lg bg-bg-card">
      <Skeleton className="w-12 h-12 rounded-md shrink-0" />
      <div className="flex-1 space-y-2">
        <Skeleton className="h-4 w-3/4" />
        <Skeleton className="h-3 w-1/2" />
      </div>
    </div>
  );
}

export function PosterSkeleton() {
  return <Skeleton className="aspect-[2/3] w-full" />;
}
'@

Write-ProjectFile 'src/components/Player.tsx' @'
import { useEffect, useRef, useState } from "react";
import {
  Play, Pause, Volume2, VolumeX, Maximize, Minimize,
  Settings, SkipBack, SkipForward, X, Loader2, AlertTriangle,
} from "lucide-react";
import { clsx } from "clsx";
import { usePlayer } from "../hooks/usePlayer";
import type { Channel } from "../types";

interface Props {
  channel: Channel;
  onClose: () => void;
}

const fmt = (s: number) => {
  if (!isFinite(s) || s < 0) return "0:00";
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = Math.floor(s % 60).toString().padStart(2, "0");
  return h > 0 ? `${h}:${m.toString().padStart(2, "0")}:${sec}` : `${m}:${sec}`;
};

export function Player({ channel, onClose }: Props) {
  const { videoRef, state, actions } = usePlayer(channel);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [fullscreen, setFullscreen] = useState(false);
  const [showControls, setShowControls] = useState(true);
  const [showMenu, setShowMenu] = useState(false);
  const hideTimer = useRef<number | null>(null);

  // Auto-ocultar controles mientras se reproduce
  useEffect(() => {
    if (!showControls || showMenu) return;
    hideTimer.current = window.setTimeout(() => {
      if (state.isPlaying) setShowControls(false);
    }, 3500);
    return () => {
      if (hideTimer.current) window.clearTimeout(hideTimer.current);
    };
  }, [showControls, showMenu, state.isPlaying]);

  useEffect(() => {
    const onFs = () => setFullscreen(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", onFs);
    return () => document.removeEventListener("fullscreenchange", onFs);
  }, []);

  const toggleFullscreen = async () => {
    const el = containerRef.current;
    const video = videoRef.current as (HTMLVideoElement & { webkitEnterFullscreen?: () => void }) | null;
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else if (el?.requestFullscreen) {
        await el.requestFullscreen();
        el.focus({ preventScroll: true });
      } else video?.webkitEnterFullscreen?.(); // iPhone
    } catch {}
  };

  // Atajos: solo cuando el propio reproductor tiene el foco (no interfiere con la pagina)
  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.target !== e.currentTarget) return;
    setShowControls(true);
    switch (e.key) {
      case " ":
      case "k":
        e.preventDefault();
        actions.playPause();
        break;
      case "ArrowRight":
        actions.seek(state.currentTime + 10);
        break;
      case "ArrowLeft":
        actions.seek(state.currentTime - 10);
        break;
      case "ArrowUp":
        e.preventDefault();
        actions.setVolume(state.volume + 0.1);
        break;
      case "ArrowDown":
        e.preventDefault();
        actions.setVolume(state.volume - 0.1);
        break;
      case "m":
        actions.setMuted(!state.muted);
        break;
      case "f":
        toggleFullscreen();
        break;
      case "p":
        actions.requestPiP();
        break;
      case "Escape":
        if (!document.fullscreenElement) onClose();
        break;
    }
  };

  const optBtn = (active: boolean) =>
    clsx("text-left text-xs px-2 py-1 rounded-md", active ? "bg-brand text-white" : "hover:bg-bg-hover");

  return (
    <div
      ref={containerRef}
      tabIndex={-1}
      onKeyDown={onKeyDown}
      onMouseMove={() => setShowControls(true)}
      className={clsx(
        "relative bg-black outline-none",
        fullscreen ? "w-screen h-screen" : "aspect-video w-full rounded-xl overflow-hidden"
      )}
    >
      <video
        ref={videoRef}
        className="w-full h-full object-contain bg-black"
        playsInline
        autoPlay
        onClick={() => {
          containerRef.current?.focus({ preventScroll: true });
          setShowControls(true);
        }}
        onDoubleClick={toggleFullscreen}
      />

      {state.loading && !state.error && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/40 pointer-events-none">
          <Loader2 className="w-12 h-12 text-brand animate-spin" />
        </div>
      )}

      {state.error && (
        <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/80 gap-3 p-6 text-center">
          <AlertTriangle className="w-10 h-10 text-brand" />
          <p className="text-ink max-w-md">{state.error}</p>
          <div className="flex gap-2">
            <button onClick={actions.retry} className="px-4 py-2 rounded-lg bg-brand hover:bg-brand-hover text-white font-semibold">
              Reintentar
            </button>
            <button onClick={onClose} className="px-4 py-2 rounded-lg bg-bg-card hover:bg-bg-hover text-ink">
              Cerrar
            </button>
          </div>
        </div>
      )}

      <div
        className={clsx(
          "absolute inset-0 flex flex-col justify-between bg-gradient-to-b from-black/60 via-transparent to-black/80 transition-opacity pointer-events-none",
          showControls ? "opacity-100" : "opacity-0"
        )}
      >
        <div className="flex items-center gap-3 p-3 md:p-4 pointer-events-auto">
          <button onClick={onClose} className="p-2 rounded-full hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-brand" aria-label="Cerrar">
            <X className="w-5 h-5" />
          </button>
          <div className="flex-1 min-w-0">
            <p className="font-semibold truncate">{channel.name}</p>
            {channel.group && <p className="text-xs text-ink-muted truncate">{channel.group}</p>}
          </div>
        </div>

        <div className="p-3 md:p-4 space-y-2 pointer-events-auto">
          {state.duration > 0 && (
            <input
              type="range"
              min={0}
              max={state.duration}
              step={0.1}
              value={state.currentTime}
              onChange={(e) => actions.seek(parseFloat(e.target.value))}
              className="w-full accent-brand"
            />
          )}
          <div className="flex items-center gap-1 md:gap-2">
            {state.duration > 0 && (
              <button onClick={() => actions.seek(state.currentTime - 10)} className="p-2 rounded-full hover:bg-white/10" aria-label="Atrasar 10 s">
                <SkipBack className="w-5 h-5" />
              </button>
            )}
            <button onClick={actions.playPause} className="p-2 rounded-full hover:bg-white/10" aria-label="Reproducir / pausar">
              {state.isPlaying ? <Pause className="w-6 h-6" /> : <Play className="w-6 h-6" />}
            </button>
            {state.duration > 0 && (
              <button onClick={() => actions.seek(state.currentTime + 10)} className="p-2 rounded-full hover:bg-white/10" aria-label="Adelantar 10 s">
                <SkipForward className="w-5 h-5" />
              </button>
            )}

            <button onClick={() => actions.setMuted(!state.muted)} className="p-2 rounded-full hover:bg-white/10" aria-label="Silenciar">
              {state.muted || state.volume === 0 ? <VolumeX className="w-5 h-5" /> : <Volume2 className="w-5 h-5" />}
            </button>
            <input
              type="range"
              min={0}
              max={1}
              step={0.05}
              value={state.muted ? 0 : state.volume}
              onChange={(e) => {
                actions.setMuted(false);
                actions.setVolume(parseFloat(e.target.value));
              }}
              className="w-24 accent-brand hidden sm:block"
            />

            {state.duration > 0 ? (
              <span className="text-xs text-ink-muted ml-2 hidden sm:inline">
                {fmt(state.currentTime)} / {fmt(state.duration)}
              </span>
            ) : (
              <span className="ml-2 text-xs font-semibold text-brand">EN VIVO</span>
            )}

            <div className="flex-1" />

            <div className="relative">
              <button onClick={() => setShowMenu((v) => !v)} className="p-2 rounded-full hover:bg-white/10" aria-label="Ajustes">
                <Settings className="w-5 h-5" />
              </button>
              {showMenu && (
                <div className="absolute right-0 bottom-full mb-2 w-64 max-h-72 overflow-y-auto bg-bg-soft border border-white/10 rounded-lg p-3 shadow-2xl space-y-3">
                  <div>
                    <p className="text-xs text-ink-muted mb-1">Velocidad</p>
                    <div className="flex gap-1 flex-wrap">
                      {[0.5, 0.75, 1, 1.25, 1.5, 2].map((r) => (
                        <button key={r} onClick={() => actions.setPlaybackRate(r)} className={optBtn(state.playbackRate === r)}>
                          {r}x
                        </button>
                      ))}
                    </div>
                  </div>
                  {state.audioTracks.length > 1 && (
                    <div>
                      <p className="text-xs text-ink-muted mb-1">Audio</p>
                      <div className="flex flex-col gap-1">
                        {state.audioTracks.map((t) => (
                          <button key={t.id} onClick={() => actions.setAudioTrack(t.id)} className={optBtn(state.activeAudio === t.id)}>
                            {t.label}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}
                  {state.subtitleTracks.length > 0 && (
                    <div>
                      <p className="text-xs text-ink-muted mb-1">Subtítulos</p>
                      <div className="flex flex-col gap-1">
                        <button onClick={() => actions.setSubtitleTrack(-1)} className={optBtn(state.activeSubtitle === -1)}>
                          Desactivados
                        </button>
                        {state.subtitleTracks.map((t) => (
                          <button key={t.id} onClick={() => actions.setSubtitleTrack(t.id)} className={optBtn(state.activeSubtitle === t.id)}>
                            {t.label}
                          </button>
                        ))}
                      </div>
                    </div>
                  )}
                  <button onClick={actions.requestPiP} className={optBtn(false) + " w-full"}>
                    Picture-in-Picture
                  </button>
                </div>
              )}
            </div>

            <button onClick={toggleFullscreen} className="p-2 rounded-full hover:bg-white/10" aria-label="Pantalla completa">
              {fullscreen ? <Minimize className="w-5 h-5" /> : <Maximize className="w-5 h-5" />}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
'@

Write-ProjectFile 'src/components/ChannelCard.tsx' @'
import { useState } from "react";
import { clsx } from "clsx";
import { Star, Play } from "lucide-react";
import type { Channel } from "../types";
import { imgUrl } from "../services/proxy";

interface Props {
  channel: Channel;
  isFavorite: boolean;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
}

export function ChannelCard({ channel, isFavorite, onToggleFavorite, onPlay }: Props) {
  const [imgError, setImgError] = useState(false);
  const logo = imgUrl(channel.logo);

  return (
    <div
      data-focusable="true"
      tabIndex={0}
      role="button"
      onClick={() => onPlay(channel)}
      onKeyDown={(e) => {
        if (e.target !== e.currentTarget) return;
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onPlay(channel);
        }
      }}
      className="group relative flex items-center gap-3 p-3 rounded-xl bg-bg-card hover:bg-bg-hover cursor-pointer transition-colors animate-fade-in"
    >
      <div className="relative w-12 h-12 rounded-lg bg-bg-soft overflow-hidden shrink-0 flex items-center justify-center">
        {logo && !imgError ? (
          <img src={logo} alt="" loading="lazy" onError={() => setImgError(true)} className="w-full h-full object-contain" />
        ) : (
          <span className="text-ink-muted text-xs font-semibold">{channel.name.slice(0, 2).toUpperCase()}</span>
        )}
        <div className="absolute inset-0 flex items-center justify-center bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity">
          <Play className="w-5 h-5 text-white" fill="white" />
        </div>
      </div>

      <div className="flex-1 min-w-0">
        <p className="font-semibold truncate">{channel.name}</p>
        <p className="text-xs text-ink-muted truncate">{channel.group}</p>
      </div>

      <button
        onClick={(e) => {
          e.stopPropagation();
          onToggleFavorite(channel.id);
        }}
        className="p-2 rounded-full hover:bg-white/10 focus-visible:ring-2 focus-visible:ring-brand"
        aria-label={isFavorite ? "Quitar de favoritos" : "Añadir a favoritos"}
      >
        <Star className={clsx("w-5 h-5", isFavorite ? "text-brand fill-brand" : "text-ink-muted")} />
      </button>
    </div>
  );
}
'@

Write-ProjectFile 'src/components/ChannelGrid.tsx' @'
import { useEffect, useState } from "react";
import { ChannelCard } from "./ChannelCard";
import type { Channel } from "../types";

const PAGE = 120;

interface Props {
  channels: Channel[];
  favSet: Set<string>;
  onToggleFavorite: (id: string) => void;
  onPlay: (c: Channel) => void;
  emptyText?: string;
}

// Renderiza por tandas: evita colgar el navegador con listas de decenas de miles de canales.
// (La virtualizacion completa llega en la Fase 2.)
export function ChannelGrid({ channels, favSet, onToggleFavorite, onPlay, emptyText = "No se encontraron resultados." }: Props) {
  const [limit, setLimit] = useState(PAGE);
  useEffect(() => setLimit(PAGE), [channels]);

  if (channels.length === 0) return <p className="text-ink-muted text-center py-10">{emptyText}</p>;

  return (
    <div className="space-y-4">
      <div className="grid md:grid-cols-2 gap-2">
        {channels.slice(0, limit).map((c) => (
          <ChannelCard key={c.id} channel={c} isFavorite={favSet.has(c.id)} onToggleFavorite={onToggleFavorite} onPlay={onPlay} />
        ))}
      </div>
      {channels.length > limit && (
        <div className="text-center">
          <button
            onClick={() => setLimit((l) => l + PAGE)}
            className="px-5 py-2 rounded-lg bg-bg-card hover:bg-bg-hover font-semibold focus-visible:ring-2 focus-visible:ring-brand"
          >
            Mostrar más ({(channels.length - limit).toLocaleString()} restantes)
          </button>
        </div>
      )}
    </div>
  );
}
'@

Write-ProjectFile 'src/components/Sidebar.tsx' @'
import { NavLink } from "react-router-dom";
import { Home, Tv, Film, Clapperboard, Star, Search, Settings, ListVideo, X } from "lucide-react";
import { clsx } from "clsx";
import { useStore } from "../store";

const items = [
  { to: "/", label: "Inicio", icon: Home },
  { to: "/live", label: "TV en vivo", icon: Tv },
  { to: "/movies", label: "Películas", icon: Film },
  { to: "/series", label: "Series", icon: Clapperboard },
  { to: "/favorites", label: "Favoritos", icon: Star },
  { to: "/search", label: "Buscar", icon: Search },
  { to: "/playlists", label: "Mis listas", icon: ListVideo },
  { to: "/settings", label: "Ajustes", icon: Settings },
];

export function Sidebar() {
  const { sidebarOpen, setSidebarOpen } = useStore();

  return (
    <>
      {sidebarOpen && <div className="lg:hidden fixed inset-0 bg-black/60 z-30" onClick={() => setSidebarOpen(false)} />}

      <aside
        className={clsx(
          "fixed lg:sticky top-0 left-0 h-screen w-64 bg-bg-soft border-r border-white/5 z-40 shrink-0",
          "flex flex-col transition-transform duration-200",
          sidebarOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0"
        )}
      >
        <div className="flex items-center justify-between p-5 border-b border-white/5">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-brand flex items-center justify-center font-bold">S</div>
            <span className="font-bold text-lg tracking-tight">StreamBox</span>
          </div>
          <button onClick={() => setSidebarOpen(false)} className="lg:hidden p-1 rounded hover:bg-white/10" aria-label="Cerrar menú">
            <X className="w-5 h-5" />
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto p-3 space-y-1">
          {items.map((it) => (
            <NavLink
              key={it.to}
              to={it.to}
              end={it.to === "/"}
              data-focusable="true"
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                clsx(
                  "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors",
                  isActive ? "bg-brand/15 text-brand" : "text-ink-muted hover:bg-bg-hover hover:text-ink"
                )
              }
            >
              <it.icon className="w-5 h-5" />
              {it.label}
            </NavLink>
          ))}
        </nav>

        <div className="p-4 text-xs text-ink-dim border-t border-white/5">v0.1 · Fase 1</div>
      </aside>
    </>
  );
}
'@

Write-ProjectFile 'src/components/Layout.tsx' @'
import { Outlet } from "react-router-dom";
import { Menu } from "lucide-react";
import { Sidebar } from "./Sidebar";
import { Player } from "./Player";
import { useStore } from "../store";

export function Layout() {
  const { toggleSidebar, nowPlaying, setNowPlaying } = useStore();

  return (
    <div className="min-h-screen flex">
      <Sidebar />
      <div className="flex-1 min-w-0 flex flex-col">
        <header className="lg:hidden sticky top-0 z-20 bg-bg/80 backdrop-blur border-b border-white/5 px-4 py-3 flex items-center gap-3">
          <button onClick={toggleSidebar} className="p-2 rounded-lg hover:bg-white/10" aria-label="Abrir menú">
            <Menu className="w-5 h-5" />
          </button>
          <div className="flex items-center gap-2">
            <div className="w-7 h-7 rounded-md bg-brand flex items-center justify-center font-bold text-sm">S</div>
            <span className="font-semibold">StreamBox</span>
          </div>
        </header>

        <main className="flex-1 p-4 md:p-6 lg:p-8 max-w-[1600px] w-full mx-auto">
          {/* Un unico reproductor global: no se reinicia al cambiar de pagina */}
          {nowPlaying && (
            <div className="sticky top-[53px] lg:top-0 z-10 bg-bg pb-4 mb-2">
              <div className="max-w-4xl">
                <Player channel={nowPlaying} onClose={() => setNowPlaying(null)} />
              </div>
            </div>
          )}
          <Outlet />
        </main>
      </div>
    </div>
  );
}
'@

Write-ProjectFile 'src/pages/CategoryPage.tsx' @'
import { useDeferredValue, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { useLiveQuery } from "dexie-react-hooks";
import { Search } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { ChannelGrid } from "../components/ChannelGrid";
import { ChannelCardSkeleton } from "../components/SkeletonLoader";
import type { Channel } from "../types";

interface Props {
  category: Channel["category"];
  title: string;
  placeholder: string;
  noun: string;
}

export function CategoryPage({ category, title, placeholder, noun }: Props) {
  const { activePlaylistId, setNowPlaying } = useStore();
  const { favSet, toggle } = useFavorites();
  const [group, setGroup] = useState("Todas");
  const [query, setQuery] = useState("");
  const deferredQuery = useDeferredValue(query);

  const items = useLiveQuery(
    () =>
      activePlaylistId
        ? db.channels.where("[playlistId+category]").equals([activePlaylistId, category]).toArray()
        : Promise.resolve([] as Channel[]),
    [activePlaylistId, category]
  );

  const groups = useMemo(
    () => Array.from(new Set((items ?? []).map((c) => c.group || "Sin categoría"))).sort((a, b) => a.localeCompare(b)),
    [items]
  );
  const activeGroup = groups.includes(group) ? group : "Todas";

  const filtered = useMemo(() => {
    const q = deferredQuery.trim().toLowerCase();
    return (items ?? []).filter(
      (c) =>
        (activeGroup === "Todas" || (c.group || "Sin categoría") === activeGroup) &&
        (!q || c.name.toLowerCase().includes(q))
    );
  }, [items, activeGroup, deferredQuery]);

  if (!activePlaylistId) {
    return (
      <div className="text-center py-20 text-ink-muted">
        <p className="mb-2">No hay ninguna lista cargada.</p>
        <Link to="/playlists" className="text-brand hover:underline">Ir a Mis listas</Link>
      </div>
    );
  }

  return (
    <div className="space-y-5 animate-fade-in">
      <div>
        <h1 className="text-2xl md:text-3xl font-bold">{title}</h1>
        <p className="text-ink-muted mt-1">{items ? `${filtered.length.toLocaleString()} ${noun}` : "Cargando..."}</p>
      </div>

      <div className="flex flex-col md:flex-row gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-muted" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={placeholder}
            className="w-full pl-9 pr-3 py-2 rounded-lg bg-bg-card border border-white/10 focus:border-brand focus:outline-none"
          />
        </div>
        <select
          value={activeGroup}
          onChange={(e) => setGroup(e.target.value)}
          className="px-3 py-2 rounded-lg bg-bg-card border border-white/10 focus:border-brand focus:outline-none"
        >
          <option value="Todas">Todas las categorías</option>
          {groups.map((g) => (
            <option key={g} value={g}>{g}</option>
          ))}
        </select>
      </div>

      {!items ? (
        <div className="grid md:grid-cols-2 gap-2">
          {Array.from({ length: 8 }).map((_, i) => <ChannelCardSkeleton key={i} />)}
        </div>
      ) : (
        <ChannelGrid
          channels={filtered}
          favSet={favSet}
          onToggleFavorite={toggle}
          onPlay={setNowPlaying}
          emptyText={`No hay ${noun} en esta lista.`}
        />
      )}
    </div>
  );
}
'@

Write-ProjectFile 'src/pages/LiveTV.tsx' @'
import { CategoryPage } from "./CategoryPage";

export function LiveTV() {
  return <CategoryPage category="live" title="TV en vivo" placeholder="Buscar canal..." noun="canales" />;
}
'@

Write-ProjectFile 'src/pages/Movies.tsx' @'
import { CategoryPage } from "./CategoryPage";

export function Movies() {
  return <CategoryPage category="movies" title="Películas" placeholder="Buscar película..." noun="títulos" />;
}
'@

Write-ProjectFile 'src/pages/Series.tsx' @'
import { CategoryPage } from "./CategoryPage";

export function Series() {
  return <CategoryPage category="series" title="Series" placeholder="Buscar serie..." noun="títulos" />;
}
'@

Write-ProjectFile 'src/pages/Favorites.tsx' @'
import { useLiveQuery } from "dexie-react-hooks";
import { Star } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { ChannelGrid } from "../components/ChannelGrid";
import type { Channel } from "../types";

export function Favorites() {
  const { setNowPlaying } = useStore();
  const { favSet, toggle } = useFavorites();
  const ids = Array.from(favSet);

  const channels = useLiveQuery(async () => {
    const rows = await db.channels.bulkGet(ids);
    return rows.filter(Boolean) as Channel[];
  }, [ids.join("|")]);

  return (
    <div className="space-y-5 animate-fade-in">
      <div>
        <h1 className="text-2xl md:text-3xl font-bold flex items-center gap-2">
          <Star className="w-6 h-6 text-brand fill-brand" /> Favoritos
        </h1>
        <p className="text-ink-muted mt-1">{(channels ?? []).length} elementos</p>
      </div>

      <ChannelGrid
        channels={channels ?? []}
        favSet={favSet}
        onToggleFavorite={toggle}
        onPlay={setNowPlaying}
        emptyText="Aún no tienes favoritos. Pulsa la estrella en cualquier canal."
      />
    </div>
  );
}
'@

Write-ProjectFile 'src/pages/Search.tsx' @'
import { useDeferredValue, useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Search as SearchIcon } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { useFavorites } from "../hooks/useFavorites";
import { ChannelGrid } from "../components/ChannelGrid";

export function SearchPage() {
  const { activePlaylistId, setNowPlaying } = useStore();
  const { favSet, toggle } = useFavorites();
  const [query, setQuery] = useState("");
  const q = useDeferredValue(query).trim().toLowerCase();

  const results = useLiveQuery(async () => {
    if (!activePlaylistId || !q) return [];
    return db.channels
      .where("playlistId")
      .equals(activePlaylistId)
      .filter((c) => c.name.toLowerCase().includes(q))
      .limit(300)
      .toArray();
  }, [activePlaylistId, q]);

  return (
    <div className="space-y-5 animate-fade-in">
      <h1 className="text-2xl md:text-3xl font-bold">Buscar</h1>

      <div className="relative">
        <SearchIcon className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-ink-muted" />
        <input
          autoFocus
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Escribe para buscar en tu lista..."
          className="w-full pl-11 pr-4 py-3 rounded-xl bg-bg-card border border-white/10 focus:border-brand focus:outline-none text-lg"
        />
      </div>

      {q && <p className="text-sm text-ink-muted">{(results ?? []).length} resultados</p>}

      {q && (
        <ChannelGrid channels={results ?? []} favSet={favSet} onToggleFavorite={toggle} onPlay={setNowPlaying} />
      )}
    </div>
  );
}
'@

Write-ProjectFile 'src/pages/Home.tsx' @'
import { useMemo } from "react";
import { Link } from "react-router-dom";
import { useLiveQuery } from "dexie-react-hooks";
import { Tv, Film, ListVideo, Plus, Clapperboard } from "lucide-react";
import { db } from "../db";
import { useStore } from "../store";
import { imgUrl } from "../services/proxy";
import type { Channel } from "../types";

export function Home() {
  const { activePlaylistId, setNowPlaying } = useStore();
  const playlists = useLiveQuery(() => db.playlists.toArray(), []);

  const data = useLiveQuery(async () => {
    if (!activePlaylistId) return null;
    const q = (cat: Channel["category"]) =>
      db.channels.where("[playlistId+category]").equals([activePlaylistId, cat]);
    const [live, movies, series, nLive, nMovies, nSeries] = await Promise.all([
      q("live").limit(20).toArray(),
      q("movies").limit(20).toArray(),
      q("series").limit(20).toArray(),
      q("live").count(),
      q("movies").count(),
      q("series").count(),
    ]);
    return { live, movies, series, nLive, nMovies, nSeries };
  }, [activePlaylistId]);

  const active = playlists?.find((p) => p.id === activePlaylistId);
  const heroLogo = useMemo(() => imgUrl(data?.live.find((c) => c.logo)?.logo), [data]);

  if (playlists && playlists.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-24 text-center animate-fade-in">
        <div className="w-16 h-16 rounded-2xl bg-brand/15 flex items-center justify-center mb-4">
          <ListVideo className="w-8 h-8 text-brand" />
        </div>
        <h1 className="text-3xl font-bold">Bienvenido a StreamBox</h1>
        <p className="text-ink-muted mt-2 max-w-md">
          Empieza añadiendo tu lista M3U/M3U8. StreamBox no incluye contenido: tú traes el tuyo.
        </p>
        <Link to="/playlists" className="mt-6 px-5 py-2.5 rounded-lg bg-brand hover:bg-brand-hover font-semibold flex items-center gap-2">
          <Plus className="w-4 h-4" /> Añadir mi primera lista
        </Link>
      </div>
    );
  }

  if (!data) return null;

  return (
    <div className="space-y-8 animate-fade-in">
      <section className="relative rounded-2xl overflow-hidden bg-bg-card border border-white/5" style={{ minHeight: 260 }}>
        {heroLogo && <img src={heroLogo} alt="" className="absolute inset-0 w-full h-full object-cover opacity-20" />}
        <div className="absolute inset-0 bg-gradient-to-r from-bg via-bg/70 to-transparent" />
        <div className="relative p-6 md:p-10 flex flex-col justify-end min-h-[260px]">
          <p className="text-xs uppercase tracking-widest text-brand font-semibold">{active?.name || "Lista activa"}</p>
          <h1 className="text-3xl md:text-5xl font-bold mt-2">Tu IPTV, a un clic</h1>
          <p className="text-ink-muted mt-2 max-w-xl">
            {data.nLive.toLocaleString()} en vivo · {data.nMovies.toLocaleString()} películas · {data.nSeries.toLocaleString()} series
          </p>
          <div className="flex flex-wrap gap-2 mt-4">
            <Link to="/live" className="px-4 py-2 rounded-lg bg-brand hover:bg-brand-hover font-semibold flex items-center gap-2">
              <Tv className="w-4 h-4" /> TV en vivo
            </Link>
            <Link to="/movies" className="px-4 py-2 rounded-lg bg-bg-soft hover:bg-bg-hover font-semibold flex items-center gap-2">
              <Film className="w-4 h-4" /> Películas
            </Link>
            <Link to="/series" className="px-4 py-2 rounded-lg bg-bg-soft hover:bg-bg-hover font-semibold flex items-center gap-2">
              <Clapperboard className="w-4 h-4" /> Series
            </Link>
          </div>
        </div>
      </section>

      <Row title="Canales en vivo" items={data.live} onPlay={setNowPlaying} />
      <Row title="Películas" items={data.movies} onPlay={setNowPlaying} />
      <Row title="Series" items={data.series} onPlay={setNowPlaying} />
    </div>
  );
}

function Row({ title, items, onPlay }: { title: string; items: Channel[]; onPlay: (c: Channel) => void }) {
  if (items.length === 0) return null;
  return (
    <section>
      <h2 className="text-xl font-bold mb-3">{title}</h2>
      <div className="flex gap-3 overflow-x-auto pb-3 -mx-1 px-1 snap-x">
        {items.map((c) => (
          <button
            key={c.id}
            data-focusable="true"
            onClick={() => onPlay(c)}
            className="shrink-0 w-40 snap-start group text-left rounded-lg"
          >
            <div className="aspect-video rounded-lg bg-bg-card overflow-hidden border border-white/5 group-hover:border-brand/50 transition-colors">
              {c.logo ? (
                <img src={imgUrl(c.logo)} alt="" loading="lazy" className="w-full h-full object-contain p-2" />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-ink-muted text-xs p-2 text-center">
                  {c.name.slice(0, 30)}
                </div>
              )}
            </div>
            <p className="mt-2 text-sm font-medium truncate">{c.name}</p>
            <p className="text-xs text-ink-muted truncate">{c.group}</p>
          </button>
        ))}
      </div>
    </section>
  );
}
'@

Write-ProjectFile 'src/pages/PlaylistManager.tsx' @'
import { useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { Plus, Trash2, Upload, Link as LinkIcon, Loader2, ListVideo, RefreshCw, Check } from "lucide-react";
import { clsx } from "clsx";
import { db } from "../db";
import { useStore } from "../store";
import { loadM3UFromUrl, loadM3UFromFile } from "../services/m3u/parser";
import { savePlaylistWithChannels, deletePlaylist } from "../services/playlists";
import type { Playlist } from "../types";

const uid = () => Math.random().toString(36).slice(2) + Date.now().toString(36);
const inputClass =
  "w-full px-3 py-2 rounded-lg bg-bg-soft border border-white/10 focus:border-brand focus:outline-none focus-visible:ring-2 focus-visible:ring-brand";

export function PlaylistManager() {
  const { activePlaylistId, setActivePlaylistId } = useStore();
  const playlists =
    useLiveQuery(async () => {
      const rows = await db.playlists.orderBy("createdAt").toArray();
      return Promise.all(
        rows.map(async (p) => ({ ...p, count: await db.channels.where("playlistId").equals(p.id).count() }))
      );
    }, []) ?? [];

  const [name, setName] = useState("");
  const [url, setUrl] = useState("");
  const [busy, setBusy] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const addFromUrl = async () => {
    if (!name.trim() || !url.trim()) return setError("Introduce un nombre y una URL.");
    setBusy(true);
    setError(null);
    try {
      const id = uid();
      const { channels } = await loadM3UFromUrl(url.trim(), id);
      const now = Date.now();
      await savePlaylistWithChannels(
        { id, name: name.trim(), type: "m3u-url", url: url.trim(), createdAt: now, updatedAt: now },
        channels
      );
      setActivePlaylistId(id);
      setName("");
      setUrl("");
    } catch (e: any) {
      setError(e?.message || "Error al cargar la lista");
    } finally {
      setBusy(false);
    }
  };

  const addFromFile = async (file: File) => {
    setBusy(true);
    setError(null);
    try {
      const id = uid();
      const { channels } = await loadM3UFromFile(file, id);
      const now = Date.now();
      await savePlaylistWithChannels(
        { id, name: name.trim() || file.name, type: "m3u-file", createdAt: now, updatedAt: now },
        channels
      );
      setActivePlaylistId(id);
      setName("");
    } catch (e: any) {
      setError(e?.message || "Error al procesar el archivo");
    } finally {
      setBusy(false);
    }
  };

  const refresh = async (p: Playlist) => {
    if (p.type !== "m3u-url" || !p.url) return;
    setBusyId(p.id);
    setError(null);
    try {
      const { channels } = await loadM3UFromUrl(p.url, p.id);
      await savePlaylistWithChannels({ ...p, updatedAt: Date.now() }, channels);
    } catch (e: any) {
      setError(e?.message || "Error al actualizar la lista");
    } finally {
      setBusyId(null);
    }
  };

  const remove = async (id: string) => {
    if (!confirm("¿Eliminar esta lista y todos sus canales?")) return;
    await deletePlaylist(id);
    if (activePlaylistId === id) setActivePlaylistId(null);
  };

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl md:text-3xl font-bold">Mis listas</h1>
        <p className="text-ink-muted mt-1">Añade tus listas M3U/M3U8 por URL o archivo.</p>
      </div>

      <section className="bg-bg-card rounded-2xl p-5 space-y-4">
        <h2 className="font-semibold flex items-center gap-2">
          <Plus className="w-5 h-5 text-brand" /> Nueva lista M3U
        </h2>

        <div className="grid md:grid-cols-2 gap-3">
          <label className="space-y-1">
            <span className="text-xs text-ink-muted">Nombre</span>
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Mi lista IPTV" className={inputClass} />
          </label>
          <label className="space-y-1">
            <span className="text-xs text-ink-muted flex items-center gap-1">
              <LinkIcon className="w-3 h-3" /> URL de la lista
            </span>
            <input value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://ejemplo.com/lista.m3u" className={inputClass} />
          </label>
        </div>

        <div className="flex flex-wrap gap-2">
          <button
            onClick={addFromUrl}
            disabled={busy}
            className="px-4 py-2 rounded-lg bg-brand hover:bg-brand-hover disabled:opacity-50 font-semibold flex items-center gap-2 focus-visible:ring-2 focus-visible:ring-white"
          >
            {busy ? <Loader2 className="w-4 h-4 animate-spin" /> : <LinkIcon className="w-4 h-4" />}
            Añadir por URL
          </button>

          <label className="px-4 py-2 rounded-lg bg-bg-soft hover:bg-bg-hover cursor-pointer font-semibold flex items-center gap-2">
            <Upload className="w-4 h-4" />
            Subir archivo
            <input
              type="file"
              accept=".m3u,.m3u8,.txt"
              className="hidden"
              disabled={busy}
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) addFromFile(f);
                e.target.value = "";
              }}
            />
          </label>
        </div>

        {busy && <p className="text-xs text-ink-muted">Procesando lista, las grandes pueden tardar unos segundos...</p>}
        {error && <p className="text-sm text-brand">{error}</p>}
      </section>

      <section className="space-y-2">
        {playlists.length === 0 && (
          <div className="text-center py-12 text-ink-muted">
            <ListVideo className="w-10 h-10 mx-auto mb-3 opacity-50" />
            <p>Aún no tienes listas. Añade una arriba para empezar.</p>
          </div>
        )}
        {playlists.map((p) => {
          const isActive = activePlaylistId === p.id;
          return (
            <div
              key={p.id}
              className={clsx("flex items-center gap-3 p-4 rounded-xl bg-bg-card border", isActive ? "border-brand/50" : "border-white/5")}
            >
              <div className="w-10 h-10 rounded-lg bg-bg-soft flex items-center justify-center shrink-0">
                <ListVideo className="w-5 h-5 text-ink-muted" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-semibold truncate">{p.name}</p>
                <p className="text-xs text-ink-muted truncate">
                  {p.count.toLocaleString()} canales · {p.type === "m3u-url" ? p.url : "Archivo local"}
                </p>
              </div>
              <button
                onClick={() => setActivePlaylistId(p.id)}
                disabled={isActive}
                className={clsx(
                  "px-3 py-1.5 rounded-lg text-sm flex items-center gap-1 focus-visible:ring-2 focus-visible:ring-brand",
                  isActive ? "bg-brand/15 text-brand" : "bg-bg-soft hover:bg-bg-hover"
                )}
              >
                {isActive ? <><Check className="w-4 h-4" /> Activa</> : "Usar"}
              </button>
              {p.type === "m3u-url" && (
                <button
                  onClick={() => refresh(p)}
                  disabled={busyId === p.id}
                  className="p-2 rounded-lg hover:bg-white/10 text-ink-muted hover:text-ink"
                  aria-label="Actualizar lista"
                >
                  {busyId === p.id ? <Loader2 className="w-4 h-4 animate-spin" /> : <RefreshCw className="w-4 h-4" />}
                </button>
              )}
              <button
                onClick={() => remove(p.id)}
                className="p-2 rounded-lg hover:bg-white/10 text-ink-muted hover:text-brand"
                aria-label="Eliminar"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          );
        })}
      </section>
    </div>
  );
}
'@

Write-ProjectFile 'src/pages/Settings.tsx' @'
import { useEffect, useRef, useState } from "react";
import { db, getSettings, saveSettings, DEFAULT_SETTINGS } from "../db";
import { Save, Trash2, RefreshCw } from "lucide-react";

type Language = "es" | "en";

const inputClass =
  "w-full px-3 py-2 rounded-lg bg-bg-soft border border-white/10 focus:border-brand focus:outline-none focus-visible:ring-2 focus-visible:ring-brand";

export function SettingsPage() {
  const [language, setLanguage] = useState<Language>("es");
  const [proxyUrl, setProxyUrl] = useState(DEFAULT_SETTINGS.proxyUrl);
  const [tmdbApiKey, setTmdbApiKey] = useState("");
  const [parentalPin, setParentalPin] = useState("");
  const [loaded, setLoaded] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");
  const timer = useRef<ReturnType<typeof setTimeout>>();

  useEffect(() => {
    getSettings().then((s) => {
      setLanguage(s.language);
      setProxyUrl(s.proxyUrl);
      setTmdbApiKey(s.tmdbApiKey);
      setParentalPin(s.parentalPin);
      setLoaded(true);
    });
    return () => clearTimeout(timer.current);
  }, []);

  const save = async () => {
    if (!loaded) return;
    if (parentalPin && !/^\d{4,6}$/.test(parentalPin)) {
      setError("El PIN debe tener entre 4 y 6 dígitos.");
      return;
    }
    setError("");
    await saveSettings({
      language,
      proxyUrl: proxyUrl.trim() || DEFAULT_SETTINGS.proxyUrl,
      tmdbApiKey: tmdbApiKey.trim(),
      parentalPin,
    });
    setSaved(true);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => setSaved(false), 1500);
  };

  const clearCache = async () => {
    if (!confirm("¿Borrar los canales guardados? Las listas por URL se pueden actualizar de nuevo; las de archivo tendras que subirlas otra vez.")) return;
    await db.channels.clear();
    alert("Caché borrada.");
  };

  const clearAll = async () => {
    if (!confirm("¿Borrar TODOS los datos (listas, canales, favoritos, historial)?")) return;
    await db.delete();
    localStorage.removeItem("streambox-ui");
    location.reload();
  };

  return (
    <div className="space-y-6 animate-fade-in max-w-2xl">
      <div>
        <h1 className="text-2xl md:text-3xl font-bold">Ajustes</h1>
        <p className="text-ink-muted mt-1">Personaliza StreamBox.</p>
      </div>

      <section className="bg-bg-card rounded-2xl p-5 space-y-4">
        <h2 className="font-semibold">General</h2>

        <label className="block space-y-1">
          <span className="text-xs text-ink-muted">Idioma (pendiente de implementar)</span>
          <select value={language} onChange={(e) => setLanguage(e.target.value as Language)} className={inputClass}>
            <option value="es">Español</option>
            <option value="en">English</option>
          </select>
        </label>

        <label className="block space-y-1">
          <span className="text-xs text-ink-muted">URL del proxy</span>
          <input value={proxyUrl} onChange={(e) => setProxyUrl(e.target.value)} className={inputClass} placeholder="/proxy" />
          <span className="text-xs text-ink-dim">
            Por defecto <code>/proxy</code> (mismo host que la app).
          </span>
        </label>

        <label className="block space-y-1">
          <span className="text-xs text-ink-muted">TMDB API Key (opcional)</span>
          <input
            type="password"
            value={tmdbApiKey}
            onChange={(e) => setTmdbApiKey(e.target.value)}
            placeholder="Pega aqui tu API key de TMDB"
            className={inputClass}
            autoComplete="off"
          />
        </label>

        <label className="block space-y-1">
          <span className="text-xs text-ink-muted">PIN parental (opcional, 4 a 6 dígitos)</span>
          <input
            type="password"
            inputMode="numeric"
            maxLength={6}
            value={parentalPin}
            onChange={(e) => setParentalPin(e.target.value.replace(/\D/g, ""))}
            placeholder="Dejar vacio para desactivar"
            className={inputClass}
            autoComplete="off"
          />
        </label>

        {error && <p className="text-sm text-brand">{error}</p>}

        <button
          onClick={save}
          disabled={!loaded}
          className="px-4 py-2 rounded-lg bg-brand hover:bg-brand-hover font-semibold flex items-center gap-2 disabled:opacity-50 focus-visible:ring-2 focus-visible:ring-white"
        >
          <Save className="w-4 h-4" /> Guardar
          {saved && <span className="text-xs opacity-80">✓ Guardado</span>}
        </button>
      </section>

      <section className="bg-bg-card rounded-2xl p-5 space-y-3">
        <h2 className="font-semibold">Datos</h2>
        <button onClick={clearCache} className="px-4 py-2 rounded-lg bg-bg-soft hover:bg-bg-hover flex items-center gap-2 focus-visible:ring-2 focus-visible:ring-brand">
          <RefreshCw className="w-4 h-4" /> Borrar caché de canales
        </button>
        <button onClick={clearAll} className="px-4 py-2 rounded-lg bg-brand/15 hover:bg-brand/25 text-brand flex items-center gap-2 focus-visible:ring-2 focus-visible:ring-brand">
          <Trash2 className="w-4 h-4" /> Borrar todos los datos
        </button>
      </section>
    </div>
  );
}
'@


# ---------------- Iconos PWA (192 y 512) ----------------
function New-StreamBoxIcon {
    param([string]$Path, [int]$Size)
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([System.Drawing.ColorTranslator]::FromHtml('#0b0b0f'))
    $brand = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#e50914'))
    $m = [int]($Size * 0.16)
    $g.FillRectangle($brand, $m, $m, $Size - 2 * $m, $Size - 2 * $m)
    $font = New-Object System.Drawing.Font('Segoe UI', [single]($Size * 0.42), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'
    $sf.LineAlignment = 'Center'
    $g.DrawString('S', $font, [System.Drawing.Brushes]::White, [System.Drawing.RectangleF]::new(0, 0, $Size, $Size), $sf)
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

try {
    $iconDir = Join-Path $root "public\icons"
    New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
    New-StreamBoxIcon (Join-Path $iconDir "icon-192.png") 192
    New-StreamBoxIcon (Join-Path $iconDir "icon-512.png") 512
    Write-Host "  + public/icons/icon-192.png, icon-512.png" -ForegroundColor Green
} catch {
    Write-Host "No se pudieron generar los iconos ($($_.Exception.Message)). Pon tus propios icon-192.png e icon-512.png en public/icons/." -ForegroundColor Yellow
}

# ---------------- Dependencias ----------------
if (-not $SkipInstall) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host ""
        Write-Host "Ejecutando npm install..." -ForegroundColor Cyan
        npm install
    } else {
        Write-Host "npm no encontrado. Instala Node.js 18+ desde https://nodejs.org y ejecuta 'npm install'." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Listo." -ForegroundColor Green
Write-Host "  Probar:        npm start        (abre http://localhost:5173)"
Write-Host "  Compilar:      npm run build"
Write-Host "  Subir a Git:   git add . ; git commit -m 'StreamBox fase 1' ; git push"