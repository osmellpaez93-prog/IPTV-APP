/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: { DEFAULT: "#0b0b0f", soft: "#14141b", card: "#1a1a23", hover: "#23232f" },
        brand: { DEFAULT: "#e50914", hover: "#ff1f2a" },
        ink: { DEFAULT: "#f5f5f7", muted: "#a1a1aa", dim: "#71717a" },
      },
      fontFamily: { sans: ['"Inter"', "system-ui", "sans-serif"] },
      animation: { "fade-in": "fadeIn .3s ease-out" },
      keyframes: { fadeIn: { "0%": { opacity: 0 }, "100%": { opacity: 1 } } },
    },
  },
  plugins: [],
};
