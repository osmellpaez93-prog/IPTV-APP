import React from "react";
import ReactDOM from "react-dom/client";
import "@fontsource/inter/400.css";
import "@fontsource/inter/600.css";
import "@fontsource/inter/700.css";
import "./index.css";
import { App } from "./App";
import { installMSEGuard } from "./services/mseGuard";

// Debe ejecutarse antes de crear cualquier MediaSource (reproductores, etc.)
installMSEGuard();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
