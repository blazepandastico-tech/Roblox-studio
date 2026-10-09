#!/usr/bin/env python3
"""Esegue il VERO Main.server.lua nello shim con scheduler e giocatori finti, per alcuni minuti di tempo simulato.
uso: play_sim.py <cartella src> [minuti]"""
import os, sys
from lupa import LuaRuntime
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.abspath(sys.argv[1]); minutes = float(sys.argv[2]) if len(sys.argv) > 2 else 4
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
lua.globals().MAIN_SRC = open(os.path.join(src, 'ServerScriptService', 'Main.server.lua'), encoding='utf-8').read()
lua.globals().MINUTES = minutes
code = r'''
local sss = game:GetService("ServerScriptService")
local main = sss:FindFirstChild("Main")
local out = {}
local function say(s) out[#out + 1] = s end
local fn, err = load(MAIN_SRC, "Main", "t", setmetatable({ script = main }, { __index = _G }))
if not fn then return "ERR load " .. tostring(err) end
local co = coroutine.create(fn)
local ok, e = coroutine.resume(co)
if not ok then return "ERRORE in Main: " .. tostring(e) .. "\n" .. debug.traceback(co) end
say("Main eseguito fino in fondo (" .. coroutine.status(co) .. ")")
local world = workspace:FindFirstChild("World")
say("workspace.World presente: " .. tostring(world ~= nil))
local n = 0
if world then for _, d in ipairs(world:GetDescendants()) do n = n + 1 end end
say("istanze dentro World: " .. n)
-- registro delle chiamate ai RemoteEvent
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local calls = {}
if remotes then
  for _, r in ipairs(remotes:GetChildren()) do
    rawget(r, "_p").FireClient = function(_, plr, ...) calls[#calls + 1] = r.Name .. " -> " .. tostring(plr.Name) .. ": " .. table.concat((function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end return t end)(...), ", ") end
    rawget(r, "_p").FireAllClients = function(_, ...) calls[#calls + 1] = r.Name .. " -> tutti: " .. table.concat((function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end return t end)(...), ", ") end
  end
end
-- giocatori
local p1 = Sim.addPlayer("Anna")
local p2 = Sim.addPlayer("Bruno")
local lastPhase = nil
local function hook(i)
  local ph = workspace:GetAttribute("Phase")
  if ph ~= lastPhase then
    say(string.format("t=%6.1fs  fase %-12s  Rossi %s - Blu %s  tempo %s  squadre: %s/%s", Sim.now, tostring(ph), tostring(workspace:GetAttribute("ScoreRed")), tostring(workspace:GetAttribute("ScoreBlue")), tostring(workspace:GetAttribute("TimeLeft")), tostring(p1.Team and p1.Team.Name), tostring(p2.Team and p2.Team.Name)))
    lastPhase = ph
  end
end
Sim.run(MINUTES * 60, 1 / 30, hook)
say("personaggi caricati: " .. #Sim.log)
for i = 1, math.min(#calls, 12) do say("remote: " .. calls[i]) end
return table.concat(out, "\n")
'''
print(lua.execute(code))
rep = lua.execute('local t = {} for k in pairs(__SHIM.stubs) do t[#t+1] = k end table.sort(t) return table.concat(__SHIM.problems, "\\n"), table.concat(t, ", ")')
print('PROBLEMI:', rep[0] or '(nessuno)')
print('stub:', rep[1])
