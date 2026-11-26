import { useEffect, useState } from "react";
import type { Channel } from "../types";
import { getMeta, type Meta } from "../services/meta";

export function useMeta(channel: Channel | null) {
  const [meta, setMeta] = useState<Meta | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!channel) { setMeta(null); setLoading(false); return; }
    let alive = true;
    setMeta(null);
    setLoading(true);
    getMeta(channel)
      .then((m) => { if (alive) setMeta(m); })
      .catch(() => { if (alive) setMeta(null); })
      .finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [channel?.id]);

  return { meta, loading };
}
