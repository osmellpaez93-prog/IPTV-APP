import { useState } from "react";
import { Play, Star, Info, Plus, Check } from "lucide-react";
import { imgUrl } from "../../services/proxy";
import type { Channel } from "../../types";

interface Props {
  item: Channel;
  kind: "movies" | "series";
  fav: boolean;
  onFav: (id: string) => void;
  onOpen: (c: Channel) => void;
}

export function HeroSpotlight({ item, kind, fav, onFav, onOpen }: Props) {
  const [bad, setBad] = useState(false);
  const src = imgUrl(item.logo);
  return (
    <section className="relative overflow-hidden rounded-2xl border border-[#22304a] bg-[#0d1320]">
      {src && !bad && (
        <img src={src} alt="" onError={() => setBad(true)} className="absolute inset-0 h-full w-full scale-110 object-cover opacity-25 blur-[3px]" />
      )}
      <div className="absolute inset-0 bg-gradient-to-r from-[#070a12] via-[#070a12]/90 to-[#070a12]/20" />
      <div className="absolute inset-0 bg-gradient-to-t from-[#070a12] via-transparent to-transparent" />
      <div className="sb-grain pointer-events-none absolute inset-0 opacity-[0.05] mix-blend-overlay" />

      <div className="relative flex min-h-[300px] items-end gap-6 p-6 md:p-9">
        {src && !bad && (
          <img src={src} alt="" className="hidden h-[220px] w-[147px] shrink-0 rounded-xl object-cover shadow-2xl ring-1 ring-white/10 md:block" />
        )}
        <div className="min-w-0 flex-1">
          <p className="text-[11px] font-bold uppercase tracking-[0.24em] text-[#4c8dff]">
            {kind === "movies" ? "Pelicula destacada" : "Serie destacada"}
          </p>
          <h1 className="mt-2 line-clamp-2 text-3xl font-black leading-tight tracking-tight md:text-5xl">{item.name}</h1>
          <div className="mt-3 flex flex-wrap items-center gap-3 text-sm text-[#93a3bd]">
            {item.rating && (
              <span className="sb-tnum flex items-center gap-1 font-bold text-[#ffb020]">
                <Star className="h-3.5 w-3.5" fill="currentColor" /> {item.rating}
              </span>
            )}
            {item.year && <span className="sb-tnum">{item.year}</span>}
            <span className="truncate">{item.group}</span>
          </div>
          {item.plot && <p className="mt-3 line-clamp-3 max-w-2xl text-sm text-[#93a3bd]">{item.plot}</p>}

          <div className="mt-5 flex flex-wrap gap-2">
            <button
              data-sbfocus="1"
              onClick={() => onOpen(item)}
              className="flex items-center gap-2 rounded-lg bg-white px-5 py-2.5 font-bold text-black hover:bg-white/85"
            >
              <Play className="h-4 w-4" fill="currentColor" /> {kind === "movies" ? "Reproducir" : "Ver episodios"}
            </button>
            <button
              data-sbfocus="1"
              onClick={() => onFav(item.id)}
              className="flex items-center gap-2 rounded-lg bg-white/12 px-4 py-2.5 font-semibold backdrop-blur hover:bg-white/20"
            >
              {fav ? <Check className="h-4 w-4" /> : <Plus className="h-4 w-4" />}
              {fav ? "En mi lista" : "Mi lista"}
            </button>
            <button
              onClick={() => onOpen(item)}
              className="flex items-center gap-2 rounded-lg bg-white/12 px-4 py-2.5 font-semibold backdrop-blur hover:bg-white/20"
            >
              <Info className="h-4 w-4" /> Detalles
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}
