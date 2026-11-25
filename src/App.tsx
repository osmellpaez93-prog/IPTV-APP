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
