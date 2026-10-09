--[[
	ProceduralAnimator
	Anima un modello modificando Motor6D.Transform ogni frame, senza bisogno di
	animazioni caricate su Roblox.

	- "Layer": pose continue calcolate da una funzione (camminata, volo coi Rampini...)
	- "Clip":  animazioni a fotogrammi chiave (fendenti, schivate, attacchi dei giganti)

	La posa viene applicata modificando Motor6D.C0 (posa di riposo * posa calcolata):
	così è sempre visibile, qualunque cosa faccia il sistema di animazione di Roblox
	(che scrive solo Motor6D.Transform). La posa di riposo di ogni articolazione viene
	memorizzata la prima volta e ripristinata quando l'animatore viene distrutto.

	Va chiamato ogni frame (RunService.PreSimulation).
]]

local Util = require(script.Parent.Parent.Lib.Util)

local IDENTITY = CFrame.identity

local Animator = {}
Animator.__index = Animator

export type Pose = { [string]: CFrame }

function Animator.new(model: Model, absolute: boolean?)
	local self = setmetatable({}, Animator)
	self.Model = model
	self.Absolute = absolute == true
	self.Motors = {} :: { [string]: Motor6D }
	self.BaseC0 = {} :: { [Motor6D]: CFrame }
	self.Layers = {} -- array ordinato
	self.Clips = {} -- clip attive
	self.Time = 0
	self.PositionScale = 1
	-- scala del modello (Model:ScaleTo, es. la forma di gigante del giocatore): le pose di riposo
	-- delle giunture sono salvate a scala 1 e ingrandite qui, altrimenti il corpo si "accartoccia"
	self.BaseScale = 1
	self.Context = {}
	self.Result = {} :: Pose
	self.Paused = 0
	-- funzione opzionale (posa, dt) chiamata dopo layer e clip: può correggere la posa (vedi ArmReach)
	self.PostStep = nil :: ((Pose, number) -> ())?
	self:Refresh()
	return self
end

local function modelScale(model: Instance): number
	if model:IsA("Model") then
		local ok, scale = pcall(function()
			return model:GetScale()
		end)
		if ok and type(scale) == "number" and scale > 0 then
			return scale
		end
	end
	return 1
end

function Animator:Refresh()
	table.clear(self.Motors)
	for _, d in self.Model:GetDescendants() do
		if d:IsA("Motor6D") and self.Motors[d.Name] == nil then
			self.Motors[d.Name] = d
			if self.BaseC0[d] == nil then
				-- posa di riposo salvata come se il modello fosse a scala 1
				local scale = modelScale(self.Model)
				self.BaseC0[d] = CFrame.new(d.C0.Position / scale) * d.C0.Rotation
			end
		end
	end
	for motor in self.BaseC0 do
		if not motor.Parent then
			self.BaseC0[motor] = nil
		end
	end
end

function Animator:HasJoint(name: string): boolean
	return self.Motors[name] ~= nil
end

-- LAYER ------------------------------------------------------------------------------

function Animator:SetLayer(name: string, fn: (number, any, number) -> Pose, weight: number?, order: number?, fadeSpeed: number?)
	for _, layer in self.Layers do
		if layer.Name == name then
			layer.Fn = fn
			layer.Target = weight or 1
			layer.FadeSpeed = fadeSpeed or layer.FadeSpeed
			return
		end
	end
	table.insert(self.Layers, {
		Name = name,
		Fn = fn,
		Weight = 0,
		Target = weight or 1,
		Order = order or 0,
		FadeSpeed = fadeSpeed or 6,
	})
	table.sort(self.Layers, function(a, b)
		return a.Order < b.Order
	end)
end

function Animator:SetLayerWeight(name: string, weight: number, fadeSpeed: number?)
	for _, layer in self.Layers do
		if layer.Name == name then
			layer.Target = weight
			if fadeSpeed then
				layer.FadeSpeed = fadeSpeed
			end
			return
		end
	end
end

function Animator:GetLayerWeight(name: string): number
	for _, layer in self.Layers do
		if layer.Name == name then
			return layer.Weight
		end
	end
	return 0
end

-- CLIP --------------------------------------------------------------------------------

function Animator:Play(clip, options: { Speed: number?, Weight: number?, Time: number?, Loop: boolean? }?)
	if not clip then
		return nil
	end
	local opts = options or {}
	self:Stop(clip.Name, 0)
	local active = {
		Clip = clip,
		Name = clip.Name,
		Time = opts.Time or 0,
		Speed = opts.Speed or 1,
		Weight = opts.Weight or 1,
		Loop = if opts.Loop ~= nil then opts.Loop else clip.Loop,
		Stopping = false,
		StopFade = clip.FadeOut or 0.15,
		StopTime = 0,
		Priority = clip.Priority or 1,
	}
	table.insert(self.Clips, active)
	table.sort(self.Clips, function(a, b)
		return a.Priority < b.Priority
	end)
	return active
end

function Animator:Stop(name: string, fade: number?)
	for _, active in self.Clips do
		if active.Name == name and not active.Stopping then
			if fade == 0 then
				active.Remove = true
			else
				active.Stopping = true
				active.StopFade = fade or active.StopFade
				active.StopTime = 0
			end
		end
	end
end

function Animator:StopAll(fade: number?)
	for _, active in self.Clips do
		self:Stop(active.Name, fade)
	end
end

function Animator:IsPlaying(name: string): boolean
	for _, active in self.Clips do
		if active.Name == name and not active.Stopping and not active.Remove then
			return true
		end
	end
	return false
end

