/**
 * Navegacion espacial (flechas / D-pad / mando).
 * Elige el enfocable mas cercano en la direccion pulsada. Los overlays
 * marcados con data-nav-lock encierran la navegacion; el reproductor
 * gestiona sus propias flechas.
 */
import { useEffect } from "react";

const SELECTOR = '[data-focusable="true"]';
const DIRS: Record<string, [number, number]> = {
  ArrowUp: [0, -1],
  ArrowDown: [0, 1],
  ArrowLeft: [-1, 0],
  ArrowRight: [1, 0],
};

function isTyping(el: Element | null): boolean {
  if (!el) return false;
  const t = el as HTMLElement;
  return (
    t.tagName === "INPUT" ||
    t.tagName === "TEXTAREA" ||
    t.tagName === "SELECT" ||
    t.isContentEditable === true
  );
}

export function useSpatialNav(enabled = true) {
  useEffect(() => {
    if (!enabled) return;

    const collect = (): HTMLElement[] => {
      const locks = document.querySelectorAll("[data-nav-lock]");
      const root: ParentNode = locks.length ? locks[locks.length - 1] : document;
      return (Array.from(root.querySelectorAll(SELECTOR)) as HTMLElement[]).filter((n) => {
        const r = n.getBoundingClientRect();
        return r.width > 1 && r.height > 1 && !n.hasAttribute("disabled");
      });
    };

    const pick = (nodes: HTMLElement[], dir: [number, number]): HTMLElement | null => {
      const active = document.activeElement as HTMLElement | null;
      if (!active || !nodes.includes(active)) return nodes[0] ?? null;
      const a = active.getBoundingClientRect();
      const ax = a.left + a.width / 2;
      const ay = a.top + a.height / 2;
      let best: HTMLElement | null = null;
      let bestScore = Infinity;
      for (const n of nodes) {
        if (n === active) continue;
        const r = n.getBoundingClientRect();
        const dx = r.left + r.width / 2 - ax;
        const dy = r.top + r.height / 2 - ay;
        const primary = dx * dir[0] + dy * dir[1];
        if (primary < 6) continue;
        const cross = Math.abs(dx * dir[1] - dy * dir[0]);
        const score = primary + cross * 2.4;
        if (score < bestScore) { bestScore = score; best = n; }
      }
      return best;
    };

    const onKey = (e: KeyboardEvent) => {
      if (e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
      const dir = DIRS[e.key];
      if (!dir) return;
      const target = e.target as HTMLElement | null;
      if (isTyping(target)) return;
      if (target && target.closest('[data-nav-scope="player"]')) return;

      const nodes = collect();
      if (!nodes.length) return;
      const found = pick(nodes, dir);
      if (found) {
        e.preventDefault();
        found.focus({ preventScroll: true });
        found.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "smooth" });
        return;
      }
      if (dir[1] !== 0 && !document.querySelector("[data-nav-lock]")) {
        e.preventDefault();
        window.scrollBy({ top: dir[1] * window.innerHeight * 0.55, behavior: "smooth" });
        window.setTimeout(() => {
          const again = pick(collect(), dir);
          if (again) {
            again.focus({ preventScroll: true });
            again.scrollIntoView({ block: "nearest", behavior: "smooth" });
          }
        }, 250);
      }
    };

    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [enabled]);
}
