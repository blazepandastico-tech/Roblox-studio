-- Estensione dello shim: scheduler cooperativo (task.spawn/wait/delay/defer + Signal:Wait) con tempo simulato e giocatori finti.
-- Si carica DOPO robloxshim.lua. Serve per eseguire davvero Main.server.lua, il ciclo di partita e i gestori degli eventi.
local Sim = { now = 0, log = {} }
_G.Sim = Sim
local problems = __SHIM.problems
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- ---------------------------------------------------------------- tempo simulato
os.clock = function() return Sim.now end
tick = function() return Sim.now end
time = function() return Sim.now end

-- ---------------------------------------------------------------- scheduler
local queue, seq = {}, 0
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then problems[#problems + 1] = "ERRORE in un thread: " .. tostring(err) .. "\n" .. debug.traceback(co) end
	return ok
end
local function schedule(co, wake) seq = seq + 1; queue[#queue + 1] = { wake = wake, co = co, seq = seq } end
task = {
	spawn = function(f, ...)
		local co = f
		if type(f) == "function" then co = coroutine.create(f) end
		resume(co, ...)
		return co
	end,
	defer = function(f, ...)
		local a = table.pack(...)
		local co = type(f) == "thread" and f or coroutine.create(function() f(table.unpack(a, 1, a.n)) end)
		schedule(co, Sim.now)
		return co
	end,
	delay = function(t, f, ...)
		local a = table.pack(...)
		local co = type(f) == "thread" and f or coroutine.create(function() f(table.unpack(a, 1, a.n)) end)
		schedule(co, Sim.now + (t or 0))
		return co
	end,
	wait = function(t)
		local co, main = coroutine.running()
		t = t or 0.03
		if main then Sim.now = Sim.now + t; return t end
		schedule(co, Sim.now + t)
		coroutine.yield()
		return t
	end,
	cancel = function(co) for i = #queue, 1, -1 do if queue[i].co == co then table.remove(queue, i) end end end,
}
wait = task.wait
spawn = task.spawn
delay = function(t, f) return task.delay(t, f) end

-- ---------------------------------------------------------------- segnali: Wait vero, errori isolati nei gestori
local SignalMT = getmetatable(RunService.Heartbeat)
function SignalMT:Wait()
	local co, main = coroutine.running()
	if main then return nil end
	self._waiters = self._waiters or {}
	self._waiters[#self._waiters + 1] = co
	return coroutine.yield()
end
function SignalMT:Fire(...)
	local fns = {}
	for i, f in ipairs(self._fns) do fns[i] = f end
	for _, f in ipairs(fns) do
		local co = coroutine.create(f)
		resume(co, ...)
	end
	local w = self._waiters
	self._waiters = nil
	if w then for _, co in ipairs(w) do resume(co, ...) end end
end

function Sim.step(dt)
	Sim.now = Sim.now + dt
	table.sort(queue, function(a, b) if a.wake ~= b.wake then return a.wake < b.wake end return a.seq < b.seq end)
	local due, rest = {}, {}
	for _, e in ipairs(queue) do if e.wake <= Sim.now then due[#due + 1] = e else rest[#rest + 1] = e end end
	queue = rest
	for _, e in ipairs(due) do resume(e.co) end
	RunService.Heartbeat:Fire(dt)
	if Sim.client then RunService.RenderStepped:Fire(dt) end
end
function Sim.run(seconds, dt, hook)
	local n = math.floor(seconds / dt + 0.5)
	for i = 1, n do
		Sim.step(dt)
		if hook then hook(i) end
	end
end

-- ---------------------------------------------------------------- giocatori finti (istanze vere dello shim, cosi' le proprieta' vengono controllate)
local plist = {}
rawset(Players, "GetPlayers", function() local t = {} for i, p in ipairs(plist) do t[i] = p end return t end)
rawset(Players, "GetPlayerFromCharacter", function(_, char)
	for _, p in ipairs(plist) do if p.Character == char then return p end end
	return nil
end)
local function buildCharacter(plr)
	local m = Instance.new("Model"); m.Name = plr.Name
	local hum = Instance.new("Humanoid"); hum.Name = "Humanoid"; hum.RigType = Enum.HumanoidRigType.R15; hum.Parent = m
	rawget(hum, "_p").MoveDirection = Vector3.new(0, 0, 0)
	rawget(hum, "_p").Health = 100; rawget(hum, "_p").MaxHealth = 100
	local hrp = Instance.new("Part"); hrp.Name = "HumanoidRootPart"; hrp.Size = Vector3.new(2, 2, 1); hrp.Parent = m
	local head = Instance.new("Part"); head.Name = "Head"; head.Size = Vector3.new(2, 1, 1); head.Parent = m
	for _, n in ipairs({ "UpperTorso", "LowerTorso", "RightFoot", "LeftFoot" }) do local p = Instance.new("Part"); p.Name = n; p.Parent = m end
	m.PrimaryPart = hrp
	m.Parent = workspace
	return m
end
function Sim.addPlayer(name, userId)
	local plr = Instance.__internal("Player")
	plr.Name = name
	local P = rawget(plr, "_p")
	P.DisplayName = name; P.UserId = userId or (#plist + 1)
	P.LoadCharacter = function(self)
		if self.Character then self.Character:Destroy() end
		self.Character = buildCharacter(self)
		Sim.log[#Sim.log + 1] = "LoadCharacter " .. self.Name
	end
	plr.Parent = Players
	plist[#plist + 1] = plr
	Players.PlayerAdded:Fire(plr)
	return plr
end
function Sim.removePlayer(plr)
	for i, p in ipairs(plist) do if p == plr then table.remove(plist, i) break end end
	Players.PlayerRemoving:Fire(plr)
	plr.Parent = nil
end
