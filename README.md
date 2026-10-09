# Calcio Fuorilegge

Calcio caotico 4 contro 4 per Roblox (nome provvisorio). Tutto il codice e' originale.

## Come aprirlo
- **Facile:** apri `CalcioFuorilegge.rbxl` con Roblox Studio (File > Open from File; `CalcioFuorilegge.rbxlx` e' lo stesso contenuto in
  XML, da usare se il primo non si apre). La mappa (stadio, lobby, scenario) e' gia' dentro il file: la vedi appena apri, nell'Explorer
  sta in `Workspace > World`. Il canyon di Terrain si costruisce in pochi secondi quando premi Play (oppure a mano, vedi `tools/bake/README.md`).
  In *Game Settings > Avatar* imposta **R15**. Premi Play (o Test > Clients and Servers con 2+ giocatori).
  Nella finestra *Output* compaiono righe `[Calcio Fuorilegge] ...` che dicono a che punto e' l'avvio; se qualcosa non va, l'errore e' li'.
- **Con Rojo:** `rojo serve` (usa `default.project.json`): place vuoto, la mappa si costruisce tutta da codice al Play.
- Per rigenerare il file dopo modifiche a `src/`: `python3 tools/bake/bake_map.py` (vedi `tools/bake/README.md`).
  `python3 tools/build_rbxlx.py` scrive invece un file leggero con i soli script (`CalcioFuorilegge_solo_script.rbxlx`).

Tutti i numeri di bilanciamento sono in `src/ReplicatedStorage/Config.lua`.

## La mappa: Canyon del Deserto
Si costruisce da codice (`MapBuilder.lua` + moduli in `src/ServerScriptService/Server/Map/`): `tools/bake` la scrive anche dentro il
file `.rbxlx`, e allora `MapBuilder.Build()` la salta (attributo `Baked` su `workspace.World`). Il canyon (Terrain) richiede qualche
secondo: viene creato in parallelo all'avvio, il resto e' subito giocabile.

| Modulo | Cosa fa |
|---|---|
| `Layout.lua` | misure condivise (campo, tribune, torri, lobby) derivate da `Config.Field` |
| `Atmosphere.lua` | luce da tramonto, foschia, nuvole, bagliore, raggi di sole |
| `Pitch.lua` | campo di terra a 18 strisce, righe lilla luminose, aree colorate, stemma centrale |
| `Goals.lua` | porte con pali di pietra e rete a nido d'ape luminosa |
| `Arena.lua` | piazza, pareti di vetro con telaio e rotaie, pubblicita' LED, angoli smussati, 2 tribune con ~290 tifosi, tabelloni segnapunti, torri faro, coriandoli |
| `Terrain.lua` | pareti del canyon a strati rosso/arancio, torri di roccia, dune, fiume, saline |
| `Props.lua` | cactus, cespugli, rocce agganciabili, parabole, pali con cavi, relitto d'aereo, mulini, avvoltoi, passerella e ponte, ascensore |
| `LobbyBuilder.lua` | baita di legno sul belvedere sopra la valle, terrazza, pedane ROSSA/BLU, cartelli, camino, trofeo |

Il sole al tramonto sta in fondo al canyon (asse X), cosi' le pareti alte non fanno ombra sullo stadio.
Il lato Rossi difende -X, i Blu +X. Rocce, torri faro e pali della luce hanno il tag `Grappable` (per il rampino della Fase 2).

Lato client, `Modules/Ambient.lua` anima tifosi, tabelloni segnapunti (punteggio e tempo in tempo reale), pale dei mulini,
parabole, luci di segnalazione, avvoltoi e i coriandoli del goal.

## Stato
- [x] Fase 1 - base giocabile (+ mappa rifatta e lobby sul belvedere)
- [ ] Fase 2 - gadget
- [ ] Fase 3 - animazioni ed effetti
- [ ] Fase 4 - seconda mappa, replay, supplementari, titoli
- [ ] Fase 5 - monete/XP, estrazioni, negozio, classifiche, salvataggi
- [ ] Fase 6 - mobile/console, impostazioni, bilanciamento

## Strumenti di sviluppo (opzionali)
`tools/preview/`: esegue il codice della mappa fuori da Studio con una mini-emulazione dell'API Roblox, controlla ogni
proprieta'/enum/metodo contro l'API reale e produce un'anteprima 3D approssimata. Vedi `tools/preview/README.md`.

`tools/bake/`: scrive la mappa dentro il `.rbxlx` e prova il file nell'emulazione. Vedi `tools/bake/README.md`.
