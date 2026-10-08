-- Vita della mappa lato client: tifosi che saltellano (e impazziscono al goal), tabelloni segnapunti,
-- pale e parabole che girano, luci di segnalazione che lampeggiano.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local Ambient = {}

local fans = {}
local fanParts = {}
local fanFrames = {}
local spinners = {}
local blinkers = {}
local boards = {}
local birds = {}
local birdParts = {}
local birdFrames = {}
local bursts = {}

local FAN_RANGE = 420 -- oltre questa distanza dal centro del campo i tifosi restano fermi (risparmio)

local function addFan(model)
	if model.ClassName ~= "Model" then
		return
	end
	local body = model:FindFirstChild("Corpo")
	local head = model:FindFirstChild("Testa")
	if not body or not head then
		return
	end
	local n = #fanParts
	fanParts[n + 1] = body
	fanParts[n + 2] = head
	fanFrames[n + 1] = body.CFrame
	fanFrames[n + 2] = head.CFrame
	fans[#fans + 1] = {
		base1 = body.CFrame,
		base2 = head.CFrame,
		phase = model:GetAttribute("Fase") or 0,
		jump = model:GetAttribute("Salto") or 1,
	}
end

local function addSpinner(model)
	spinners[#spinners + 1] = {
		model = model,
		base = model:GetPivot(),
		speed = model:GetAttribute("SpinSpeed") or 0.1,
		axisX = model:GetAttribute("SpinAxis") == "X",
		angle = 0,
	}
end

