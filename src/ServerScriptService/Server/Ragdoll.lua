-- Ragdoll fisico temporaneo per personaggi R15 (Motor6D e AnimationConstraint).
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local Ragdoll = {}

local COLLIDE_PARTS = {
	UpperTorso = true,
	LowerTorso = true,
	Head = true,
	LeftUpperLeg = true,
	RightUpperLeg = true,
	LeftLowerLeg = true,
	RightLowerLeg = true,
}

function Ragdoll.IsRagdolled(char)
	return char:GetAttribute("Ragdolled") == true
end

function Ragdoll.Apply(char, duration, impulse)
	if not char or not char.Parent then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then
		return
	end
	if char:GetAttribute("Ragdolled") then
		return
	end
	duration = duration or Config.Ragdoll.Duration
	char:SetAttribute("Ragdolled", true)
	char:SetAttribute("Sliding", nil)

	local disabled = {}
	local created = {}
	local collideRestore = {}

	for _, d in ipairs(char:GetDescendants()) do
		local a0, a1
		if d:IsA("Motor6D") and d.Name ~= "Root" and d.Name ~= "RootJoint" then
			a0 = d.Part0 and d.Part0:FindFirstChild(d.Name .. "RigAttachment")
			a1 = d.Part1 and d.Part1:FindFirstChild(d.Name .. "RigAttachment")
		elseif d:IsA("AnimationConstraint") and d.Name ~= "Root" and d.Name ~= "RootJoint" then
			a0, a1 = d.Attachment0, d.Attachment1
		end
		if a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment") then
			d.Enabled = false
			table.insert(disabled, d)
			local bs = Instance.new("BallSocketConstraint")
			bs.Name = "RagdollSocket"
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.UpperAngle = 65
			bs.TwistLimitsEnabled = true
			bs.TwistLowerAngle = -45
			bs.TwistUpperAngle = 45
			bs.Parent = a0.Parent
			table.insert(created, bs)
			local nc = Instance.new("NoCollisionConstraint")
			nc.Name = "RagdollNoCollide"
			nc.Part0 = a0.Parent
			nc.Part1 = a1.Parent
			nc.Parent = a0.Parent
			table.insert(created, nc)
		end
	end
	for name in pairs(COLLIDE_PARTS) do
		local part = char:FindFirstChild(name)
		if part then
			collideRestore[part] = part.CanCollide
			part.CanCollide = true
		end
	end

	hum.PlatformStand = true
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	if impulse then
		hrp.AssemblyLinearVelocity = impulse
		hrp.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-4, 4), math.random(-8, 8))
	end

	task.delay(duration, function()
		if not char.Parent then
			return
		end
		for _, c in ipairs(created) do
			if c.Parent then
				c:Destroy()
			end
		end
		for _, j in ipairs(disabled) do
			if j.Parent then
				j.Enabled = true
			end
		end
		for part, was in pairs(collideRestore) do
			if part.Parent then
				part.CanCollide = was
			end
		end
		if hum.Health > 0 and hrp.Parent then
			local look = hrp.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude < 0.01 then
				flat = Vector3.new(0, 0, -1)
			end
			local pos = hrp.Position + Vector3.new(0, 3, 0)
			char:PivotTo(CFrame.lookAt(pos, pos + flat.Unit))
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		char:SetAttribute("Ragdolled", nil)
	end)
end

return Ragdoll
