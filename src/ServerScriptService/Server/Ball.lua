-- Palla: fisica autorevole sul server, conduzione, calci, effetto, goal.
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Stamina = require(script.Parent.Stamina)
local Ragdoll = require(script.Parent.Ragdoll)

local K = Config.Kick
local B = Config.Ball
local F = Config.Field
local RADIUS = B.Diameter / 2

local Ball = {}
Ball.Part = nil
Ball.Active = false

local state = {
	spin = 0,
	possessor = nil,
	lastToucher = nil,
	prevToucher = nil, -- candidato assist
	prevTime = 0,
	powerShot = nil,
}
local lockUntil = {} -- [plr] = os.clock() entro cui non puo' ri-controllare la palla
local lastKick = {}
local tight = {} -- [plr] = true se tiene Spazio

local function charParts(plr)
	local char = plr.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then
		return nil
	end
	return char, hum, hrp
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function validVector(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude > 0.05 and v.Magnitude < 1e4
end

local function teamKeyOf(plr)
	if plr.Team then
		for key, t in pairs(Config.Teams) do
			if t.Name == plr.Team.Name then
				return key
			end
		end
	end
	return nil
end
Ball.TeamKeyOf = teamKeyOf

local function setToucher(plr)
	if state.lastToucher == plr then
		return
	end
	local old = state.lastToucher
	if old and plr and teamKeyOf(old) == teamKeyOf(plr) then
		state.prevToucher = old
		state.prevTime = os.clock()
	else
		state.prevToucher = nil
	end
	state.lastToucher = plr
end

function Ball.ClearPossession()
	state.possessor = nil
	Ball.Part:SetAttribute("Possessor", nil)
end

function Ball.SetToucher(plr)
	setToucher(plr)
end

function Ball.Create()
	local part = Instance.new("Part")
	part.Name = "Ball"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(B.Diameter, B.Diameter, B.Diameter)
	part.Color = Color3.fromRGB(250, 250, 250)
	part.Material = Enum.Material.SmoothPlastic
	part.CustomPhysicalProperties = PhysicalProperties.new(0.55, 0.5, 0.7, 1, 1)
	part.Anchored = true
	part.Position = Vector3.new(0, RADIUS + 0.3, 0)

	-- pezze nere (icosaedro: 12 direzioni)
	local phi = (1 + math.sqrt(5)) / 2
	local dirs = {}
	for _, a in ipairs({ -1, 1 }) do
		for _, b in ipairs({ -phi, phi }) do
			table.insert(dirs, Vector3.new(0, a, b))
			table.insert(dirs, Vector3.new(a, b, 0))
			table.insert(dirs, Vector3.new(b, 0, a))
		end
	end
	for _, d in ipairs(dirs) do
		local patch = Instance.new("Part")
		patch.Name = "Patch"
		patch.Shape = Enum.PartType.Ball
		patch.Size = Vector3.new(1.05, 1.05, 1.05)
		patch.Color = Color3.fromRGB(25, 25, 30)
		patch.Material = Enum.Material.SmoothPlastic
		patch.CanCollide = false
		patch.CanQuery = false
		patch.CanTouch = false
		patch.Massless = true
		patch.Anchored = false
		patch.CFrame = part.CFrame + d.Unit * (RADIUS - 0.02)
		local w = Instance.new("WeldConstraint")
		w.Part0 = part
		w.Part1 = patch
		w.Parent = patch
		patch.Parent = part
	end

	-- scia
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, RADIUS * 0.8, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -RADIUS * 0.8, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.LightEmission = 0.6
	trail.Enabled = false
	trail.Parent = part

	part.Parent = workspace
	Ball.Part = part

	part.Touched:Connect(function(other)
		if not Ball.Active then
			return
		end
		local char = other.Parent
		local plr = char and Players:GetPlayerFromCharacter(char)
		if not plr then
			return
		end
		setToucher(plr)
		-- tiro a carica piena che colpisce un avversario/compagno: lo butta a terra
		local ps = state.powerShot
		local vel = part.AssemblyLinearVelocity
		if ps and ps.by ~= plr and os.clock() - ps.t < 2.5 and vel.Magnitude > K.PowerHitSpeed then
			if not Ragdoll.IsRagdolled(char) and not char:GetAttribute("Shielded") then
				state.powerShot = nil
				Ragdoll.Apply(char, Config.Ragdoll.Duration, vel.Unit * K.PowerHitImpulse + Vector3.new(0, 18, 0))
				part.AssemblyLinearVelocity = vel * 0.35 + Vector3.new(0, 14, 0)
				Net.Get("Notify"):FireClient(ps.by, "Colpo diretto!")
				Net.Get("Notify"):FireClient(plr, "Sei stato colpito!")
				local stats = ps.by:FindFirstChild("leaderstats")
				if stats and stats:FindFirstChild("Colpi") then
					stats.Colpi.Value = stats.Colpi.Value + 1
				end
			end
		end
	end)
	return part
end

function Ball.Reset(position)
	local p = Ball.Part
	p.Anchored = true
	p.AssemblyLinearVelocity = Vector3.zero
	p.AssemblyAngularVelocity = Vector3.zero
	p.CFrame = CFrame.new(position or Vector3.new(0, RADIUS + 0.3, 0))
	state.spin = 0
	state.powerShot = nil
	state.lastToucher = nil
	state.prevToucher = nil
	Ball.ClearPossession()
end

function Ball.Release()
	local p = Ball.Part
	p.Anchored = false
	p:SetNetworkOwner(nil)
end

function Ball.SetActive(on)
	Ball.Active = on
end

function Ball.SetTight(plr, on)
	tight[plr] = on and true or nil
end

function Ball.GetScorers()
	return state.lastToucher, state.prevToucher, state.prevTime
end

-- ritorna "Red" / "Blue" = la squadra che ha segnato, oppure nil
function Ball.CheckGoal()
	local p = Ball.Part.Position
	local gw = F.GoalWidth / 2
	if math.abs(p.Z) < gw - 0.5 and p.Y < F.GoalHeight - 0.5 then
		if p.X > F.Length / 2 + RADIUS then
			return "Red" -- palla nella porta dei Blu (+X)
		elseif p.X < -F.Length / 2 - RADIUS then
			return "Blue"
		end
	end
	return nil
end

function Ball.OutOfBounds()
	local p = Ball.Part.Position
	return p.Y < -30 or math.abs(p.X) > F.Length / 2 + 40 or math.abs(p.Z) > F.Width / 2 + 40 or p.Y > 80
end

----------------------------------------------------------------------
-- Calci
----------------------------------------------------------------------
local function applyKick(plr, hrp, velocity, spin, charged)
	local part = Ball.Part
	part.Anchored = false
	part.AssemblyLinearVelocity = velocity + flat(hrp.AssemblyLinearVelocity) * 0.25
	part.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-6, 6), math.random(-6, 6))
	state.spin = spin
	state.powerShot = charged and { by = plr, t = os.clock() } or nil
	Ball.ClearPossession()
	lockUntil[plr] = os.clock() + B.TouchLockAfterKick
	setToucher(plr)
	part:SetNetworkOwner(nil)
