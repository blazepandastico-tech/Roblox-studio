#!/usr/bin/env python3
"""Prova il .rbxlx "cotto" nello shim: la mappa arriva DAL FILE, poi gira il vero Main.server.lua con giocatori finti.
Controlla che: il file si importi senza problemi (ogni proprieta' passa la verifica API dello shim), la mappa NON venga ricostruita,
il terreno si costruisca una volta sola, la partita giri (fasi, punteggio) e lo shim non segnali problemi.
uso: test_baked.py <CalcioFuorilegge.rbxlx> [minuti]"""
import os
import sys

from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PREVIEW = os.path.join(ROOT, "tools", "preview")
SRC = os.path.join(ROOT, "src")
sys.path.insert(0, HERE)
import bakedlib  # noqa: E402


def make_runtime(api_index):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().API_INDEX_PATH = api_index
    lua.execute(open(os.path.join(PREVIEW, "robloxshim.lua"), encoding="utf-8").read())
    lua.execute(open(os.path.join(PREVIEW, "sim.lua"), encoding="utf-8").read())
    files = []
    for dp, _, fn in os.walk(SRC):
        for f in fn:
            if f.endswith(".lua"):
                files.append(os.path.relpath(os.path.join(dp, f), SRC))
    lua.execute("function __mount(root, ...) __SHIM.mountFiles(root, {...}) end")
    lua.globals().__mount(SRC, *sorted(files))
    lua.globals().MAIN_SRC = open(os.path.join(SRC, "ServerScriptService", "Main.server.lua"), encoding="utf-8").read()
    return lua


COUNT = r"""
local function census(root)
	local c, n = {}, 0
	for _, d in ipairs(root:GetDescendants()) do
		c[d.ClassName] = (c[d.ClassName] or 0) + 1
		n = n + 1
	end
	return c, n
end
"""


def main():
    rbxlx = os.path.abspath(sys.argv[1])
    minutes = float(sys.argv[2]) if len(sys.argv) > 2 else 4
    api_index = os.path.join(PREVIEW, "api_index.lua")
    fails = []

    # riferimento: la mappa costruita da codice
    ref = make_runtime(api_index)
    ref_counts = ref.execute(
        COUNT
        + r"""
local MapBuilder = require(game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("MapBuilder"))
local world = MapBuilder.BuildStatic()
local c, n = census(world)
local lc, ln = census(game:GetService("Lighting"))
local out = { "World=" .. n, "Lighting=" .. ln }
local names = {}
for k in pairs(c) do names[#names + 1] = k end
table.sort(names)
for _, k in ipairs(names) do out[#out + 1] = k .. "=" .. c[k] end
return table.concat(out, ",")
"""
    )

    # prova: la mappa arriva dal file
    lua = make_runtime(api_index)
    n, problems = bakedlib.import_baked(lua, rbxlx)
    print("importate dal file: %d istanze" % n)
    if problems:
        fails.append("importazione: " + problems)
        print("PROBLEMI DI IMPORTAZIONE:\n" + problems[:3000])
    got_counts = lua.execute(
        COUNT
        + r"""
local world = workspace:FindFirstChild("World")
if not world then return "NESSUN World" end
local c, n = census(world)
local lc, ln = census(game:GetService("Lighting"))
local out = { "World=" .. n, "Lighting=" .. ln }
local names = {}
for k in pairs(c) do names[#names + 1] = k end
table.sort(names)
for _, k in ipairs(names) do out[#out + 1] = k .. "=" .. c[k] end
return table.concat(out, ",")
"""
    )
    # i Clouds dentro Terrain sono nel conteggio di World? no: sono fuori. Confronto solo World + Lighting
    if got_counts != ref_counts:
        fails.append("il World importato non ha le stesse istanze di quello costruito da codice")
        print("codice:", ref_counts)
        print("file:  ", got_counts)
    else:
        print("istanze per classe uguali a quelle della mappa costruita da codice:", ref_counts.split(",")[0], ref_counts.split(",")[1])

    lua.globals().MINUTES = minutes
    res = lua.execute(
        COUNT
        + r"""
local out = {}
local function say(s) out[#out + 1] = s end
local world0 = workspace:FindFirstChild("World")
local _, before = census(world0)
local main = game:GetService("ServerScriptService"):FindFirstChild("Main")
local fn, err = load(MAIN_SRC, "Main", "t", setmetatable({ script = main }, { __index = _G }))
if not fn then return "ERR load " .. tostring(err) end
local co = coroutine.create(fn)
local ok, e = coroutine.resume(co)
if not ok then return "ERRORE in Main: " .. tostring(e) .. "\n" .. debug.traceback(co) end
local worlds = 0
for _, c in ipairs(workspace:GetChildren()) do if c.Name == "World" then worlds = worlds + 1 end end
local _, after = census(world0)
say("cartelle World nel workspace: " .. worlds)
say("istanze dentro World prima/dopo Main: " .. before .. " / " .. after)
-- partita
local p1 = Sim.addPlayer("Anna")
local p2 = Sim.addPlayer("Bruno")
local lastPhase
local phases = {}
Sim.run(MINUTES * 60, 1 / 30, function()
	local ph = workspace:GetAttribute("Phase")
	if ph ~= lastPhase then
		phases[#phases + 1] = string.format("%.0fs:%s", Sim.now, tostring(ph))
		lastPhase = ph
	end
end)
say("fasi: " .. table.concat(phases, " "))
say("personaggi caricati: " .. #Sim.log)
-- il terreno si costruisce a fette (task.wait ogni 20 operazioni): a fine simulazione deve essere finito
local ops = 0
local T = rawget(workspace.Terrain, "_terrain")
if T then ops = #T.ops end
say("operazioni di terreno registrate: " .. ops)
say("Terrain.CanyonBuilt: " .. tostring(workspace.Terrain:GetAttribute("CanyonBuilt")))
return table.concat(out, "\n"), worlds, before, after, ops, workspace.Terrain:GetAttribute("CanyonBuilt") == true
"""
    )
    text = res[0]
    print(text)
    worlds, before, after, ops, built = res[1], res[2], res[3], res[4], res[5]
    if worlds != 1:
        fails.append("c'e' piu' di una cartella World (%s)" % worlds)
    if before != after:
        fails.append("Main ha ricostruito/modificato la mappa gia' presente nel file (%s -> %s)" % (before, after))
    if not ops or ops < 100 or not built:
        fails.append("il terreno non e' stato costruito all'avvio (%s operazioni, CanyonBuilt=%s)" % (ops, built))
    if "ERRORE" in text:
        fails.append("Main si e' fermato")
    rep = lua.execute("return table.concat(__SHIM.problems, '\\n')")
    print("PROBLEMI DELLO SHIM:", rep or "(nessuno)")
    if rep:
        fails.append("problemi dello shim")
    if "Playing" not in text:
        fails.append("la partita non e' mai arrivata alla fase Playing")
    print("\nRISULTATO:", "OK" if not fails else "FALLITO")
    for f in fails:
        print("  -", f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
