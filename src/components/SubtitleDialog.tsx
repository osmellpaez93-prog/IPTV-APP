import { useEffect, useState } from "react";
import { X, Search, Loader2, Upload, Minus, Plus } from "lucide-react";
import { getSettings } from "../db";
import type { Channel, Settings } from "../types";
import type { PlayerState, usePlayer } from "../hooks/usePlayer";
import { guessQuery, searchSubs, downloadSub, srtToVtt, decodeText, type SubResult } from "../services/subtitles";
import { Link } from "react-router-dom";

type Actions = ReturnType<typeof usePlayer>["actions"];

interface Props {
  channel: Channel;
  state: PlayerState;
  actions: Actions;
  onClose: () => void;
}

const inputClass =
  "w-full px-3 py-2 rounded-lg bg-bg-soft border border-white/10 focus:border-brand focus:outline-none text-sm";

export function SubtitleDialog({ channel, state, actions, onClose }: Props) {
  const [settings, setSettings] = useState<Settings | null>(null);
  const [query, setQuery] = useState("");
  const [year, setYear] = useState("");
  const [season, setSeason] = useState("");
  const [episode, setEpisode] = useState("");
  const [languages, setLanguages] = useState("es,en");
  const [results, setResults] = useState<SubResult[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [usingId, setUsingId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  useEffect(() => {
    const g = guessQuery(channel.name);
    setQuery(g.query);
    setYear(g.year ?? "");
    setSeason(g.season ?? "");
    setEpisode(g.episode ?? "");
    getSettings().then((s) => {
      setSettings(s);
      setLanguages(s.osLanguages || "es,en");
    });
  }, [channel.id]);

  const hasKey = !!settings?.osApiKey;

  const search = async () => {
    if (!settings) return;
    setBusy(true);
    setError(null);
    setMsg(null);
    try {
      setResults(await searchSubs(settings, { query: query.trim(), year: year.trim() || undefined, season: season.trim() || undefined, episode: episode.trim() || undefined }, languages.trim()));
    } catch (e: any) {
      setError(e?.message || "Error al buscar");
      setResults(null);
    } finally {
      setBusy(false);
    }
  };

  const use = async (r: SubResult) => {
    if (!settings) return;
    setUsingId(r.fileId);
    setError(null);
    setMsg(null);
    try {
      const d = await downloadSub(settings, r.fileId);
      actions.addSubtitle(`${(r.language || "").toUpperCase()} · ${r.release}`.slice(0, 60), d.vtt);
      setMsg(`Subtítulo activado.${d.remaining != null ? ` Descargas restantes hoy: ${d.remaining}.` : ""}`);
    } catch (e: any) {
      setError(e?.message || "No se pudo descargar el subtítulo");
    } finally {
      setUsingId(null);
    }
  };

  const onFile = async (f: File) => {
    setError(null);
    try {
      const text = decodeText(new Uint8Array(await f.arrayBuffer()));
      actions.addSubtitle(f.name.slice(0, 60), f.name.toLowerCase().endsWith(".vtt") ? text : srtToVtt(text));
      setMsg("Subtítulo cargado desde archivo.");
    } catch {
      setError("No se pudo leer el archivo.");
    }
  };

  const isEpisode = !!(season || episode);

  return (
    <div className="absolute inset-0 z-20 bg-black/85 overflow-y-auto p-3 sm:p-5">
      <div className="max-w-xl mx-auto space-y-3">
        <div className="flex items-center gap-2">
          <h3 className="font-semibold flex-1">Subtítulos</h3>
          <button onClick={onClose} className="p-2 rounded-full hover:bg-white/10" aria-label="Cerrar">
            <X className="w-5 h-5" />
          </button>
        </div>

        {state.activeExtSub && (
          <div className="flex items-center gap-2 bg-bg-card rounded-lg p-2 text-sm">
            <span className="text-ink-muted flex-1">Sincronización: {state.subOffset > 0 ? "+" : ""}{state.subOffset.toFixed(1)} s</span>
            <button onClick={() => actions.shiftSubtitles(-0.5)} className="px-2 py-1 rounded-md bg-bg-soft hover:bg-bg-hover flex items-center gap-1">
              <Minus className="w-3 h-3" /> 0.5
            </button>
            <button onClick={() => actions.shiftSubtitles(0.5)} className="px-2 py-1 rounded-md bg-bg-soft hover:bg-bg-hover flex items-center gap-1">
              <Plus className="w-3 h-3" /> 0.5
            </button>
          </div>
        )}

        <label className="flex items-center gap-2 px-3 py-2 rounded-lg bg-bg-card hover:bg-bg-hover cursor-pointer text-sm">
          <Upload className="w-4 h-4" /> Cargar archivo .srt / .vtt del dispositivo
          <input
            type="file"
            accept=".srt,.vtt,.txt"
            className="hidden"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) onFile(f);
              e.target.value = "";
            }}
          />
        </label>

        {!hasKey ? (
          <p className="text-sm text-ink-muted bg-bg-card rounded-lg p-3">
            Para buscar en OpenSubtitles, añade tu API key (y tu usuario y contraseña) en{" "}
            <Link to="/settings" onClick={onClose} className="text-brand underline">Ajustes</Link>.
          </p>
        ) : (
          <div className="space-y-2 bg-bg-card rounded-lg p-3">
            <input value={query} onChange={(e) => setQuery(e.target.value)} onKeyDown={(e) => e.key === "Enter" && search()} placeholder="Título" className={inputClass} />
            <div className="grid grid-cols-3 gap-2">
              {isEpisode ? (
                <>
                  <input value={season} onChange={(e) => setSeason(e.target.value)} placeholder="Temp." className={inputClass} />
                  <input value={episode} onChange={(e) => setEpisode(e.target.value)} placeholder="Ep." className={inputClass} />
                </>
              ) : (
                <>
                  <input value={year} onChange={(e) => setYear(e.target.value)} placeholder="Año" className={inputClass} />
                  <span />
                </>
              )}
              <input value={languages} onChange={(e) => setLanguages(e.target.value)} placeholder="es,en" className={inputClass} />
            </div>
            <button onClick={search} disabled={busy || !query.trim()} className="w-full px-4 py-2 rounded-lg bg-brand hover:bg-brand-hover disabled:opacity-50 font-semibold flex items-center justify-center gap-2 text-sm">
              {busy ? <Loader2 className="w-4 h-4 animate-spin" /> : <Search className="w-4 h-4" />} Buscar en OpenSubtitles
            </button>
          </div>
        )}

        {error && <p className="text-sm text-brand">{error}</p>}
        {msg && <p className="text-sm text-green-400">{msg}</p>}

        {results && results.length === 0 && <p className="text-sm text-ink-muted">No se encontraron subtítulos. Prueba a simplificar el título o cambiar el idioma.</p>}

        <div className="space-y-1">
          {(results ?? []).slice(0, 30).map((r) => (
            <button
              key={r.fileId}
              onClick={() => use(r)}
              disabled={usingId !== null}
              className="w-full flex items-center gap-3 p-2 rounded-lg bg-bg-card hover:bg-bg-hover text-left disabled:opacity-60"
            >
              <span className="px-2 py-0.5 rounded bg-brand/20 text-brand text-xs font-bold uppercase shrink-0">{r.language}</span>
              <span className="flex-1 min-w-0">
                <span className="block text-sm truncate">{r.release || r.title}</span>
                <span className="block text-xs text-ink-muted">
                  {r.downloads.toLocaleString()} descargas{r.hearingImpaired ? " · para sordos" : ""}{r.ai ? " · traducción automática" : ""}{r.trusted ? " · fiable" : ""}
                </span>
              </span>
              {usingId === r.fileId && <Loader2 className="w-4 h-4 animate-spin shrink-0" />}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
