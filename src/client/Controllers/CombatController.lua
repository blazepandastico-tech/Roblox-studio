--[[
	CombatController
	Fendenti (combo da 4), abilità delle lame Z/X/C/V, armi a distanza, ricarica,
	Risveglio Valkar, trasformazione e attacchi in forma di gigante,
	essere afferrati da un gigante (premi Spazio per liberarti!) e contraccolpi.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Items = require(Shared.Data.Items)
local Skills = require(Shared.Data.Skills)
local Serums = require(Shared.Data.Serums)

local CombatController = {}
local C
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local combo = 0
local lastSwing = 0
local lastRanged = 0
local cooldowns: { [string]: number } = {}
local titanForm = false
local grabbedBy: Model? = nil
local dashUntil = 0
local dashVelocity = Vector3.zero
local stunnedUntil = 0
local controls: any = nil
local activeSkill: string? = nil

CombatController.Cooldowns = cooldowns

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local ZONE_PRIORITY = { Nape = 5, Eye = 4, RightArm = 3, LeftArm = 3, RightLeg = 3, LeftLeg = 3, Body = 1 }

local function root(): BasePart?
	return Util.GetRoot(player.Character)
end

local function alive(): boolean
	return Util.IsAlive(player.Character)
end

local function targetFolders(): { Instance }
	local list = {}
	for _, name in { Config.Folders.Titans, Config.Folders.Enemies } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	-- PvP: anche gli altri giocatori con il PvP attivo (se lo è anche il tuo)
	if player:GetAttribute("PvPActive") == true then
		for _, other in Players:GetPlayers() do
			if other ~= player and other:GetAttribute("PvPActive") == true and other.Character then
				table.insert(list, other.Character)
			end
		end
	end
	return list
end

-- Il personaggio di un altro giocatore a cui appartiene questa parte (per il PvP)
local function pvpOwner(part: BasePart): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local owner = Players:GetPlayerFromCharacter(model)
		if owner then
			if owner ~= player and owner:GetAttribute("PvPActive") == true then
				return model
			end
			return nil
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Trova le parti colpite (una per bersaglio, preferendo la nuca)
local function collectHits(parts: { BasePart }, max: number?): ({ BasePart }, { Vector3 }, boolean)
	local best: { [Instance]: BasePart } = {}
	for _, part in parts do
		local owner = Util.FindAncestorWithAttribute(part, "TitanUid") or Util.FindAncestorWithAttribute(part, "EnemyUid")
		local rival = if owner then nil else pvpOwner(part)
		if rival then
			-- un altro giocatore: si colpisce il busto (una parte sola per bersaglio)
			if not best[rival] or part.Name == "UpperTorso" then
				best[rival] = part
			end
		elseif owner and owner:GetAttribute("State") ~= "Dead" and owner:GetAttribute("Dead") ~= true and owner:GetAttribute("Ally") ~= true then
			local zone = part:GetAttribute("HitZone")
			if zone or owner:GetAttribute("EnemyUid") then
				local current = best[owner]
				local pri = ZONE_PRIORITY[zone or "Body"] or 1
				if not current or pri > (ZONE_PRIORITY[current:GetAttribute("HitZone") or "Body"] or 1) then
					best[owner] = part
				end
			end
		end
	end
	local hits, positions = {}, {}
	local nape = false
	for _, part in best do
		table.insert(hits, part)
		table.insert(positions, part.Position)
		if part:GetAttribute("HitZone") == "Nape" then
			nape = true
		end
		if max and #hits >= max then
			break
		end
	end
	return hits, positions, nape
end

local function queryBox(cframe: CFrame, size: Vector3): { BasePart }
	overlap.FilterDescendantsInstances = targetFolders()
	return workspace:GetPartBoundsInBox(cframe, size, overlap)
end

local function queryRadius(position: Vector3, radius: number): { BasePart }
	overlap.FilterDescendantsInstances = targetFolders()
	return workspace:GetPartBoundsInRadius(position, radius, overlap)
end

local function hitFeedback(positions: { Vector3 }, nape: boolean)
	if #positions == 0 then
		return
	end
	local character = player.Character
	if C.AnimationController then
		C.AnimationController.Freeze(character, if nape then 0.09 else 0.05)
	end
	if C.CameraController then
		C.CameraController.Shake(if nape then 0.28 else 0.14, 0.18)
	end
	for _, pos in positions do
		if C.EffectsController then
			C.EffectsController.Sparks(pos, if nape then Color3.fromRGB(255, 220, 140) else Color3.fromRGB(255, 255, 255), if nape then 24 else 12, 45)
			C.EffectsController.Steam(pos, 2.5, 4, 0.8, Color3.fromRGB(240, 200, 190))
		end
	end
	if C.SoundController then
		C.SoundController.Play(if nape then "SlashHeavy" else "Slash", positions[1], { Range = 200 })
	end
end

-- Piccolo aiuto alla mira: se una nuca è vicina, ti spinge verso di lei
local function napeAssist(r: BasePart)
	local best, bestDist = nil, 22
	for _, part in queryRadius(r.Position, 22) do
		if part.Name == "Nape" then
			local d = (part.Position - r.Position).Magnitude
			if d < bestDist then
				best, bestDist = part, d
			end
		end
	end
	if best then
		local dir = (best.Position - r.Position).Unit
		r.AssemblyLinearVelocity += dir * 28
	end
end

-- FENDENTI ---------------------------------------------------------------------------------

local function isFlying(): boolean
	return C.ODMController ~= nil and C.ODMController.IsFlying()
end

local function swing()
	local r = root()
	local character = player.Character
	if not r or not character or not alive() then
		return
	end
	if titanForm then
		local mouseHit = CombatController.AimPoint(400)
		Net.Event("TitanSkill"):FireServer("M1", mouseHit)
		return
	end
	if grabbedBy then
		Net.Event("EscapeMash"):FireServer()
		return
	end
	local now = os.clock()
	if now - lastSwing < Config.Combat.ComboStepTime then
		return
	end
	if now - lastSwing > Config.Combat.ComboResetTime then
		combo = 0
	end
	combo = combo % 4 + 1
	lastSwing = now
	C.AnimationController.Play(character, "Slash" .. combo, 1.1)
	if C.SoundController then
		C.SoundController.Play("Slash", r.Position, { Range = 120, Volume = 0.4 })
	end
	napeAssist(r)
	local thisCombo = combo
	task.delay(0.09, function()
		local rr = root()
		if not rr then
			return
		end
		local speed = rr.AssemblyLinearVelocity.Magnitude
		local reach = Config.Combat.BladeReach + math.min(speed * 0.06, 10)
		local look = rr.CFrame.LookVector
		if isFlying() then
			look = Util.SafeUnit(rr.AssemblyLinearVelocity, look)
		end
		local cf = CFrame.lookAt(rr.Position + look * (reach * 0.5), rr.Position + look * reach)
		local parts = queryBox(cf, Vector3.new(13, 13, reach + 4))
		for _, extra in queryRadius(rr.Position, 9) do
			table.insert(parts, extra)
		end
		local hits, positions, nape = collectHits(parts, Config.Combat.MaxHitsPerSwing)
		if #hits > 0 then
			Net.Event("Attack"):FireServer({ Combo = thisCombo, Hits = hits, Speed = speed })
			hitFeedback(positions, nape)
		end
	end)
end

-- ABILITÀ DELLE LAME ------------------------------------------------------------------------

local function skillReady(key: string): boolean
	return os.clock() >= (cooldowns[key] or 0)
end

local function runSkillHits(key: string, duration: number, interval: number, finder: () -> { BasePart })
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < duration and alive() do
			local hits, positions, nape = collectHits(finder(), 6)
			if #hits > 0 then
				Net.Event("SkillHit"):FireServer(key, hits)
				hitFeedback(positions, nape)
			end
			task.wait(interval)
		end
		if activeSkill == key then
			activeSkill = nil
		end
	end)
end

local function nearestNape(position: Vector3, range: number): BasePart?
	local best, bestDist = nil, range
	local folder = workspace:FindFirstChild(Config.Folders.Titans)
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("State") ~= "Dead" and not model:GetAttribute("Ally") then
			local nape = model:FindFirstChild("Nape")
			if nape and nape:IsA("BasePart") then
				local d = (nape.Position - position).Magnitude
				if d < bestDist then
					best, bestDist = nape, d
				end
			end
		end
	end
	return best
end

local function bladeSkill(key: string)
	local skill = Skills.Blade[key]
	local r = root()
	local character = player.Character
	if not skill or not r or not character or not alive() or grabbedBy then
		return
	end
	local stats = C.ClientData.Stats
	if stats and (stats.BladeMastery or 0) < skill.Mastery then
		C.Notifications.Toast(("%s: serve maestria %d (ora %d)"):format(skill.Name, skill.Mastery, math.floor(stats.BladeMastery or 0)), "Errore", 2.5)
		return
	end
	if not skillReady(key) then
		return
	end
	cooldowns[key] = os.clock() + skill.Cooldown
	activeSkill = key
	Net.Event("Skill"):FireServer(key)
	C.AnimationController.Play(character, skill.Anim, 1)
	if C.SoundController then
		C.SoundController.Play("SlashHeavy", r.Position, { Range = 200 })
	end
	if key == "Z" then
		runSkillHits(key, skill.Duration, 0.14, function()
			local rr = root()
			return if rr then queryRadius(rr.Position, skill.Radius) else {}
		end)
		if C.EffectsController then
			C.EffectsController.Shockwave(r.Position, skill.Radius, Color3.fromRGB(230, 240, 255), 0.35, 0.4)
		end
	elseif key == "X" then
		local dir = Util.SafeUnit(camera.CFrame.LookVector)
		local speed = skill.Distance / skill.Duration
		dashVelocity = dir * speed
		dashUntil = os.clock() + skill.Duration
		if C.CameraController then
			C.CameraController.Punch(14)
		end
		runSkillHits(key, skill.Duration + 0.1, 0.08, function()
			local rr = root()
			if not rr then
				return {}
			end
			return queryBox(CFrame.lookAt(rr.Position + dir * 6, rr.Position + dir * 12), Vector3.new(skill.Radius, skill.Radius, 16))
		end)
	elseif key == "C" then
		runSkillHits(key, skill.Duration, skill.Duration / skill.Ticks, function()
			local rr = root()
			if rr and C.ODMController.IsFlying() then
				rr.AssemblyLinearVelocity += camera.CFrame.LookVector * 6
			end
			return if rr then queryRadius(rr.Position, skill.Radius) else {}
		end)
	elseif key == "V" then
		local nape = nearestNape(r.Position, skill.Range)
		if not nape then
			C.Notifications.Toast("Nessuna nuca abbastanza vicina!", "Errore", 2)
			cooldowns[key] = os.clock() + 2
			return
		end
		if C.CameraController then
			C.CameraController.Punch(18)
			C.CameraController.Shake(0.3, 0.4)
		end
		local start = os.clock()
		local conn
		conn = RunService.PreSimulation:Connect(function()
			local rr = root()
			if not rr or not nape.Parent or os.clock() - start > skill.Duration then
				conn:Disconnect()
				return
			end
			local offset = nape.Position + Vector3.new(0, 2, 0) - rr.Position
			if offset.Magnitude > 6 then
				rr.AssemblyLinearVelocity = offset.Unit * math.min(220, offset.Magnitude * 9)
			else
				rr.AssemblyLinearVelocity = Vector3.zero
			end
		end)
		local hitsDone = 0
		task.spawn(function()
			task.wait(0.25)
			while hitsDone < skill.Hits and nape.Parent and alive() do
				hitsDone += 1
				local rr = root()
				if rr and (nape.Position - rr.Position).Magnitude < 30 then
					Net.Event("SkillHit"):FireServer(key, { nape })
					hitFeedback({ nape.Position }, true)
				end
				task.wait(0.2)
			end
		end)
	end
end

-- ARMI A DISTANZA ---------------------------------------------------------------------------

function CombatController.AimPoint(range: number): Vector3
	local aim = C.CameraController.AimScreenPoint()
	local ray = camera:ViewportPointToRay(aim.X, aim.Y)
	local list = { player.Character }
	local fx = workspace:FindFirstChild("EffettiLocali")
	if fx then
		table.insert(list, fx)
	end
	rayParams.FilterDescendantsInstances = list
	local result = workspace:Raycast(ray.Origin, ray.Direction * range, rayParams)
	return if result then result.Position else ray.Origin + ray.Direction * range
end

local function fireRanged()
	if titanForm or grabbedBy or not alive() then
		return
	end
	local profile = C.ClientData.Profile
	local def = profile and Items.Get(profile.Equipped.Ranged)
	local r = root()
	if not def or not r then
		C.Notifications.Toast("Nessuna arma a distanza equipaggiata (menu M).", "Info", 2)
		return
	end
	local now = os.clock()
	if now - lastRanged < def.Cooldown then
		return
	end
	if (player:GetAttribute("RangedAmmo") or 0) <= 0 then
		C.Notifications.Toast("Munizioni finite! Riforniscile a un Deposito.", "Errore", 2)
		return
	end
	lastRanged = now
	local aim = C.CameraController.AimScreenPoint()
	local ray = camera:ViewportPointToRay(aim.X, aim.Y)
	local list = { player.Character }
	local fx = workspace:FindFirstChild("EffettiLocali")
	if fx then
		table.insert(list, fx)
	end
	rayParams.FilterDescendantsInstances = list
	local camDist = (ray.Origin - r.Position).Magnitude
	local result = workspace:Raycast(ray.Origin, ray.Direction * (def.Range + camDist), rayParams)
	local hitPos = if result then result.Position else ray.Origin + ray.Direction * (def.Range + camDist)
	if (hitPos - r.Position).Magnitude > def.Range then
		hitPos = r.Position + (hitPos - r.Position).Unit * def.Range
	end
	Net.Event("Ranged"):FireServer({ HitPos = hitPos, HitPart = result and result.Instance or nil })
	local origin = r.Position + Vector3.new(0, 1.5, 0)
	local character = player.Character
	if def.Kind == "Lancia" or def.Kind == "Cannone" then
		C.AnimationController.Play(character, "FireSpear", 1)
		C.EffectsController.Projectile(origin, hitPos, math.clamp((hitPos - origin).Magnitude / 400, 0.12, 0.6), "Spear", 1)
		C.CameraController.Shake(0.2, 0.2)
	elseif def.Kind == "Segnalatore" then
		C.AnimationController.Play(character, "Flare", 1)
		C.EffectsController.Projectile(origin, hitPos, 0.5, "Spear", 1)
	else
		C.AnimationController.Play(character, "FireGun", 1)
		C.EffectsController.Tracer(origin, hitPos, def.ProjectileColor)
		C.CameraController.Shake(0.12, 0.15)
	end
	if C.SoundController then
		C.SoundController.Play("Shot", origin, { Range = 300 })
	end
end

-- ESSERE AFFERRATI ----------------------------------------------------------------------------

local function onGrab(state: boolean, model: Model?, info: any)
	local hum = Util.GetHumanoid(player.Character)
	if state then
		grabbedBy = model
		if hum then
			hum.PlatformStand = true
		end
		if C.HUD then
			C.HUD.ShowMash(true, if type(info) == "number" then info else 12)
		end
		C.CameraController.Shake(0.6, 0.5)
	else
		grabbedBy = nil
		if hum then
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		if C.HUD then
			C.HUD.ShowMash(false)
		end
		if info == "Eaten" then
			C.CameraController.Shake(1, 0.8)
			C.EffectsController.Flash(Color3.fromRGB(255, 40, 40), 0.3, 0.6)
		end
	end
end

local function pinToHand()
	if not grabbedBy then
		return
	end
	local r = root()
	local hand = grabbedBy:FindFirstChild("RightHand") :: BasePart?
	if not r or not hand or not grabbedBy.Parent then
		onGrab(false, nil, nil)
		return
	end
	local height = grabbedBy:GetAttribute("Height") or 20
	r.CFrame = hand.CFrame * CFrame.new(0, -height * 0.03, -height * 0.04)
	r.AssemblyLinearVelocity = Vector3.zero
end

-- FORMA DI GIGANTE ---------------------------------------------------------------------------

local function onTitanForm(data)
	if type(data) ~= "table" then
		return
	end
	if data.On == true then
		titanForm = true
		task.delay(2, function()
			local character = player.Character
			local form = character and character:FindFirstChild("FormaGigante")
			if not form or not form:GetAttribute("MeshSkin") then
				return
			end
			local pieces, loaded = 0, 0
			for _, d in form:GetChildren() do
				if d:IsA("MeshPart") then
					pieces += 1
					local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if not root or (d.Position - root.Position).Magnitude < (data.Height or 30) * 2 then
						loaded += 1
					end
				end
			end
			print(("[Giganti 3D] Sul tuo schermo: %d pezzi del modello, %d al posto giusto"):format(pieces, loaded))
			if loaded < 12 then
				warn("[Giganti 3D] Il modello non si vede: ti rendo di nuovo visibile. Mandami queste righe dell'Output.")
				local hidden = form:FindFirstChild("PartiNascoste")
				for _, tag in if hidden then hidden:GetChildren() else {} do
					local part = tag:IsA("ObjectValue") and tag.Value
					if part and part:IsA("BasePart") then
						part.Transparency = 0
					end
				end
			end
		end)
		C.CameraController.SetTitanForm(data.Height or 30)
		C.ODMController.ReleaseAll(true)
		if C.HUD then
			C.HUD.SetTitanMode(true, data.Serum)
		end
	elseif data.On == false then
		titanForm = false
		C.CameraController.SetTitanForm(0)
		if C.HUD then
			C.HUD.SetTitanMode(false)
		end
	end
	if data.Dash then
		dashVelocity = data.Dash
		dashUntil = os.clock() + (data.Duration or 0.6)
	end
	if data.Freeze then
		local r = root()
		if r then
			r.Anchored = true
			task.delay(data.Freeze, function()
				r.Anchored = false
			end)
		end
	end
end

local function titanSkill(key: string)
	if not titanForm then
		return
	end
	local profile = C.ClientData.Profile
	local serum = profile and Serums.Get(profile.Serum)
	local skill = serum and serum.Skills[key]
	if not skill then
		return
	end
	local mastery = profile.SerumMastery and profile.SerumMastery[serum.Id] or 0
	if mastery < (skill.Mastery or 0) then
		C.Notifications.Toast(("%s: serve maestria %d (ora %d)"):format(skill.Name, skill.Mastery, mastery), "Errore", 2.5)
		return
	end
	local id = "T" .. key
	if os.clock() < (cooldowns[id] or 0) then
		return
	end
	cooldowns[id] = os.clock() + skill.Cooldown
	Net.Event("TitanSkill"):FireServer(key, CombatController.AimPoint(800))
end

function CombatController.IsTitanForm(): boolean
	return titanForm
end

function CombatController.IsGrabbed(): boolean
	return grabbedBy ~= nil
end

function CombatController.ActiveSkill(): string?
	return activeSkill
end

function CombatController.Init(c)
	C = c
end

function CombatController.Start()
	task.spawn(function()
		local ok, module = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
		end)
		if ok and module then
			controls = module:GetControls()
		end
	end)

	local input = C.InputController
	local function leaveHorse()
		if player:GetAttribute("Riding") and C.HorseController then
			C.HorseController.Dismount()
		end
	end
	input.On("Attack", function(began)
		if began then
			leaveHorse()
			swing()
		end
	end)
	input.On("Ranged", function(began)
		if began then
			fireRanged()
		end
	end)
	input.On("Boost", function(began)
		if began and grabbedBy then
			Net.Event("EscapeMash"):FireServer()
			if C.HUD then
				C.HUD.MashPulse()
			end
		end
	end)
	for _, key in Skills.Order do
		input.On("Skill" .. key, function(began)
			if not began then
				return
			end
			if titanForm then
				titanSkill(key)
			else
				leaveHorse()
				bladeSkill(key)
			end
		end)
	end
	input.On("Reload", function(began)
		if not began or titanForm then
			return
		end
		local dur = player:GetAttribute("BladeDur") or 0
		local max = player:GetAttribute("BladeDurMax") or 0
		local spares = player:GetAttribute("BladeSpares") or 0
		if dur < max and spares > 0 then
			Net.Event("ReloadBlades"):FireServer()
			C.AnimationController.Play(player.Character, "Reload", 1)
			if C.SoundController then
				C.SoundController.Play("Unsheath")
			end
		elseif spares <= 0 then
			C.Notifications.Toast("Nessuna lama di ricambio.", "Errore", 2)
		end
	end)
	input.On("Transform", function(began)
		if began and not grabbedBy then
			Net.Event("Transform"):FireServer()
		end
	end)
	input.On("Awaken", function(began)
		if began then
			Net.Event("Awaken"):FireServer()
		end
	end)

	Net.Event("Grab").OnClientEvent:Connect(onGrab)
	Net.Event("TitanForm").OnClientEvent:Connect(onTitanForm)
	Net.Event("Knockback").OnClientEvent:Connect(function(velocity: Vector3, stun: number)
		local r = root()
		if not r or grabbedBy then
			return
		end
		if velocity.Magnitude > 1 then
			r.AssemblyLinearVelocity = velocity
		end
		C.CameraController.Shake(math.clamp(velocity.Magnitude / 200, 0.15, 0.7), 0.35)
		C.AnimationController.Play(player.Character, "HitReact", 1, true)
		if stun and stun > 0 then
			stunnedUntil = os.clock() + stun
			if controls then
				controls:Disable()
			end
			task.delay(stun, function()
				if os.clock() >= stunnedUntil - 0.01 and controls then
					controls:Enable()
				end
			end)
		end
	end)
	Net.Event("HitConfirm").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if data.Kind == "NapeKill" then
			if C.DamageNumbers then
				C.DamageNumbers.Banner(if data.Perfect then "TAGLIO PERFETTO!" else "NUCA!", if data.Perfect then Color3.fromRGB(255, 215, 110) else Color3.fromRGB(255, 120, 100))
			end
			C.CameraController.Punch(10)
			if C.SoundController then
				C.SoundController.Play("SlashHeavy", nil, { Pitch = 0.8 })
			end
		elseif data.Kind == "Sever" then
			if C.DamageNumbers then
				C.DamageNumbers.Banner("ARTO RECISO", Color3.fromRGB(255, 180, 160), 0.8)
			end
		elseif data.Kind == "Kill" then
			if C.DamageNumbers then
				C.DamageNumbers.KillPopup(data.Name, data.XP or 0, data.Gold or 0, data.Boss)
			end
		end
	end)

	player.CharacterAdded:Connect(function()
		titanForm = false
		grabbedBy = nil
		combo = 0
		C.CameraController.SetTitanForm(0)
		if C.HUD then
			C.HUD.SetTitanMode(false)
			C.HUD.ShowMash(false)
		end
	end)

	RunService.PreSimulation:Connect(function()
		if grabbedBy then
			pinToHand()
		end
		if os.clock() < dashUntil then
			local r = root()
			if r then
				r.AssemblyLinearVelocity = Vector3.new(dashVelocity.X, math.max(dashVelocity.Y, r.AssemblyLinearVelocity.Y), dashVelocity.Z)
			end
		end
	end)
end

return CombatController