end

local function aimBasis(hrp, aim)
	local h = flat(aim)
	if h.Magnitude < 0.05 then
		h = flat(hrp.CFrame.LookVector)
	end
	h = h.Unit
	local pitch = math.asin(math.clamp(aim.Unit.Y, -1, 1))
	pitch = math.clamp(pitch, K.MinPitch, K.MaxPitch)
	return h, pitch
end

local function findPassTarget(plr, hrp, h)
	local best, bestDot
	local myTeam = plr.Team
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= plr and other.Team ~= nil and other.Team == myTeam then
			local oc, _, ohrp = charParts(other)
			if oc and not Ragdoll.IsRagdolled(oc) then
				local to = flat(ohrp.Position - hrp.Position)
				if to.Magnitude > 3 then
					local dot = to.Unit:Dot(h)
					if dot > K.PassMinDot and (not bestDot or dot > bestDot) then
						best, bestDot = ohrp, dot
					end
				end
			end
		end
	end
	return best
end

function Ball.Kick(plr, kind, charge, aim, curve)
	if not Ball.Active or Ball.Part.Anchored then
		return false
	end
	if not validVector(aim) then
		return false
	end
	local char, hum, hrp = charParts(plr)
	if not char or Ragdoll.IsRagdolled(char) then
		return false
	end
	local now = os.clock()
	if lastKick[plr] and now - lastKick[plr] < K.Cooldown then
		return false
	end
	local part = Ball.Part
	if (part.Position - hrp.Position).Magnitude > K.Reach then
		return false
	end
	charge = math.clamp(tonumber(charge) or 0, 0, 1)
	curve = math.clamp(tonumber(curve) or 0, -1, 1)
	aim = aim.Unit

	local cost
	if kind == "normal" then
		cost = (charge < 0.15) and Config.Stamina.KickTap or (Config.Stamina.KickChargedMin + (Config.Stamina.KickChargedMax - Config.Stamina.KickChargedMin) * charge)
	elseif kind == "pass" then
		cost = Config.Stamina.Pass
	elseif kind == "flick" then
		cost = Config.Stamina.Flick
	elseif kind == "lob" then
		cost = Config.Stamina.Lob
	else
		return false
	end
	local strong = Stamina.Spend(plr, cost)
	local weak = Config.Stamina.WeakKickMultiplier
	lastKick[plr] = now

	local h, pitch = aimBasis(hrp, aim)

	if kind == "normal" then
		local power = K.MinPower + (K.MaxPower - K.MinPower) * charge
		local p = pitch + K.ArcBase
		if not strong then
			power = power * weak
			p = 0
			charge = 0
		end
		local dir = h * math.cos(p) + Vector3.new(0, math.sin(p), 0)
		local spin = (charge > 0.1 and strong) and curve or 0
		applyKick(plr, hrp, dir * power, spin, charge >= K.PowerShotThreshold and strong)
	elseif kind == "pass" then
		local target = findPassTarget(plr, hrp, h)
		local dir, speed
		if target then
			local lead = target.Position + flat(target.AssemblyLinearVelocity) * 0.35
			local to = flat(lead - part.Position)
			local dist = to.Magnitude
			speed = math.clamp(dist * K.PassPerStud + K.PassBase, K.PassMin, K.PassMax)
			dir = (to.Unit * math.cos(0.05) + Vector3.new(0, math.sin(0.05), 0))
		else
			speed = 55
			dir = h * math.cos(0.05) + Vector3.new(0, math.sin(0.05), 0)
		end
		if not strong then
			speed = speed * weak
		end
		applyKick(plr, hrp, dir * speed, 0, false)
	elseif kind == "flick" then
		local m = strong and 1 or weak
		applyKick(plr, hrp, (h * K.FlickForward + Vector3.new(0, K.FlickUp, 0)) * m, 0, false)
	elseif kind == "lob" then
		local m = strong and 1 or weak
		applyKick(plr, hrp, (h * K.LobForward + Vector3.new(0, K.LobUp, 0)) * m, 0, false)
	end
	return true
