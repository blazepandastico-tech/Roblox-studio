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
| CombatService | validazione dei colpi del client (distanza, frequenza, velocità) |
| QuestService / StoryService | missioni ripetibili e storia in 17 capitoli |
| SerumService / ShifterService | sieri e trasformazioni (bloccati da `Config.Serums.Available`) |
| ShopService | armerie, laboratorio, mercante |
| MonetizationService | gemme, Developer Products (`ProcessReceipt`), Game Pass, negozio delle gemme |
| RaidService | raid a ondate nell'Arena (lobby, ondate, boss, ricompense) |
| NPCService | personaggi, dialoghi, traghetti tra le isole |
| SupplyService / CodesService | rifornimenti e codici regalo |

## Client
- `ODMController`: fisica dei rampini a gas lato client (tensione delle funi, gas, sterzata).
- `CombatController`: combo, abilità, mira alla nuca; il server convalida tutto.
- `AnimationController` + `shared/Anim/ProceduralAnimator`: animazioni procedurali via `Motor6D.Transform`
  (pose e clip in `shared/Anim/Poses.lua`), condivise tra umani e giganti.
- `TitanAnimator`: anima i giganti dagli attributi inviati dal server.
- UI: HUD, Menu, Dialoghi (ritratto 3D), Negozi, Premium, Raid, Intro.

## Dati (shared/Data)
Items, Serums, Bloodlines, Titans, Enemies, WorldLayout (isole), Zones, NPCs, Quests, Story, Shops,
Skills, Leveling, StatsCalc, Raids, Monetization, Sounds, AnimationIds.

## Verifiche
- `tools/check_refs.py`: ogni `S.X.Y` / `C.X.Y` esiste, ogni remote è dichiarata, ogni `require` punta a un file.
- `tools/test_data.py`: carica i dati con l'interprete `luau` e controlla migliaia di riferimenti
  (storia, missioni, PNG, isole e zone che non si sovrappongono, raid, negozio premium, curve dei livelli).
