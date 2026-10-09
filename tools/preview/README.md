# Anteprima e controlli della mappa (senza Roblox Studio)

Questi strumenti servono a sviluppare la mappa senza aprire Studio. L'anteprima e' una **approssimazione** disegnata con three.js:
non e' il render di Roblox (luci, nebbia, texture e terreno sono simulati).

## Cosa c'e'
- `robloxshim.lua`: mini-emulazione dell'API Roblox in Lua. Con `api_index.lua` (generato dall'API dump ufficiale) **rifiuta**
  proprieta', enum, metodi e tipi che non esistono davvero: se il codice della mappa passa qui, i nomi sono corretti.
- `run_map.py`: esegue `MapBuilder.Build()` nello shim ed esporta la scena in JSON.
- `render_map.mjs` + `viewer_map.html` + `views.json`: disegnano il JSON (terreno a voxel con marching cubes, parti, testi dei cartelli, neon con bagliore).
- `geom_check.py`: controlla che niente di solido entri nel campo e che spawn e porte siano liberi.
- `ambient_test.py`, `server_smoke.py`: provano il modulo client `Ambient` e il caricamento dei moduli server.
- `sim.lua` + `play_sim.py`, `play_sim2.py`, `play_client.py`: **eseguono davvero** `Main.server.lua` (e `Client.client.lua`) con uno scheduler a tempo simulato
  e giocatori finti: ciclo di partita, calci, scivolate, goal, HUD. `server_smoke.py` NON esegue Main: un nome di proprieta' sbagliato in `Main.server.lua`
  (`Players.CharacterAutoLoad` invece di `CharacterAutoLoads`) era passato inosservato e impediva di costruire la mappa.
- `lint.cjs`: controllo di sintassi (luaparse).

## Come si usa
```bash
pip install lupa
python3 tools/preview/build_api_index.py            # scarica l'API dump e crea api_index.lua
python3 tools/preview/run_map.py src out.json        # costruisce la mappa nello shim (stampa problemi API)
python3 tools/preview/geom_check.py out.json
python3 tools/preview/ambient_test.py src
python3 tools/preview/server_smoke.py src
python3 tools/preview/play_sim.py src 9              # esegue Main + ciclo di partita per 9 minuti simulati
python3 tools/preview/play_sim2.py src               # + azioni dei giocatori (calcio, scivolata, scatto, goal, rientro in lobby)
python3 tools/preview/play_client.py src             # + client (HUD, effetti, ambiente)
BAKED=CalcioFuorilegge.rbxlx python3 tools/preview/play_sim.py src 4   # lo stesso, ma con la mappa letta DAL FILE .rbxlx (vedi tools/bake)

cd tools/preview && npm install                      # three + playwright-core (serve un Chromium: CHROMIUM_PATH=...)
node render_map.mjs ../../out.json shots all         # immagini in tools/preview/shots/
```
Il codice Lua del progetto resta nel sottoinsieme comune a Lua 5.3 e Luau (niente `continue`, `+=`, annotazioni di tipo).
