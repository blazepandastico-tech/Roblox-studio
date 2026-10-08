-- Stamina a 4 tacche: unico serbatoio per sprint, calci, scivolate, scatti e (poi) gadget.
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local S = Config.Stamina

local Stamina = {}

local data = {}

function Stamina.Init(plr)
	data[plr] = { value = S.Pips, last = 0, wants = false, exhausted = false, sent = -1 }
	plr:SetAttribute("Stamina", S.Pips)
end

function Stamina.Remove(plr)
	data[plr] = nil
end

function Stamina.Get(plr)
	local d = data[plr]
	return d and d.value or 0
end

-- Consuma stamina. Ritorna true se ce n'era abbastanza (altrimenti il colpo e' debole).
function Stamina.Spend(plr, amount)
	local d = data[plr]
	if not d then
		return true
	end
	local had = d.value >= amount - 0.001
	d.value = math.max(0, d.value - amount)
	d.last = os.clock()
	return had
end

function Stamina.Refill(plr)
	local d = data[plr]
	if d then
		d.value = S.Pips
		d.exhausted = false
	end
end

function Stamina.SetSprinting(plr, on)
	local d = data[plr]
	if d then
		d.wants = on and true or false
	end
end

function Stamina.IsSprinting(plr)
	local d = data[plr]
	return d ~= nil and d.wants and not d.exhausted
end

function Stamina.Step(dt)
	local now = os.clock()
	for plr, d in pairs(data) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			local moving = hum.MoveDirection.Magnitude > 0.1
			local sprinting = d.wants and not d.exhausted and moving
			if sprinting then
				d.value = math.max(0, d.value - S.SprintDrainPerSec * dt)
				d.last = now
				if d.value <= 0 then
					d.exhausted = true
				end
			elseif now - d.last >= S.RegenDelay then
				d.value = math.min(S.Pips, d.value + S.RegenPerSec * dt)
			end
			if d.exhausted and d.value >= S.ExhaustedRecover then
				d.exhausted = false
			end

			-- velocita': non toccarla durante scivolate/ragdoll/scatti
			if not (char:GetAttribute("Sliding") or char:GetAttribute("Ragdolled") or char:GetAttribute("Dashing")) then
				local mult = char:GetAttribute("SpeedMult") or 1
				local speed = sprinting and Config.Move.SprintSpeed or Config.Move.WalkSpeed
				hum.WalkSpeed = speed * mult
			end
			hum.JumpPower = Config.Move.JumpPower
			hum.UseJumpPower = true

			if math.abs(d.value - d.sent) > 0.02 then
				d.sent = d.value
				plr:SetAttribute("Stamina", d.value)
			end
		end
	end
end

Players.PlayerRemoving:Connect(Stamina.Remove)

return Stamina
