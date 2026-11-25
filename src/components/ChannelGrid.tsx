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
