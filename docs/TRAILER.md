# Trailer del gioco

Due video pronti in `assets/trailer/`:

| File | Formato | Dove usarlo |
|---|---|---|
| `SieriPerduti_Trailer.mp4` | 1920×1080 (orizzontale), circa 32 s | YouTube, Discord, pagina del gruppo Roblox |
| `SieriPerduti_Trailer_Verticale.mp4` | 1080×1920 (verticale) | TikTok, YouTube Shorts, Instagram Reels |

La musica è stata creata apposta per il trailer: nessun problema di copyright.

## Cosa si vede

1. "Un tempo le mura ci proteggevano..." nel buio
2. Un gigante enorme che spunta dalle mura durante il temporale
3. Il Gigante della Furia che urla in mezzo alla città
4. Il volo con il dispositivo di manovra tra i tetti
5. Il colpo alla nuca nel temporale
6. Il volo sopra l'isola con la città murata e i giganti che arrivano
7. La città piena di vita: cittadini, mercati
8. Il raid nell'arena contro il boss
9. I Sieri dei Giganti (in arrivo)
10. Logo, "GIOCA ORA SU ROBLOX" e il codice regalo

## Testo da mettere sotto il video

```
⚔️ I GIGANTI SONO TORNATI! Vola con il dispositivo di manovra, colpisci la nuca e salva l'arcipelago.
🗺️ 5 isole • 📖 storia in 4 stagioni • 🔥 raid • 📈 livello 2000
Gioca GRATIS su Roblox: cerca "Sieri Perduti" 🎁 Codice: SIERIPERDUTI
#roblox #robloxgame #giganti #anime #robloxedit
```

## Consigli per farlo girare

- **TikTok e Shorts:** pubblica la versione verticale. I primi 2 secondi contano tantissimo:
  - se i video non partono bene, taglia l'introduzione nera e fai partire il video dal gigante dietro le mura;
  - puoi farlo con CapCut.
- **Musica di tendenza:** su TikTok puoi aggiungere una musica di tendenza al posto della nostra, dall'app.
- **Link nella bio:** metti il link del gioco nella bio.
- **Quando pubblicare:** pubblica nel pomeriggio, verso le 17-19, quando i ragazzi escono da scuola.
- **Continuità:** pubblica anche clip brevi di partite vere registrate in Roblox Studio (tasto F12 o registratore dello schermo).
  I trailer funzionano meglio insieme ai video di gioco vero.

Il trailer si rifà con `tools/thumbnails/trailer.py`:
- `renderall` calcola i fotogrammi;
- `music` crea la musica;
- `edit` monta il video.