local function addBlinker(part)
	blinkers[#blinkers + 1] = { part = part, offset = #blinkers * 0.37 }
end

local function addBoard(part)
	local gui = part:FindFirstChild("Gui")
	if not gui then
		return
	end
	boards[#boards + 1] = {
		red = gui:FindFirstChild("PunteggioRossi"),
		blue = gui:FindFirstChild("PunteggioBlu"),
		time = gui:FindFirstChild("Tempo"),
		phase = gui:FindFirstChild("Fase"),
	}
end

local function addBird(model)
	local body = model:FindFirstChild("Corpo")
	local wl, wr, head = model:FindFirstChild("AlaSx"), model:FindFirstChild("AlaDx"), model:FindFirstChild("Testa")
	if not (body and wl and wr and head) then
		return
	end
	local n = #birdParts
	birdParts[n + 1] = body
	birdParts[n + 2] = wl
	birdParts[n + 3] = wr
	birdParts[n + 4] = head
	for i = 1, 4 do
		birdFrames[n + i] = birdParts[n + i].CFrame
	end
	birds[#birds + 1] = {
		cx = model:GetAttribute("Cx") or 0,
		cz = model:GetAttribute("Cz") or 0,
		r = model:GetAttribute("Raggio") or 100,
		h = model:GetAttribute("Quota") or 100,
		speed = model:GetAttribute("Velocita") or 0.15,
		phase = model:GetAttribute("Fase") or 0,
	}
end

local function addBurst(part)
	bursts[#bursts + 1] = part
end

-- coriandoli: tutti i cannoncini sparano insieme, poi una seconda raffica
local function fireBursts()
	for _, part in ipairs(bursts) do
		for _, e in ipairs(part:GetChildren()) do
			if e:IsA("ParticleEmitter") then
				e:Emit(26)
			end
		end
	end
end

local function fmtTime(sec)
	local s = math.max(0, math.ceil(sec))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local PHASE_TEXT = {
	Intermission = "INTERVALLO",
	Kickoff = "CALCIO D'INIZIO",
	Playing = "IN GIOCO",
	Goal = "GOAL!",
	Ended = "FINITA",
}

local function updateBoards()
	local phase = workspace:GetAttribute("Phase") or "Intermission"
	local now = workspace:GetServerTimeNow()
	local endAt = workspace:GetAttribute("PhaseEnd") or 0
	local clock = workspace:GetAttribute("TimeLeft") or Config.Match.Duration
	if phase == "Playing" then
		clock = endAt - now
	elseif phase == "Intermission" then
		clock = endAt - now
	end
	local red = tostring(workspace:GetAttribute("ScoreRed") or 0)
	local blue = tostring(workspace:GetAttribute("ScoreBlue") or 0)
	for _, b in ipairs(boards) do
		if b.red then
			b.red.Text = red
		end
		if b.blue then
			b.blue.Text = blue
		end
		if b.time then
			b.time.Text = fmtTime(clock)
		end
		if b.phase then
			b.phase.Text = PHASE_TEXT[phase] or ""
		end
	end
end

local function register(tagName, adder)
	for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
		adder(inst)
	end
	CollectionService:GetInstanceAddedSignal(tagName):Connect(adder)
end

function Ambient.Start()
	register("Fan", addFan)
	register("Spin", addSpinner)
	register("Blink", addBlinker)
	register("Scoreboard", addBoard)
	register("Bird", addBird)
	register("GoalBurst", addBurst)

	local lastPhase = workspace:GetAttribute("Phase")
	workspace:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = workspace:GetAttribute("Phase")
		if phase == "Goal" and lastPhase ~= "Goal" then
			fireBursts()
			task.delay(1.1, fireBursts)
		end
		lastPhase = phase
	end)

	local t = 0
	local acc = 0
	local boardAcc = 0
	RunService.RenderStepped:Connect(function(dt)
		t = t + dt
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position

		-- ruote e parabole
		for _, s in ipairs(spinners) do
			s.angle = s.angle + s.speed * dt
			if s.axisX then
				s.model:PivotTo(s.base * CFrame.Angles(s.angle, 0, 0))
			else
				s.model:PivotTo(CFrame.new(s.base.Position) * CFrame.Angles(0, s.angle, 0) * s.base.Rotation)
			end
		end

		-- luci rosse che lampeggiano
		for _, b in ipairs(blinkers) do
			b.part.Transparency = (math.floor((t + b.offset) * 1.3) % 2 == 0) and 0 or 0.8
		end

		-- tifosi: 20 aggiornamenti al secondo, solo se la camera e' vicina allo stadio
		acc = acc + dt
		if acc >= 0.05 and camPos and camPos.Magnitude < FAN_RANGE and #fans > 0 then
			acc = 0
			local phase = workspace:GetAttribute("Phase")
			local amp, freq = 0.18, 2.2
			if phase == "Goal" then
				amp, freq = 1.9, 6.5
			elseif phase == "Playing" then
				amp, freq = 0.3, 3
			elseif phase == "Intermission" then
				amp, freq = 0.1, 1.4
			end
			for i, f in ipairs(fans) do
				local bob = math.abs(math.sin(t * freq * f.jump + f.phase)) * amp
				local up = Vector3.new(0, bob, 0)
				fanFrames[2 * i - 1] = f.base1 + up
				fanFrames[2 * i] = f.base2 + up * 1.15
			end
			workspace:BulkMoveTo(fanParts, fanFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- avvoltoi: volteggiano in cerchio sbattendo le ali
		if #birds > 0 then
			for i, b in ipairs(birds) do
				local a = b.phase + t * b.speed
				local pos = Vector3.new(b.cx + b.r * math.cos(a), b.h + 3 * math.sin(t * 0.6 + b.phase), b.cz + b.r * math.sin(a))
				local dir = (b.speed >= 0) and 1 or -1
				local ahead = Vector3.new(-math.sin(a) * dir, 0, math.cos(a) * dir)
				local body = CFrame.lookAt(pos, pos + ahead) * CFrame.Angles(0, 0, -0.28 * dir)
				local flap = math.sin(t * 2.6 + b.phase * 3) * 0.45
				local o = 4 * (i - 1)
				birdFrames[o + 1] = body
				birdFrames[o + 2] = body * CFrame.new(-0.7, 0.1, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(-2.2, 0, 0)
				birdFrames[o + 3] = body * CFrame.new(0.7, 0.1, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(2.2, 0, 0)
				birdFrames[o + 4] = body * CFrame.new(0, 0.1, -2.1)
			end
			workspace:BulkMoveTo(birdParts, birdFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- tabelloni: 5 volte al secondo
		boardAcc = boardAcc + dt
		if boardAcc >= 0.2 then
			boardAcc = 0
			updateBoards()
		end
	end)
end

return Ambient