end

----------------------------------------------------------------------
-- Step: attrito, effetto Magnus, conduzione
----------------------------------------------------------------------
function Ball.Step(dt)
	local part = Ball.Part
	if not Ball.Active or part.Anchored then
		return
	end
	local vel = part.AssemblyLinearVelocity
	local hv = flat(vel)
	local grounded = part.Position.Y <= RADIUS + 0.4

	-- effetto: forza laterale sulla velocita' orizzontale
	if math.abs(state.spin) > 0.01 and hv.Magnitude > 8 then
		local side = hv:Cross(Vector3.yAxis) -- a destra del moto
		vel = vel + side * (state.spin * B.Magnus * dt)
		state.spin = state.spin * math.max(0, 1 - B.SpinDecay * dt)
		if grounded then
			state.spin = state.spin * 0.9
		end
	end

	-- attrito
	local drag = grounded and B.GroundDrag or B.AirDrag
	local k = math.max(0, 1 - drag * dt)
	vel = Vector3.new(vel.X * k, vel.Y, vel.Z * k)

	-- conduzione
	local now = os.clock()
	local possessor = state.possessor
	if possessor then
		local char, _, hrp = charParts(possessor)
		if not char or Ragdoll.IsRagdolled(char) or flat(part.Position - hrp.Position).Magnitude > B.ReleaseRadius then
			Ball.ClearPossession()
			possessor = nil
		end
	end
	if not possessor then
		local bestD = B.ControlRadius
		for _, plr in ipairs(Players:GetPlayers()) do
			local char, _, hrp = charParts(plr)
			if char and plr.Team and not Ragdoll.IsRagdolled(char) and (lockUntil[plr] or 0) < now then
				local rel = part.Position - hrp.Position
				if flat(rel).Magnitude < bestD and rel.Y < 4 and rel.Y > -3.5 then
					bestD = flat(rel).Magnitude
					possessor = plr
				end
			end
		end
		if possessor then
			state.possessor = possessor
			part:SetAttribute("Possessor", possessor.UserId)
			setToucher(possessor)
		end
	end
	if possessor then
		local _, _, hrp = charParts(possessor)
		local pv = flat(hrp.AssemblyLinearVelocity)
		if pv.Magnitude > B.MinControlSpeed then
			local fwd = flat(hrp.CFrame.LookVector)
			if fwd.Magnitude > 0.05 then
				local dist = tight[possessor] and B.CarryDistanceTight or B.CarryDistance
				local target = hrp.Position + fwd.Unit * dist
				local err = flat(target - part.Position)
				local desired = pv + err * B.FollowRate
				if desired.Magnitude > B.MaxCarrySpeed then
					desired = desired.Unit * B.MaxCarrySpeed
				end
				local blend = 1 - math.exp(-14 * dt)
				local nh = hv:Lerp(desired, blend)
				vel = Vector3.new(nh.X, vel.Y, nh.Z)
			end
		end
	end

	part.AssemblyLinearVelocity = vel

	-- rotolamento senza slittamento a terra
	if grounded then
		local h2 = flat(vel)
		part.AssemblyAngularVelocity = h2:Cross(Vector3.yAxis) / RADIUS
	end

	-- il colpo potente smette di essere "potente" quando rallenta
	if state.powerShot and (vel.Magnitude < K.PowerHitSpeed * 0.8 or now - state.powerShot.t > 2.5) then
		state.powerShot = nil
	end
end

function Ball.Knock(velocity)
	local part = Ball.Part
	part.Anchored = false
	part.AssemblyLinearVelocity = velocity
	state.powerShot = nil
	state.spin = 0
	Ball.ClearPossession()
	part:SetNetworkOwner(nil)
end

function Ball.ForgetPlayer(plr)
	lockUntil[plr] = nil
	lastKick[plr] = nil
	tight[plr] = nil
	if state.possessor == plr then
		Ball.ClearPossession()
	end
	if state.lastToucher == plr then
		state.lastToucher = nil
	end
	if state.prevToucher == plr then
		state.prevToucher = nil
	end
end

Players.PlayerRemoving:Connect(function(plr)
	if Ball.Part then
		Ball.ForgetPlayer(plr)
	end
end)

return Ball
