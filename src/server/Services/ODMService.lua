--[[
	ODMService - convalida dei Rampini a Gas lato server (anti-trucchi)

	Il volo è simulato dal client (proprietario fisico del personaggio): così è fluido anche con
	300 ms di ping. Il server non lo ricalcola, ma lo tiene d'occhio con le stesse formule
	di Shared.Modules.ODMPhysicsModule:

	  1. AGGANCI: ogni "Fire" viene controllato (portata del rampino + tolleranza di latenza,
	     parte valida, niente agganci ai giocatori, personaggio vivo e non trasformato,
	     gas sufficiente). Se non va bene il client riceve "Reject" e sgancia il cavo,
	     e gli altri giocatori non vedono nulla.
	  2. GAS: il server tiene un conteggio PRUDENTE (sottostima i consumi e sovrastima le
	     ricariche), quindi è sempre >= del gas legittimo del client. Lo pubblica
	     nell'attributo "GasCap" e il client non può superarlo: gas infinito impossibile,
	     nessun falso positivo per chi gioca onestamente.
	  3. SPOSTAMENTI: ogni 0,25 s confronta lo spostamento con il massimo credibile
	     (volo a slancio pieno, abilità, spinte). Dopo campioni consecutivi sospetti
	     riporta il personaggio all'ultima posizione valida (niente ban automatici).

	Inoltra inoltre agli altri giocatori vicini i cavi convalidati (per vederli volare).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Net = require(Shared.Lib.Net)
local ODMPhysics = require(Shared.Modules.ODMPhysicsModule)

local ODMService = {}
local S

local ODM = Config.ODM
local V = ODM.Validation
local TICK = 0.1
local GROUND_PROBE = 8 -- entro questa altezza consideriamo il giocatore "a terra" (per eccesso)
local DRAIN_FACTOR = 0.9 -- il server sottostima i consumi: mai più severo del client
local RELAY_RADIUS = 700

type HookInfo = { Since: number }
type State = {
	Gas: number,
	PublishedGas: number,
	Hooks: { [string]: HookInfo },
	Boost: boolean,
	Character: Model?,
	LastValid: CFrame?,
	LastValidTime: number,
	LastSample: number,
	Strikes: number,
	GraceUntil: number,
	BudgetCount: number,
	BudgetReset: number,
}

local states: { [Player]: State } = {}

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false

local function maxGas(player: Player): number
	local value = player:GetAttribute("MaxGas")
	return if type(value) == "number" and value > 0 then value else 100
end

local function gasEfficiency(player: Player): number
	local value = player:GetAttribute("GasEfficiency")
	return if type(value) == "number" and value > 0 then value else 1
end

local function speedMult(player: Player): number
	local until_ = player:GetAttribute("AwakenedUntil")
	local awakened = type(until_) == "number" and workspace:GetServerTimeNow() < until_
	return ODMPhysics.SpeedMult(player:GetAttribute("ODMReel"), awakened)
end

local function publish(player: Player, st: State, force: boolean?)
	local gas = st.Gas
	if force or math.abs(gas - st.PublishedGas) >= 1 or (gas <= 0 and st.PublishedGas > 0) then
		st.PublishedGas = gas
		player:SetAttribute("GasCap", math.floor(gas * 10 + 0.5) / 10)
	end
end

local function getState(player: Player): State
	local st = states[player]
	if not st then
		st = {
			Gas = maxGas(player),
			PublishedGas = -1,
			Hooks = {},
			Boost = false,
			Character = nil,
			LastValid = nil,
			LastValidTime = 0,
			LastSample = 0,
			Strikes = 0,
			GraceUntil = os.clock() + 3,
			BudgetCount = 0,
			BudgetReset = 0,
		}
		states[player] = st
	end
	return st
end

-- personaggio vivo, non trasformato e non afferrato da un gigante
local function canUseODM(player: Player): (boolean, BasePart?)
	local character = player.Character
	local root = Util.GetRoot(character)
	local humanoid = Util.GetHumanoid(character)
	if not root or not humanoid or humanoid.Health <= 0 then
		return false, nil
	end
	local pstate = S.PlayerService.GetState(player)
	if pstate.Transformed or pstate.GrabbedBy or pstate.Dead then
		return false, root
	end
	return true, root
end

local function withinBudget(st: State, limit: number): boolean
	local now = os.clock()
	if now >= st.BudgetReset then
		st.BudgetCount = 0
		st.BudgetReset = now + 1
	end
	st.BudgetCount += 1
	return st.BudgetCount <= limit
end

local function relay(sender: Player, root: BasePart, action: string, data)
	local remote = Net.Event("ODM")
	for _, other in Players:GetPlayers() do
		if other ~= sender then
			local otherRoot = Util.GetRoot(other.Character)
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= RELAY_RADIUS then
				remote:FireClient(other, sender, action, data)
			end
		end
	end
end

local function reject(player: Player, st: State, side: string, seq: any)
	st.Hooks[side] = nil
	Net.Event("ODMCorrect"):FireClient(player, "Reject", { Side = side, Seq = if type(seq) == "number" then seq else nil })
end

-- AGGANCI ---------------------------------------------------------------------------------

local function onFire(player: Player, st: State, data)
	local side = if data.Side == "Left" then "Left" else "Right"
	local ok, root = canUseODM(player)
	local part = data.Part
	local position = data.Position
	if not ok or not root then
		reject(player, st, side, data.Seq)
		return
	end
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") or not part:IsDescendantOf(workspace) or typeof(position) ~= "Vector3" then
		reject(player, st, side, data.Seq)
		return
	end
	-- niente agganci ai personaggi degli altri giocatori
	local model = part:FindFirstAncestorOfClass("Model")
	if model and Players:GetPlayerFromCharacter(model) then
		reject(player, st, side, data.Seq)
		return
	end
	-- il punto dichiarato deve stare sulla parte (con margine per le parti in movimento);
	-- il Terreno è un'unica "parte" grande quanto il mondo, quindi non si controlla
	if not part:IsA("Terrain") and (part.Position - position).Magnitude > part.Size.Magnitude * 0.5 + 25 then
		reject(player, st, side, data.Seq)
		return
	end
	local range = player:GetAttribute("ODMRange")
	if type(range) ~= "number" or range <= 0 then
		reject(player, st, side, data.Seq)
		return
	end
	if not ODMPhysics.ValidateAnchor(root.Position, position, range, root.AssemblyLinearVelocity.Magnitude) then
		reject(player, st, side, data.Seq)
		return
	end
	local cost = ODMPhysics.HookCost(gasEfficiency(player))
	if st.Gas + V.GasSlack < cost then
		reject(player, st, side, data.Seq)
		return
	end
	st.Gas = math.max(0, st.Gas - cost)
	st.Hooks[side] = { Since = os.clock() }
	publish(player, st)

	local clean = { Side = side, Part = part, Position = position }
	if typeof(data.Offset) == "Vector3" then
		clean.Offset = data.Offset
	end
	relay(player, root, "Fire", clean)
end

local function onRelease(player: Player, st: State, data)
	local side = if data.Side == "Left" then "Left" else "Right"
	if not st.Hooks[side] then
		return
	end
	st.Hooks[side] = nil
	local root = Util.GetRoot(player.Character)
	if root then
		relay(player, root, "Release", { Side = side })
	end
end

local function onODM(player: Player, action: any, data: any)
	if type(action) ~= "string" or type(data) ~= "table" then
		return
	end
	local st = getState(player)
	if not withinBudget(st, 30) then
		return
	end
	if action == "Fire" then
		if V.Enabled then
			onFire(player, st, data)
		else
			-- convalida spenta: si inoltra e basta
			local root = Util.GetRoot(player.Character)
			if root and typeof(data.Part) == "Instance" and typeof(data.Position) == "Vector3" then
				st.Hooks[if data.Side == "Left" then "Left" else "Right"] = { Since = os.clock() }
				relay(player, root, "Fire", { Side = data.Side, Part = data.Part, Offset = data.Offset, Position = data.Position })
			end
		end
	elseif action == "Release" then
		onRelease(player, st, data)
	elseif action == "Boost" then
		st.Boost = data.On == true
	end
end

-- SIMULAZIONE PRUDENTE DEL GAS E CONTROLLO DEGLI SPOSTAMENTI -------------------------------

local function nearGround(root: BasePart, character: Model): boolean
	groundParams.FilterDescendantsInstances = { character }
	return workspace:Raycast(root.Position, Vector3.new(0, -GROUND_PROBE, 0), groundParams) ~= nil
end

local function updateGas(player: Player, st: State, root: BasePart, character: Model, dt: number)
	local reeling = 0
	for _ in st.Hooks do
		reeling += 1
	end
	local grounded = nearGround(root, character)
	local boosting = st.Boost and not grounded
	local maxG = maxGas(player)
	if reeling > 0 or boosting then
		st.Gas -= ODMPhysics.GasDrain(reeling, boosting, gasEfficiency(player), dt) * DRAIN_FACTOR
	elseif grounded then
		st.Gas += ODM.GasRegenGround * dt
	end
	st.Gas = math.clamp(st.Gas, 0, maxG)
	publish(player, st)
end

local function checkMovement(player: Player, st: State, root: BasePart, humanoid: Humanoid, now: number)
	if now - st.LastSample < V.SampleInterval then
		return
	end
	st.LastSample = now
	local exempt = now < st.GraceUntil or root.Anchored or humanoid.SeatPart ~= nil
	if not st.LastValid or exempt then
		st.LastValid = root.CFrame
		st.LastValidTime = now
		st.Strikes = 0
		return
	end
	local delta = root.Position - (st.LastValid :: CFrame).Position
	-- le cadute sono innocue (e la gravità non ha velocità limite): conta solo il resto
	delta = Vector3.new(delta.X, math.max(delta.Y, 0), delta.Z)
	local allowed = ODMPhysics.MaxDisplacement(speedMult(player), now - st.LastValidTime)
	if delta.Magnitude <= allowed then
		st.LastValid = root.CFrame
		st.LastValidTime = now
		st.Strikes = 0
		return
	end
	st.Strikes += 1
	if st.Strikes >= V.StrikesToCorrect then
		warn(("[ODM] %s: spostamento non plausibile (%.0f studs, massimo %.0f): riportato indietro"):format(player.Name, delta.Magnitude, allowed))
		local back = st.LastValid :: CFrame
		pcall(function()
			(player.Character :: Model):PivotTo(back)
			root.AssemblyLinearVelocity = Vector3.zero
		end)
		st.Strikes = 0
		st.LastValidTime = now
		st.GraceUntil = now + 0.5
	end
end

local function tick(dt: number)
	local now = os.clock()
	for player, st in states do
		local character = player.Character
		if character ~= st.Character then
			-- nuovo personaggio: si riparte da zero
			st.Character = character
			st.Hooks = {}
			st.Boost = false
			st.Gas = maxGas(player)
			st.LastValid = nil
			st.GraceUntil = now + 3
			publish(player, st, true)
		end
		local ok, root = canUseODM(player)
		if not ok then
			st.Hooks = {}
			st.LastValid = nil
		elseif root and character then
			updateGas(player, st, root, character, dt)
			local humanoid = Util.GetHumanoid(character)
			if V.Enabled and humanoid then
				checkMovement(player, st, root, humanoid, now)
			end
		end
	end
end

-- API PER GLI ALTRI SERVIZI -----------------------------------------------------------------

-- Bombole piene (Depositi, raid, oggetti)
function ODMService.Refill(player: Player)
	local st = getState(player)
	st.Gas = maxGas(player)
	publish(player, st, true)
end

-- Consuma gas per un'azione convalidata altrove (es. schivata)
function ODMService.Spend(player: Player, amount: number)
	local st = getState(player)
	st.Gas = math.max(0, st.Gas - amount * DRAIN_FACTOR)
	publish(player, st)
end

function ODMService.DodgeCost(player: Player): number
	return ODMPhysics.DodgeCost(gasEfficiency(player))
end

-- Spostamenti decisi dal server (teletrasporti, traghetti, raid): non sono trucchi
function ODMService.Grace(player: Player, seconds: number)
	local st = getState(player)
	st.GraceUntil = math.max(st.GraceUntil, os.clock() + seconds)
	st.LastValid = nil
end

function ODMService.Gas(player: Player): number
	return getState(player).Gas
end

function ODMService.Init(services)
	S = services
end

function ODMService.Start()
	Net.Event("ODM").OnServerEvent:Connect(onODM)
	local function track(player: Player)
		getState(player)
		player:GetAttributeChangedSignal("MaxGas"):Connect(function()
			-- bombole migliori: si parte pieni (come sul client)
			ODMService.Refill(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local now = os.clock()
			local ok, err = pcall(tick, math.min(now - last, 0.5))
			last = now
			if not ok then
				warn("[ODM] " .. tostring(err))
			end
		end
	end)
end

return ODMService
