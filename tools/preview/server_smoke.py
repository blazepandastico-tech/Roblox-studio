import os, sys
from lupa import LuaRuntime
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.abspath(sys.argv[1])
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().API_INDEX_PATH = os.path.join(here, 'api_index.lua')
lua.execute(open(os.path.join(here, 'robloxshim.lua'), encoding='utf-8').read())
files = []
for dp, dn, fn in os.walk(src):
    for f in fn:
        if f.endswith('.lua'):
            files.append(os.path.relpath(os.path.join(dp, f), src))
lua.execute("function __mount(root, ...) __SHIM.mountFiles(root, {...}) end")
lua.globals().__mount(src, *sorted(files))
code = r'''
local Server = game:GetService("ServerScriptService").Server
local out = {}
local function step(name, fn)
	local ok, err = pcall(fn)
	out[#out + 1] = (ok and "OK    " or "ERRORE ") .. name .. (ok and "" or (" -> " .. tostring(err)))
end
local MapBuilder, Lobby, Ball, Net
step("require Net", function() Net = require(game:GetService("ReplicatedStorage").Net) end)
step("MapBuilder.Build", function() MapBuilder = require(Server.MapBuilder) MapBuilder.Build() end)
step("require Lobby", function() Lobby = require(Server.Lobby) end)
step("Lobby.Init", function() Lobby.Init() end)
step("pad counters", function()
	local pad = workspace.World.Lobby.Pads.RedPad
	assert(pad:GetAttribute("TeamKey") == "Red")
	Lobby.RefreshPads()
	local txt = pad.Contatore.Gui.Conteggio.Text
	assert(txt == "0 / 4", txt)
end)
step("LobbySpawnCFrame", function()
	local cf = MapBuilder.LobbySpawnCFrame()
	assert(cf.Position.Y > 60)
end)
step("require Ball", function() Ball = require(Server.Ball) end)
step("Ball.Create", function() Ball.Create() end)
step("require Match", function() require(Server.Match) end)
step("require Actions", function() require(Server.Actions) end)
step("require Stamina", function() require(Server.Stamina) end)
step("require Ragdoll", function() require(Server.Ragdoll) end)
return table.concat(out, "\n")
'''
print(lua.execute(code))
rep = lua.execute('local t = {} for k in pairs(__SHIM.stubs) do t[#t+1] = k end table.sort(t) return table.concat(__SHIM.problems, "\\n"), table.concat(t, ", ")')
print('PROBLEMI:', rep[0] or '(nessuno)')
print('stub:', rep[1])
