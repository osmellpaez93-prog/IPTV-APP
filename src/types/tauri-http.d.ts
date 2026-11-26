declare module "@tauri-apps/plugin-http" {
  export function fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response>;
}
