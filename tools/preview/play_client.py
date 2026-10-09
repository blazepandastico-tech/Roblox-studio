#!/usr/bin/env python3
"""Server + client nello stesso shim: avvia Main, poi esegue Client.client.lua (HUD, effetti, ambiente, input) e simula eventi.
uso: play_client.py <cartella src>"""
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
lua.globals().MAIN_SRC = open(os.path.join(src, 'ServerScriptService', 'Main.server.lua'), encoding='utf-8').read()
lua.globals().CLIENT_SRC = open(os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts', 'Client.client.lua'), encoding='utf-8').read()
code = r'''
local out = {}
local function say(s) out[#out + 1] = s end
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local main = game:GetService("ServerScriptService"):FindFirstChild("Main")
local co = coroutine.create(load(MAIN_SRC, "Main", "t", setmetatable({ script = main }, { __index = _G })))
local ok, e = coroutine.resume(co)
if not ok then return "ERRORE in Main: " .. tostring(e) end
local anna = Sim.addPlayer("Anna")
local bruno = Sim.addPlayer("Bruno")
Sim.run(21, 1 / 30)
-- ---- passo al client
rawset(RunService, "IsServer", function() return false end)
rawset(RunService, "IsClient", function() return true end)
rawset(Players, "LocalPlayer", anna)
local pg = Instance.__internal("PlayerGui"); pg.Name = "PlayerGui"; pg.Parent = anna
local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ls = sps:FindFirstChild("Client")
Sim.client = true
local fn, err = load(CLIENT_SRC, "Client", "t", setmetatable({ script = ls }, { __index = _G }))
if not fn then return "ERR load client: " .. tostring(err) end
local cco = coroutine.create(fn)
local ok2, e2 = coroutine.resume(cco)
if not ok2 then return "ERRORE nel client: " .. tostring(e2) .. "\n" .. debug.traceback(cco) end
say("Client eseguito (" .. coroutine.status(cco) .. ")")
local n = 0
for _, d in ipairs(pg:GetDescendants()) do n = n + 1 end
say("istanze nella PlayerGui: " .. n)
-- eventi dal server verso il client
local remotes = game:GetService("ReplicatedStorage").Remotes
remotes.Notify.OnClientEvent:Fire("Prova notifica")
remotes.GoalScored.OnClientEvent:Fire("Red", "Anna", "Bruno", false)
remotes.GoalScored.OnClientEvent:Fire("Blue", "Bruno", "", true)
Sim.run(6, 1 / 30)
-- cambi di fase e punteggi (come li imposta il server)
workspace:SetAttribute("ScoreRed", 3); workspace:SetAttribute("ScoreBlue", 2)
for _, ph in ipairs({ "Intermission", "Kickoff", "Playing", "Goal", "Ended" }) do
  workspace:SetAttribute("Phase", ph); workspace:SetAttribute("PhaseEnd", Sim.now + 5)
  if ph == "Ended" then workspace:SetAttribute("ResultText", "Vincono i Rossi!  3 - 2") end
  Sim.run(2, 1 / 30)
end
anna:SetAttribute("Stamina", 2.5)
Sim.run(2, 1 / 30)
say("fine simulazione client a t=" .. string.format("%.1f", Sim.now))
return table.concat(out, "\n")
'''
print(lua.execute(code))
rep = lua.execute('local t = {} for k in pairs(__SHIM.stubs) do t[#t+1] = k end table.sort(t) return table.concat(__SHIM.problems, "\\n"), table.concat(t, ", ")')
print('PROBLEMI:', rep[0] or '(nessuno)')
print('stub:', rep[1])
