/**
 * Guard de MediaSource.
 *
 * Chrome/Edge (sin Dolby Access) NO soportan AC-3, E-AC-3, DTS ni TrueHD en MSE.
 * Cuando mpegts.js intenta addSourceBuffer('audio/mp4;codecs=ac-3') falla, pero
 * su demuxer sigue enviando datos -> bucle "appendBuffer: HTMLMediaElement.error
 * attribute is not null" y "Cannot read properties of null (reading 'emit')".
 *
 * Este guard intercepta addSourceBuffer ANTES de que eso ocurra: si el navegador
 * no soporta el codec de audio, lanza una excepcion limpia que mpegts.js captura
 * como ERROR, lo que permite pasar al siguiente candidato sin corromper el video.
 *
 * La deteccion es DINAMICA (MediaSource.isTypeSupported): en Firefox o Edge con
 * Dolby Access los codecs si se soportan y el guard no interfiere.
 */
const supported = new Map<string, boolean>();

export function isMSESupported(mime: string): boolean {
  if (typeof MediaSource === "undefined" || !MediaSource.isTypeSupported) return true;
  let v = supported.get(mime);
  if (v === undefined) {
    v = MediaSource.isTypeSupported(mime);
    supported.set(mime, v);
  }
  return v;
}

let installed = false;
export function installMSEGuard() {
  if (installed || typeof MediaSource === "undefined") return;
  installed = true;
  const orig = MediaSource.prototype.addSourceBuffer;
  MediaSource.prototype.addSourceBuffer = function (this: MediaSource, type: string) {
    // Solo bloqueamos pistas de AUDIO con codecs que el navegador no puede decodificar en MSE.
    if (/audio\//i.test(type) && !isMSESupported(type)) {
      throw new DOMException(`Audio codec no soportado por el navegador: ${type}`, "NotSupportedError");
    }
    return orig.call(this, type);
  };
}
