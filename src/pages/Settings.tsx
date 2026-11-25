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
