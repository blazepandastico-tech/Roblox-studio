# Trailer del gioco

I video sono in `assets/trailer/`. La musica è stata composta apposta per i trailer: non ci sono problemi di copyright.

| File | Formato | Dove usarlo |
|---|---|---|
| `SieriPerduti_Lancio.mp4` | 1920×1080, 42 s | YouTube, Discord, pagina del gioco e del gruppo Roblox |
| `SieriPerduti_Lancio_Verticale.mp4` | 1080×1920, 42 s | TikTok, YouTube Shorts, Instagram Reels |
| `SieriPerduti_Halloween.mp4` | 1920×1080, 40 s | annuncio dell'aggiornamento di Halloween |
| `SieriPerduti_Halloween_Verticale.mp4` | 1080×1920, 40 s | TikTok, Shorts, Reels per Halloween |

Il vecchio trailer (`SieriPerduti_Trailer.mp4`, fatto con scene generiche prima della grafica nuova) è
ancora nella stessa cartella.

**Le immagini sono simulate.** Il mondo, i giganti, il cadetto e i menu sono quelli veri del gioco: vengono
costruiti con il codice del gioco e disegnati dal motore di `tools/thumbnails/engine.py`. Non sono però riprese
di Roblox Studio, quindi luci e materiali in Roblox saranno un po' diversi. Le telecamere si muovono dentro foto
chiave del mondo con la prospettiva giusta. Vapore, pioggia, foglie, pipistrelli e fantasmi sono aggiunti al montaggio.

## Trailer di lancio (niente Halloween)

1. "Un tempo le Mura ci proteggevano..." nel buio, con le braci.
2. Le Mura di notte sotto la pioggia, i lampi: "Poi tornarono i GIGANTI."
3. La fila dei giganti fuori dal cancello, con il vapore: "Sono enormi... e hanno fame."
4. Il volto di un gigante da vicino.
5. Il cadetto che vola tra i tetti di Calaneth con i rampini e la scia di gas.
6. Il cadetto che si lancia sulla nuca di un gigante: "COLPISCI LA NUCA!"
7. L'isola di Vermiglia dall'alto: "5 isole. Un arcipelago tutto da esplorare."
8. Il mercato di Calaneth, la città di notte con le lucciole, Aurion, il campo d'addestramento.
9. Il colosso che spunta dalle Mura: "I GIGANTI PIÙ GRANDI TI ASPETTANO".
10. Giganti tutti diversi, poi il logo, "GIOCA ORA GRATIS SU ROBLOX" e il codice regalo `SIERIPERDUTI`.

Testo da mettere sotto il video:

```
⚔️ I GIGANTI SONO TORNATI! Vola tra i tetti con i rampini, colpisci la nuca e salva l'arcipelago.
🗺️ 5 isole • 📖 storia in 4 stagioni • 🔥 raid e boss • 🐎 cavalli e barche • 📈 fino al livello 2000
Gioca GRATIS su Roblox: cerca "Sieri Perduti" 🎁 Codice: SIERIPERDUTI
#roblox #robloxgame #giganti #anime #robloxedit
```

## Trailer di Halloween

1. "Questa notte le Mura sono infestate..." con i pipistrelli e un lampo viola.
2. Le Mura di notte, nebbia e pipistrelli: "🎃 AGGIORNAMENTO DI HALLOWEEN".
3. Case e giardini infestati, con fantasmi e fuochi fatui.
4. La strada del mercato con le foglie d'autunno: zucche, lapidi, ragnatele e candele.
5. I giganti in costume (zucca, strega, zombie, corna, scheletro): "I GIGANTI SI TRAVESTONO!"
6. Il Re Zucca e il Gigante Fantasma da vicino.
7. I titoli dei 5 nuovi eventi Admin Abuse, uno dopo l'altro.
8. Il pannello Admin Abuse: premi (dolcetti, premio finale, bonus doppi) e programmazione per giorno e ora.
9. Il campo di notte con pipistrelli e fuochi fatui, poi l'arcipelago in festa.
10. La nuova schermata iniziale di Halloween e "🎃 ORA SU ROBLOX 🎃".

Testo da mettere sotto il video:

```
🎃 HALLOWEEN È ARRIVATO SU SIERI PERDUTI! Le Mura sono infestate e i giganti si sono travestiti.
👻 5 nuovi eventi • 🍬 dolcetti e premi • 🎃 Re Zucca e Gigante Fantasma • 🦇 tutto l'arcipelago infestato
Gioca GRATIS su Roblox: cerca "Sieri Perduti" — solo per Halloween!
#roblox #halloween #robloxhalloween #giganti #anime
```

## Consigli per farlo girare

- **TikTok e Shorts:** pubblica la versione verticale. I primi 2 secondi contano tantissimo: se vuoi partire
  subito dall'azione, taglia l'introduzione nera con CapCut.
- **Musica di tendenza:** su TikTok puoi mettere una musica di tendenza al posto della nostra, dall'app.
- **Link nella bio:** metti il link del gioco nella bio.
- **Quando pubblicare:** il pomeriggio, verso le 17-19, quando i ragazzi escono da scuola. Il trailer di
  Halloween conviene pubblicarlo nell'ultima settimana di ottobre.
- **Continuità:** aggiungi anche clip brevi di partite vere registrate in Roblox Studio (registratore dello
  schermo). I trailer funzionano meglio insieme ai video di gioco vero.

## Rifare i video

```bash
python3 tools/trailer_video.py chiavi lancio cartella_lancio          # foto chiave del mondo vero (lente)
python3 tools/trailer_video.py musica lancio musica_lancio.wav
python3 tools/trailer_video.py monta lancio cartella_lancio musica_lancio.wav Lancio.mp4 Lancio_Verticale.mp4 --caratteri fonts

python3 tools/trailer_video.py chiavi halloween cartella_halloween
python3 tools/trailer_video.py menu halloween cartella_halloween --caratteri fonts   # menu ed eventi (tools/ui_photo.py)
python3 tools/trailer_video.py musica halloween musica_halloween.wav
python3 tools/trailer_video.py monta halloween cartella_halloween musica_halloween.wav Halloween.mp4 Halloween_Verticale.mp4 --caratteri fonts
```

Inquadrature, movimenti della telecamera, effetti e testi sono in `tools/trailer_video.py`
(`KEYS`, `shots_lancio`, `shots_halloween`). I caratteri sono i pacchetti npm `@fontsource` (vedi `docs/HALLOWEEN.md`).
Il vecchio trailer si rifà con `tools/thumbnails/trailer.py`.
