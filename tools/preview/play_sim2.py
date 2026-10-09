#!/usr/bin/env python3
"""Come play_sim.py, ma in piu' simula le azioni dei giocatori (calcio, scivolata, scatto, sprint, chiedi palla, goal, rientro in lobby).
uso: play_sim2.py <cartella src>"""
import os, sys
from lupa import LuaRuntime
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.abspath(sys.argv[1])
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().API_INDEX_PATH = os.path.join(here, 'api_index.lua')
lua.execute(open(os.path.join(here, 'robloxshim.lua'), encoding='utf-8').read())
lua.execute(open(os.path.join(here, 'sim.lua'), encoding='utf-8').read())
files = []
for dp, dn, fn in os.walk(src):
    for f in fn:
        if f.endswith('.lua'): files.append(os.path.relpath(os.path.join(dp, f), src))
lua.execute("function __mount(root, ...) __SHIM.mountFiles(root, {...}) end")
lua.globals().__mount(src, *sorted(files))
if os.environ.get('BAKED'):  # prova partendo dal .rbxlx "cotto" (tools/bake): la mappa arriva dal file
    sys.path.insert(0, os.path.join(here, '..', 'bake'))
    import bakedlib
    _n, _prob = bakedlib.import_baked(lua, os.environ['BAKED'])
    print('mappa importata dal file:', _n, 'istanze', ('PROBLEMI: ' + _prob) if _prob else '')
lua.globals().MAIN_SRC = open(os.path.join(src, 'ServerScriptService', 'Main.server.lua'), encoding='utf-8').read()
code = r'''
local sss = game:GetService("ServerScriptService")
local main = sss:FindFirstChild("Main")
local out = {}
local function say(s) out[#out + 1] = s end
local fn = load(MAIN_SRC, "Main", "t", setmetatable({ script = main }, { __index = _G }))
local co = coroutine.create(fn)
local ok, e = coroutine.resume(co)
if not ok then return "ERRORE in Main: " .. tostring(e) .. "\n" .. debug.traceback(co) end
local calls = {}
local function fmt(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end return table.concat(t, ", ") end
local remotes = game:GetService("ReplicatedStorage").Remotes
for _, r in ipairs(remotes:GetChildren()) do
  rawget(r, "_p").FireClient = function(_, plr, ...) calls[#calls + 1] = string.format("t=%.1f %s -> %s: %s", Sim.now, r.Name, plr.Name, fmt(...)) end
  rawget(r, "_p").FireAllClients = function(_, ...) calls[#calls + 1] = string.format("t=%.1f %s -> tutti: %s", Sim.now, r.Name, fmt(...)) end
end
local function R(name) return remotes:FindFirstChild(name) end
local anna = Sim.addPlayer("Anna")
local bruno = Sim.addPlayer("Bruno")
local dt = 1 / 30
local function phase() return tostring(workspace:GetAttribute("Phase")) end
-- fino al fischio d'inizio
Sim.run(16, dt)
say("t=" .. string.format("%.1f", Sim.now) .. " fase " .. phase())
Sim.run(4, dt)
say("t=" .. string.format("%.1f", Sim.now) .. " fase " .. phase())
local ball = workspace:FindFirstChild("Ball")
say("palla ancorata: " .. tostring(ball.Anchored))
-- metto Anna vicino alla palla, Bruno vicino ad Anna
local ac, bc = anna.Character, bruno.Character
ac:PivotTo(CFrame.new(ball.Position + Vector3.new(-2, 1, 0)))
bc:PivotTo(CFrame.new(ball.Position + Vector3.new(-4, 1, 1)))
-- sprint, controllo stretto, chiedi palla
R("Sprint").OnServerEvent:Fire(anna, true)
R("Control").OnServerEvent:Fire(anna, true)
R("CallBall").OnServerEvent:Fire(bruno)
Sim.run(1, dt)
-- calcio normale carico, poi passaggio, flick, lob, valori strani
R("Kick").OnServerEvent:Fire(anna, "normal", 0.8, Vector3.new(1, 0.2, 0.1), 0.5)
Sim.run(1, dt)
say("velocita' palla dopo il tiro: " .. string.format("%.1f", ball.AssemblyLinearVelocity.Magnitude))
ball.CFrame = CFrame.new(ac.HumanoidRootPart.Position + Vector3.new(2, 0, 0))
Sim.run(1, dt)
R("Kick").OnServerEvent:Fire(anna, "pass", 0, Vector3.new(-1, 0, 0), 0)
Sim.run(1, dt)
R("Kick").OnServerEvent:Fire(anna, "flick", 0, Vector3.new(0, 0, 1), 0)
R("Kick").OnServerEvent:Fire(anna, "lob", 0.5, Vector3.new(0, 0.5, 1), 0)
R("Kick").OnServerEvent:Fire(anna, "boh", 0.5, Vector3.new(0, 0.5, 1), 0)
R("Kick").OnServerEvent:Fire(anna, 5, "x", nil, nil)
-- scivolata e scatto
R("Tackle").OnServerEvent:Fire(anna, Vector3.new(-1, 0, 0.3))
Sim.run(1.2, dt)
R("Dash").OnServerEvent:Fire(bruno, Vector3.new(0, 0, 1))
Sim.run(1, dt)
R("Tackle").OnServerEvent:Fire(bruno, nil)
Sim.run(1.2, dt)
-- ragdoll finisce
Sim.run(5, dt)
-- goal: la palla entra nella porta dei Blu (+X)
local Config = require(game:GetService("ReplicatedStorage").Config)
ball.Anchored = true
ball.CFrame = CFrame.new(Config.Field.Length / 2 + 6, 3, 0)
ball.Anchored = false
Sim.run(1, dt)
say("t=" .. string.format("%.1f", Sim.now) .. " fase " .. phase() .. "  punteggio " .. tostring(workspace:GetAttribute("ScoreRed")) .. " - " .. tostring(workspace:GetAttribute("ScoreBlue")))
Sim.run(8, dt)
say("t=" .. string.format("%.1f", Sim.now) .. " fase " .. phase())
-- uno esce, uno rientra in lobby
R("ReturnLobby").OnServerEvent:Fire(bruno)
Sim.run(2, dt)
Sim.removePlayer(bruno)
Sim.run(2, dt)
R("JoinQueue").OnServerEvent:Fire(anna)
-- muore e rinasce
anna.Character.Humanoid.Died:Fire()
Sim.run(4, dt)
-- fino alla fine della partita
Sim.run(380, dt)
say("t=" .. string.format("%.1f", Sim.now) .. " fase " .. phase() .. "  " .. tostring(workspace:GetAttribute("ResultText")))
say("personaggi caricati: " .. #Sim.log)
for i = 1, #calls do say("remote: " .. calls[i]) end
return table.concat(out, "\n")
'''
print(lua.execute(code))
rep = lua.execute('local t = {} for k in pairs(__SHIM.stubs) do t[#t+1] = k end table.sort(t) return table.concat(__SHIM.problems, "\\n"), table.concat(t, ", ")')
print('PROBLEMI:', rep[0] or '(nessuno)')
print('stub:', rep[1])
