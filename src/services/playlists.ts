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
