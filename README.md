# StreamBox

Reproductor IPTV moderno (PWA). No incluye contenido: cada usuario agrega su propia lista M3U/M3U8.

## Uso

```
npm install
npm start          # proxy (3001) + app (5173)
```

Abre http://localhost:5173. En el movil (misma red wifi): http://IP-DE-TU-PC:5173

## Produccion

```
npm run build
npm run server     # sirve dist/ y el proxy en http://localhost:3001
```

Para instalar la PWA en el movil necesitas HTTPS (un hosting con certificado o un tunel).

## Notas

- El proxy (`server/index.js`) evita CORS y mixed content y reescribe los .m3u8 para que los segmentos pasen por el proxy.
- No lo expongas publicamente sin autenticacion: es un proxy abierto.
