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
