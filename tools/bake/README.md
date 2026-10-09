# Mappa "cotta" dentro il file .rbxlx

`python3 tools/bake/bake_map.py` scrive la mappa gia' costruita dentro `CalcioFuorilegge.rbxlx`: aprendo il file in Studio si vedono
subito stadio, lobby e scenario (anche senza premere Play), con gli script gia' al loro posto.

## Cosa entra nel file e cosa no
| Nel file | Costruito all'avvio |
|---|---|
| `workspace.World` (campo, porte, stadio, lobby, scenario: ~3000 parti, luci, cartelli, tag, attributi) | il **canyon di Terrain** (pareti, dune, fiume): i voxel non si scrivono nel file, `Terrain.lua` li costruisce in pochi secondi quando parte il gioco |
| `Lighting` (tramonto, foschia, bagliore, raggi) e le nuvole dentro `workspace.Terrain` | la palla, le squadre, i personaggi |
| gli script di `src/` | |

`workspace.World` porta l'attributo `Baked`: se c'e', `MapBuilder.Build()` non ricostruisce nulla e lancia solo il terreno.
Senza (place vuoto + Rojo, o file leggero di `tools/build_rbxlx.py`) costruisce tutto da codice come prima.

Il terreno si puo' costruire anche **da Studio, in modalita' Edit**, dalla Command Bar (View > Command Bar), una volta sola:
```lua
require(game.ServerScriptService.Server.Map.Terrain).Build()
```
Poi salva il file (Ctrl+S): il canyon resta nel place e al Play non viene rifatto (`workspace.Terrain` ha l'attributo `CanyonBuilt`;
per rifarlo da capo: `workspace.Terrain:Clear()` e cancella l'attributo).

## Come funziona (e perche' ci si puo' fidare)
1. `MapBuilder.BuildStatic()` gira nello shim Roblox (`tools/preview/robloxshim.lua`): ogni proprieta', enum e tipo e' verificato contro l'API vera.
2. `export_world.lua` scrive l'albero (istanze, proprieta', attributi, tag, riferimenti) come righe di testo.
3. `rbxbake` (Rust, `rbx_xml` + `rbx_reflection_database` di Rojo: le stesse librerie con cui Rojo scrive i .rbxlx) controlla
   proprieta' e tipi contro il database di Studio e scrive l'XML. Una proprieta' che l'encoder non sa scrivere e' un errore, non si perde in silenzio.
4. `bake_map.py` rilegge il file in modo rigoroso e lo confronta, riga per riga, con i record di partenza (0 differenze attese; i colori
   delle parti sono salvati a 8 bit come fa Studio, `Font` diventa `FontFace`, `Texture` diventa `TextureContent`).
5. `test_baked.py` importa il file nello shim (`import_world.lua`) e fa girare il vero `Main.server.lua` con giocatori finti:
   la mappa non viene ricostruita, il terreno parte una volta sola, la partita gira.

Mai provato in un vero Roblox Studio: lo shim e le librerie di Rojo sono un controllo forte, ma non sostituiscono un'apertura vera.

## Uso
```bash
pip install lupa
python3 tools/preview/build_api_index.py        # una volta: scarica l'API dump di Roblox e crea api_index.lua
python3 tools/bake/bake_map.py                  # scrive CalcioFuorilegge.rbxlx (compila rbxbake la prima volta: serve Rust)
python3 tools/bake/test_baked.py CalcioFuorilegge.rbxlx 4     # prova il file nello shim (4 minuti simulati)
BAKED=CalcioFuorilegge.rbxlx python3 tools/preview/play_sim2.py src   # idem, con azioni dei giocatori
```
Dopo ogni modifica a `src/` (mappa o script) rigenera il file con `bake_map.py`.
`tools/build_rbxlx.py` resta come alternativa senza Rust: file leggero con i soli script (la mappa si costruisce al Play).
