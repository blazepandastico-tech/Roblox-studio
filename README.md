# Calcio Fuorilegge

Calcio caotico 4 contro 4 per Roblox (nome provvisorio). Tutto il codice e' originale.

## Come aprirlo
- **Facile:** apri `CalcioFuorilegge.rbxlx` con Roblox Studio (File > Open from File).
  In *Game Settings > Avatar* imposta **R15**. Premi Play (o Test > Clients and Servers con 2+ giocatori).
- **Con Rojo:** `rojo serve` (usa `default.project.json`).
- Per rigenerare il file dopo modifiche a `src/`: `python3 tools/build_rbxlx.py`.

La mappa e la lobby sono costruite da codice all'avvio (`MapBuilder.lua`).
Tutti i numeri di bilanciamento sono in `src/ReplicatedStorage/Config.lua`.

## Stato
- [x] Fase 1 - base giocabile
- [ ] Fase 2 - gadget
- [ ] Fase 3 - animazioni ed effetti
- [ ] Fase 4 - seconda mappa, replay, supplementari, titoli
- [ ] Fase 5 - monete/XP, estrazioni, negozio, classifiche, salvataggi
- [ ] Fase 6 - mobile/console, impostazioni, bilanciamento
