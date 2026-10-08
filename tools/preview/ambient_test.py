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
res = lua.execute(r'''
local Server = game:GetService("ServerScriptService").Server
require(Server.MapBuilder).Build()
-- il client
local mods = game:GetService("StarterPlayer").StarterPlayerScripts.Modules
local Ambient = require(mods.Ambient)
Ambient.Start()
local RS = game:GetService("RunService")
local function step(n, dt) for i = 1, n do RS.RenderStepped:Fire(dt) end end
-- stato iniziale
local fan = game:GetService("CollectionService"):GetTagged("Fan")[1]
local body0 = fan.Corpo.CFrame
local boards = game:GetService("CollectionService"):GetTagged("Scoreboard")
local spin = game:GetService("CollectionService"):GetTagged("Spin")
local before = {}
for i, m in ipairs(spin) do before[i] = m:GetPivot() end
workspace:SetAttribute("Phase", "Playing")
workspace:SetAttribute("PhaseEnd", workspace:GetServerTimeNow() + 300)
workspace:SetAttribute("ScoreRed", 2)
workspace:SetAttribute("ScoreBlue", 1)
step(60, 0.016)
local gui = boards[1].Gui
local info = {}
info[#info + 1] = "tifosi: " .. #game:GetService("CollectionService"):GetTagged("Fan")
info[#info + 1] = "fan moved: " .. tostring(fan.Corpo.CFrame.Y ~= body0.Y)
info[#info + 1] = "red=" .. gui.PunteggioRossi.Text .. " blue=" .. gui.PunteggioBlu.Text .. " time=" .. gui.Tempo.Text .. " fase=" .. gui.Fase.Text
local moved = 0
for i, m in ipairs(spin) do if m:GetPivot() ~= before[i] then moved = moved + 1 end end
info[#info + 1] = "spinners moved: " .. moved .. "/" .. #spin
local bird = game:GetService("CollectionService"):GetTagged("Bird")[1]
local b0 = bird.Corpo.CFrame
step(30, 0.016)
info[#info + 1] = "bird moved: " .. tostring(bird.Corpo.CFrame ~= b0) .. " (" .. #game:GetService("CollectionService"):GetTagged("Bird") .. " uccelli)"
info[#info + 1] = "burst spots: " .. #game:GetService("CollectionService"):GetTagged("GoalBurst")
workspace:SetAttribute("Phase", "Goal")
step(40, 0.016)
info[#info + 1] = "goal ok, fase=" .. gui.Fase.Text
return table.concat(info, "\n")
''')
print(res)
rep = lua.execute('return table.concat(__SHIM.problems, "\\n")')
print('PROBLEMI:', rep or '(nessuno)')
