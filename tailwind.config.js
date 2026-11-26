/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Azul broadcast nocturno: la base de toda la superficie.
        bg: {
          deep: "#05070f",
          DEFAULT: "#0a0e1a",
          surface: "#111a2e",
          raised: "#18233c",
          soft: "#111a2e",
          card: "#111a2e",
          hover: "#18233c",
          line: "#26314f",
        },
        brand: { DEFAULT: "#e50914", hover: "#ff2430", soft: "#ff6b70" },
        signal: { DEFAULT: "#22d3ee", soft: "#7ee7f7", deep: "#0e7490" },
        aqua: { DEFAULT: "#22d3ee", soft: "#7ee7f7" },
        gold: { DEFAULT: "#ffb020", soft: "#ffd27a" },
        iris: { DEFAULT: "#8b5cf6", soft: "#b79bff" },
        lime: { DEFAULT: "#a3e635", soft: "#d0f58a" },
        ink: { DEFAULT: "#f2f5fb", muted: "#9aa7c2", dim: "#63708d" },
        ok: "#22c55e",
        warn: "#f59e0b",
        danger: "#ef4444",
        info: "#38bdf8",
      },
      fontFamily: { sans: ['"Inter"', "system-ui", "sans-serif"] },
      boxShadow: {
        dock: "0 24px 60px -18px rgba(0,0,0,.9), 0 0 0 1px rgba(38,49,79,.9)",
        card: "0 10px 30px -12px rgba(0,0,0,.85)",
        glow: "0 0 32px -6px var(--accent-glow)",
      },
      animation: {
        "fade-in": "fadeIn .28s ease-out both",
        "slide-up": "slideUp .34s cubic-bezier(.2,.8,.2,1) both",
        "pop-in": "popIn .2s cubic-bezier(.2,.9,.3,1.25) both",
        drift: "drift 30s ease-in-out infinite alternate",
        sheen: "sheen 2.6s linear infinite",
        "live-dot": "liveDot 1.6s ease-in-out infinite",
      },
      keyframes: {
        fadeIn: { "0%": { opacity: "0" }, "100%": { opacity: "1" } },
        slideUp: {
          "0%": { opacity: "0", transform: "translateY(16px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        popIn: {
          "0%": { opacity: "0", transform: "scale(.95)" },
          "100%": { opacity: "1", transform: "scale(1)" },
        },
        drift: {
          "0%": { transform: "translate3d(-5%,-3%,0) scale(1)" },
          "100%": { transform: "translate3d(6%,4%,0) scale(1.15)" },
        },
        sheen: {
          "0%": { backgroundPosition: "220% 0" },
          "100%": { backgroundPosition: "-220% 0" },
        },
        liveDot: {
          "0%,100%": { opacity: "1", transform: "scale(1)" },
          "50%": { opacity: ".35", transform: "scale(.8)" },
        },
      },
    },
  },
  plugins: [],
};
