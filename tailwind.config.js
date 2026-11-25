/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: { DEFAULT: "#0b0b0f", deep: "#07070b", soft: "#12121a", card: "#181822", hover: "#22222f", line: "#2c2c3c" },
        brand: { DEFAULT: "#e50914", hover: "#ff2430", soft: "#ff6b70" },
        ink: { DEFAULT: "#f6f6f8", muted: "#a4a4b2", dim: "#6e6e80" },
        gold: { DEFAULT: "#f5a524", soft: "#ffc86b" },
        aqua: { DEFAULT: "#22d3ee", soft: "#7ee7f7" },
        iris: { DEFAULT: "#8b5cf6", soft: "#b79bff" },
        ok: "#22c55e", warn: "#f5a524", danger: "#ef4444", info: "#38bdf8",
      },
      fontFamily: { sans: ['"Inter"', "system-ui", "sans-serif"] },
      boxShadow: {
        focus: "0 0 0 3px rgba(229,9,20,.8), 0 0 26px rgba(229,9,20,.35)",
        card: "0 10px 30px -12px rgba(0,0,0,.85)",
      },
      animation: {
        "fade-in": "fadeIn .32s ease-out both",
        "slide-up": "slideUp .38s cubic-bezier(.2,.8,.2,1) both",
        "pop-in": "popIn .22s cubic-bezier(.2,.9,.3,1.3) both",
        drift: "drift 26s ease-in-out infinite alternate",
      },
      keyframes: {
        fadeIn: { "0%": { opacity: "0" }, "100%": { opacity: "1" } },
        slideUp: { "0%": { opacity: "0", transform: "translateY(14px)" }, "100%": { opacity: "1", transform: "translateY(0)" } },
        popIn: { "0%": { opacity: "0", transform: "scale(.94)" }, "100%": { opacity: "1", transform: "scale(1)" } },
        drift: { "0%": { transform: "translate3d(-4%, -2%, 0) scale(1)" }, "100%": { transform: "translate3d(5%, 3%, 0) scale(1.12)" } },
      },
    },
  },
  plugins: [],
};
