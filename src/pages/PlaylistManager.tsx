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