-- "Hit-stop": congela per un istante le clip (sensazione d'impatto)
function Animator:Freeze(duration: number)
	self.Paused = math.max(self.Paused, duration)
end

local function sampleClip(clip, t: number): Pose
	local keys = clip.Keys
	local count = #keys
	if count == 0 then
		return {}
	end
	if t <= keys[1].T then
		return keys[1].Pose
	end
	if t >= keys[count].T then
		return keys[count].Pose
	end
	for i = 1, count - 1 do
		local a, b = keys[i], keys[i + 1]
		if t >= a.T and t <= b.T then
			local span = b.T - a.T
			local alpha = if span > 0 then (t - a.T) / span else 1
			alpha = Util.Ease(alpha, b.Ease or "QuadInOut")
			local pose = {}
			for joint, cfA in a.Pose do
				local cfB = b.Pose[joint] or IDENTITY
				pose[joint] = cfA:Lerp(cfB, alpha)
			end
			for joint, cfB in b.Pose do
				if pose[joint] == nil then
					pose[joint] = IDENTITY:Lerp(cfB, alpha)
				end
			end
			return pose
		end
	end
	return keys[count].Pose
end

local function scaled(cf: CFrame, scale: number): CFrame
	if scale == 1 then
		return cf
	end
	local p = cf.Position
	if p.X == 0 and p.Y == 0 and p.Z == 0 then
		return cf
	end
	return CFrame.new(p * scale) * cf.Rotation
end

function Animator:Step(dt: number)
	self.Time += dt
	local scale = self.PositionScale
	local result: Pose = {}

	-- Layer procedurali (si sommano)
	for _, layer in self.Layers do
		local diff = layer.Target - layer.Weight
		local stepSize = layer.FadeSpeed * dt
		if math.abs(diff) <= stepSize then
			layer.Weight = layer.Target
		else
			layer.Weight += math.sign(diff) * stepSize
		end
		if layer.Weight > 0.001 then
			local ok, pose = pcall(layer.Fn, self.Time, self.Context, dt)
			if not ok and not layer.Warned then
				-- segnala l'errore una sola volta nella finestra Output
				layer.Warned = true
				warn(("[Animazioni] Errore nel layer '%s' di %s: %s"):format(layer.Name, self.Model.Name, tostring(pose)))
			end
			if ok and pose then
				local w = layer.Weight
				for joint, cf in pose do
					local value = scaled(cf, scale)
					if w < 0.999 then
						value = IDENTITY:Lerp(value, w)
					end
					local current = result[joint]
					result[joint] = if current then current * value else value
				end
			end
		end
	end

	-- Clip (sovrascrivono in base al peso)
	local clipDt = dt
	if self.Paused > 0 then
		self.Paused -= dt
		clipDt = 0
	end
	local i = 1
	while i <= #self.Clips do
		local active = self.Clips[i]
		local clip = active.Clip
		active.Time += clipDt * active.Speed
		local duration = clip.Duration
		local finished = false
		if active.Remove then
			finished = true
		elseif active.Loop then
			if duration > 0 and active.Time > duration then
				active.Time %= duration
			end
		elseif active.Time >= duration + (clip.Hold or 0) then
			if not active.Stopping then
				active.Stopping = true
				active.StopTime = 0
			end
		end

		local weight = active.Weight
		local fadeIn = clip.FadeIn or 0.06
		if fadeIn > 0 and active.Time < fadeIn then
			weight *= active.Time / fadeIn
		end
		if active.Stopping then
			active.StopTime += dt
			local fade = math.max(active.StopFade, 0.0001)
			weight *= math.clamp(1 - active.StopTime / fade, 0, 1)
			if active.StopTime >= fade then
				finished = true
			end
		end

		if finished then
			table.remove(self.Clips, i)
		else
			if weight > 0.001 then
				local pose = sampleClip(clip, math.min(active.Time, duration))
				for joint, cf in pose do
					local value = scaled(cf, scale)
					local current = result[joint] or IDENTITY
					result[joint] = if weight >= 0.999 then value else current:Lerp(value, weight)
				end
			end
			i += 1
		end
	end

	-- correzioni finali della posa (es. ArmReach: le mani che afferrano un punto del mondo)
	if self.PostStep then
		local ok, err = pcall(self.PostStep, result, dt)
		if not ok and not self.PostWarned then
			self.PostWarned = true
			warn(("[Animazioni] Errore nella correzione della posa di %s: %s"):format(self.Model.Name, tostring(err)))
		end
	end

	self.Result = result
end

function Animator:Apply()
	local result = self.Result
	local scale = modelScale(self.Model)
	self.BaseScale = scale
	for name, motor in self.Motors do
		local base = self.BaseC0[motor]
		if base == nil then
			-- salvata come se il modello fosse a scala 1
			base = CFrame.new(motor.C0.Position / scale) * motor.C0.Rotation
			self.BaseC0[motor] = base
		end
		if scale ~= 1 then
			base = CFrame.new(base.Position * scale) * base.Rotation
		end
		local offset = result[name]
		local target = if offset then base * offset else base
		if motor.C0 ~= target then
			motor.C0 = target
		end
	end
end

function Animator:Update(dt: number)
	self:Step(dt)
	self:Apply()
end

function Animator:Destroy()
	table.clear(self.Clips)
	table.clear(self.Layers)
	local scale = modelScale(self.Model)
	for motor, base in self.BaseC0 do
		if motor.Parent then
			motor.C0 = CFrame.new(base.Position * scale) * base.Rotation
		end
	end
	table.clear(self.BaseC0)
end

return Animator
