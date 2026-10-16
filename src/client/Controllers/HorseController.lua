--[[
	HorseController - il cavallo
	  - H: chiama il cavallo / scendi
	  - anima le zampe di tutti i cavalli visibili (passo e galoppo in base alla velocità),
	    il collo che annuisce, la coda che ondeggia e il rumore degli zoccoli
	  - si scende da soli usando i rampini, attaccando o entrando in acqua
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)

local HorseController = {}
local C
local player = Players.LocalPlayer

type HorseRig = { Model: Model, Phase: number, LastStep: number, Motors: { [string]: Motor6D } }

local rigs: { [Model]: HorseRig } = {}
local lastAutoDismount = 0

-- sfasamento delle zampe nel ciclo: galoppo (a coppie) e passo (a quattro tempi)
local GALLOP = { AS = 0.0, AD = 0.12, PS = 0.55, PD = 0.67 }
local WALK = { AS = 0.0, PD = 0.25, AD = 0.5, PS = 0.75 }

function HorseController.IsRiding(): boolean
	return player:GetAttribute("Riding") == true
end

-- Scende dal cavallo (usato da rampini e attacchi)
function HorseController.Dismount()
	if HorseController.IsRiding() then
		Net.Event("Horse"):FireServer(false)
	end
end

local function register(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	rigs[model] = { Model = model, Phase = math.random(), LastStep = 0, Motors = motors }
	model.DescendantAdded:Connect(function(d)
		if d:IsA("Motor6D") then
			local rig = rigs[model]
			if rig then
				rig.Motors[d.Name] = d
			end
		end
	end)
end

local function animate(rig: HorseRig, dt: number, t: number, localRoot: BasePart?)
	local model = rig.Model
	local character = model.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z).Magnitude
	local gallop = math.clamp((flat - 18) / 14, 0, 1)
	local moving = math.clamp(flat / 8, 0, 1)
	local stride = 6 + gallop * 6
	rig.Phase = (rig.Phase + dt * flat / stride) % 1
	local phase = rig.Phase
	local amp = math.rad(18 + 22 * gallop) * moving
	local m = rig.Motors
	for leg, offset in GALLOP do
		local walkOffset = WALK[leg]
		local o = offset * gallop + walkOffset * (1 - gallop)
		local a = (phase + o) * math.pi * 2
		local hip = m["Anca" .. leg]
		local knee = m["Ginocchio" .. leg]
		if hip then
			hip.Transform = CFrame.Angles(math.sin(a) * amp, 0, 0)
		end
		if knee then
			knee.Transform = CFrame.Angles(-math.max(0, -math.cos(a)) * amp * 1.5, 0, 0)
		end
	end
	local cycle = phase * math.pi * 2
	local breathe = math.sin(t * 2.2) * 0.03 * (1 - moving)
	if m.SellaMotore then
		local bob = math.abs(math.sin(cycle)) * 0.28 * gallop + math.abs(math.sin(cycle * 2)) * 0.08 * moving * (1 - gallop)
		m.SellaMotore.Transform = CFrame.new(0, bob + breathe, 0) * CFrame.Angles(math.sin(cycle) * math.rad(3) * gallop, 0, 0)
	end
	if m.ColloMotore then
		local nod = math.sin(cycle) * math.rad(9) * moving
		local graze = if moving < 0.1 then math.max(0, math.sin(t * 0.35)) * math.rad(12) else 0
		m.ColloMotore.Transform = CFrame.Angles(nod - graze, 0, 0)
	end
	if m.CodaMotore then
		m.CodaMotore.Transform = CFrame.Angles(math.rad(-20) * gallop + math.sin(t * 3) * 0.08, 0, math.sin(t * 2.3) * 0.25 * (1 - gallop * 0.6))
	end
	-- zoccoli: un colpo a ogni appoggio (solo per i cavalli vicini)
	if moving > 0.5 and localRoot and (localRoot.Position - root.Position).Magnitude < 140 then
		local interval = if gallop > 0.5 then 0.18 else 0.3
		if t - rig.LastStep > interval and C.SoundController then
			rig.LastStep = t
			C.SoundController.Play("Step", root.Position - Vector3.new(0, 5, 0), { Range = 140, Volume = 0.5, Pitch = 1.3 + math.random() * 0.2 })
		end
	end
end

function HorseController.Init(c)
	C = c
end

function HorseController.Start()
	for _, model in CollectionService:GetTagged(Config.Tags.Horse) do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal(Config.Tags.Horse):Connect(register)
	CollectionService:GetInstanceRemovedSignal(Config.Tags.Horse):Connect(function(model)
		rigs[model :: Model] = nil
	end)
	C.InputController.On("Horse", function(began)
		if not began then
			return
		end
		if HorseController.IsRiding() then
			Net.Event("Horse"):FireServer(false)
		else
			if player:GetAttribute("Transformed") then
				return
			end
			Net.Event("Horse"):FireServer(true)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local localRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for model, rig in rigs do
			if model.Parent then
				animate(rig, dt, t, localRoot)
			else
				rigs[model] = nil
			end
		end
		-- in acqua il cavallo non ci va: scendi
		if HorseController.IsRiding() then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Swimming and t - lastAutoDismount > 1 then
				lastAutoDismount = t
				HorseController.Dismount()
			end
		end
	end)
end

return HorseController
