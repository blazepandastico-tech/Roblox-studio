-- Gestione dei RemoteEvent di gioco: calci, scivolata, scatto, sprint, chiedi palla.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Stamina = require(script.Parent.Stamina)
local Ragdoll = require(script.Parent.Ragdoll)
local Ball = require(script.Parent.Ball)

local Actions = {}

local cooldowns = {} -- [plr] = { tackle = t, dash = t, call = t }

local function cd(plr)
	local c = cooldowns[plr]
	if not c then
		c = { tackle = 0, dash = 0, call = 0 }
		cooldowns[plr] = c
	end
	return c
end

local function parts(plr)
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

local function validDir(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z and flat(v).Magnitude > 0.05
end

local function stat(plr, name, delta)
	local stats = plr:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild(name)
	if v then
		v.Value = v.Value + delta
	end
end

function Actions.Init(isPlaying)
	Net.Get("Kick").OnServerEvent:Connect(function(plr, kind, charge, aim, curve)
		if not isPlaying() or typeof(kind) ~= "string" then
			return
		end
		Ball.Kick(plr, kind, charge, aim, curve)
	end)

	Net.Get("Control").OnServerEvent:Connect(function(plr, on)
		Ball.SetTight(plr, on == true)
	end)

	Net.Get("Sprint").OnServerEvent:Connect(function(plr, on)
		Stamina.SetSprinting(plr, on == true)
	end)

	Net.Get("Tackle").OnServerEvent:Connect(function(plr, dir)
		if not isPlaying() then
			return
		end
		local char, hum, hrp = parts(plr)
		if not char or Ragdoll.IsRagdolled(char) or char:GetAttribute("Sliding") then
			return
		end
		local c = cd(plr)
		local now = os.clock()
		if now < c.tackle or Stamina.Get(plr) < 0.05 then
			return
		end
		c.tackle = now + Config.Tackle.Cooldown
		Stamina.Spend(plr, Config.Stamina.Tackle)
		local d = validDir(dir) and flat(dir).Unit or flat(hrp.CFrame.LookVector).Unit

		char:SetAttribute("Sliding", true)
		hum.AutoRotate = false
		task.spawn(function()
			local T = Config.Tackle
			local t0 = os.clock()
			local hit = {}
			local ballHit = false
			while true do
				local el = os.clock() - t0
				if el >= T.Duration or not char.Parent or hum.Health <= 0 or Ragdoll.IsRagdolled(char) then
					break
				end
				local speed = T.Speed * (1 - 0.7 * el / T.Duration)
				hrp.AssemblyLinearVelocity = Vector3.new(d.X * speed, hrp.AssemblyLinearVelocity.Y, d.Z * speed)
				hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + d)

				for _, other in ipairs(Players:GetPlayers()) do
					if other ~= plr and not hit[other] then
						local oc, _, ohrp = parts(other)
						if oc and not Ragdoll.IsRagdolled(oc) and not oc:GetAttribute("Evading") and not oc:GetAttribute("Shielded") then
							local to = flat(ohrp.Position - hrp.Position)
							if to.Magnitude < T.Reach and (to.Magnitude < 1.5 or to.Unit:Dot(d) > -0.2) then
								hit[other] = true
								Ragdoll.Apply(oc, Config.Ragdoll.Duration, d * T.VictimImpulse + Vector3.new(0, 20, 0))
								Net.Get("Notify"):FireClient(plr, "Contrasto!")
								Net.Get("Notify"):FireClient(other, "Sei stato contrastato!")
								stat(plr, "Contrasti", 1)
							end
						end
					end
				end
				if not ballHit then
					local ball = Ball.Part
					local rel = ball.Position - hrp.Position
					if flat(rel).Magnitude < T.Reach and rel.Y < 5 and not ball.Anchored then
						ballHit = true
						Ball.SetToucher(plr)
						Ball.Knock(d * T.BallKnock + Vector3.new(0, T.BallKnockUp, 0))
					end
				end
				RunService.Heartbeat:Wait()
			end
			if char.Parent then
				char:SetAttribute("Sliding", nil)
				hum.AutoRotate = true
			end
		end)
	end)

	Net.Get("Dash").OnServerEvent:Connect(function(plr, dir)
		if not isPlaying() then
			return
		end
		local char, hum, hrp = parts(plr)
		if not char or Ragdoll.IsRagdolled(char) or char:GetAttribute("Sliding") or char:GetAttribute("Dashing") then
			return
		end
		local c = cd(plr)
		local now = os.clock()
		if now < c.dash or Stamina.Get(plr) < 0.05 then
			return
		end
		c.dash = now + Config.Dash.Cooldown
		Stamina.Spend(plr, Config.Stamina.Dash)
		local d = validDir(dir) and flat(dir).Unit or flat(hrp.CFrame.RightVector).Unit

		char:SetAttribute("Dashing", true)
		char:SetAttribute("Evading", true)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < Config.Dash.Duration and char.Parent and hum.Health > 0 and not Ragdoll.IsRagdolled(char) do
				hrp.AssemblyLinearVelocity = Vector3.new(d.X * Config.Dash.Speed, hrp.AssemblyLinearVelocity.Y, d.Z * Config.Dash.Speed)
				RunService.Heartbeat:Wait()
			end
			if char.Parent then
				char:SetAttribute("Dashing", nil)
			end
		end)
		task.delay(Config.Dash.EvadeTime, function()
			if char.Parent then
				char:SetAttribute("Evading", nil)
			end
		end)
	end)

	Net.Get("CallBall").OnServerEvent:Connect(function(plr)
		if not isPlaying() then
			return
		end
		local char = plr.Character
		local head = char and char:FindFirstChild("Head")
		if not head then
			return
		end
		local c = cd(plr)
		local now = os.clock()
		if now < c.call then
			return
		end
		c.call = now + 1.5
		local old = head:FindFirstChild("CallSign")
		if old then
			old:Destroy()
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "CallSign"
		gui.Size = UDim2.fromOffset(120, 40)
		gui.StudsOffset = Vector3.new(0, 4.2, 0)
		gui.AlwaysOnTop = true
		gui.Parent = head
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundColor3 = Color3.fromRGB(255, 214, 64)
		lbl.TextColor3 = Color3.fromRGB(40, 30, 10)
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextScaled = true
		lbl.Text = "PASSA!"
		lbl.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = lbl
		task.delay(Config.Kick.CallBallDuration, function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end)
end

Players.PlayerRemoving:Connect(function(plr)
	cooldowns[plr] = nil
end)

return Actions
