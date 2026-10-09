# Architettura del codice

Progetto Rojo (`default.project.json`), tutto in Luau. Commenti e testi in italiano, identificatori in inglese.

```
src/shared  → ReplicatedStorage.Shared   (dati e librerie condivisi)
src/server  → ServerScriptService.Server (servizi del server)
src/client  → StarterPlayerScripts.Client (controller e interfaccia)
```

## Avvio
- `server/Main.server.lua` carica i servizi nell'ordine di `ORDER`, chiama `Init(S)` su tutti e poi `Start()`
  (ogni servizio è isolato con `pcall`: se uno fallisce gli altri continuano).
- `client/Main.client.lua` fa lo stesso con controller e moduli UI (registro `C`).
- Le remote sono dichiarate in `shared/Lib/Net.lua` (unico elenco di nomi).

## Servizi del server
| Servizio | Ruolo |
|---|---|
| DataService | profili con DataStore (blocco di sessione, salvataggio automatico, BindToClose) |
| WorldBuilder | genera l'arcipelago: oceano, isole, mura, città, foresta, sottosuolo, arena |
| LightingService / EventService | giorno-notte, atmosfera, annunci, invasioni, effetti |
| PlayerService | personaggio, statistiche, danni, livelli, oro, rinascita, zone visitate |
| InventoryService | inventario, equipaggiamento, consumabili |
| TitanService | giganti: IA, attacchi, arti recisi, nuca, boss, ondate dei raid |
| EnemyService | nemici umani (polizia corrotta, Squadra Ombra...) |
| CombatService | validazione dei colpi del client (distanza, frequenza, velocità), usura delle lame (di più sulle corazze), miccia delle Lance Dirompenti |
| ODMService | convalida dei Rampini: portata degli agganci, conteggio prudente del gas (`GasCap`), spostamenti non plausibili; inoltra i cavi agli altri giocatori |
| QuestService / StoryService | missioni ripetibili e storia in 17 capitoli |
| SerumService / ShifterService | sieri e trasformazioni (bloccati da `Config.Serums.Available`) |
| ShopService | armerie, laboratorio, mercante |
| MonetizationService | gemme, Developer Products (`ProcessReceipt`), Game Pass, negozio delle gemme |
| RaidService | raid a ondate nell'Arena (lobby, ondate, boss, ricompense) |
| NPCService | personaggi, dialoghi, traghetti tra le isole |
| SupplyService / CodesService | rifornimenti e codici regalo |

## Client
- `ODMController`: input, mira, sensori degli ostacoli e grafica dei rampini; la matematica del volo è in
  `shared/Modules/ODMPhysicsModule` (trazione che scala con vicinanza e angolo, pendolo, slancio cinetico),
  la stessa usata da `ODMService` per convalidare.
- `CombatController`: combo, abilità, mira alla nuca; il server convalida tutto.
- `AnimationController` + `shared/Anim/ProceduralAnimator`: animazioni procedurali via `Motor6D.Transform`
  (pose e clip in `shared/Anim/Poses.lua`), condivise tra umani e giganti.
- `TitanAnimator`: anima i giganti dagli attributi inviati dal server.
- UI: HUD, Menu, Dialoghi (ritratto 3D), Negozi, Premium, Raid, Intro.

## Dati (shared/Data)
Items, Serums, Bloodlines, Titans, Enemies, WorldLayout (isole), Zones, NPCs, Quests, Story, Shops,
Skills, Leveling, StatsCalc, Raids, Monetization, Sounds, AnimationIds.

## Rampini: chi decide cosa
Il client è il proprietario fisico del personaggio e simula il volo ogni frame (nessun ritardo).
Il server non ricalcola il volo ma lo sorveglia con le stesse formule:
- `Fire` viene accettato solo se il punto è entro la portata (+ tolleranza di latenza) e c'è gas;
  altrimenti il client riceve `ODMCorrect("Reject")` e sgancia, e gli altri non vedono il cavo.
- il gas del server è una stima per eccesso (consumi ×0,9, ricarica "a terra" entro 8 studs):
  il client non può mai superarlo, chi gioca onestamente non viene mai corretto.
- spostamenti oltre il massimo credibile per 2 campioni di fila → ritorno all'ultima posizione valida.
  I teletrasporti del server passano da `PlayerService.Teleport`, che concede un periodo di grazia.
Tutte le soglie sono in `Config.ODM.Validation` (`Enabled = false` per spegnere la convalida).

## Verifiche
- `tools/check_refs.py`: ogni `S.X.Y` / `C.X.Y` esiste, ogni remote è dichiarata, ogni `require` punta a un file.
- `tools/test_data.py`: carica i dati con l'interprete `luau` e controlla migliaia di riferimenti
  (storia, missioni, PNG, isole e zone che non si sovrappongono, raid, negozio premium, curve dei livelli).
