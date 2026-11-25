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
