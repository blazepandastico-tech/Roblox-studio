--[[
	ArmReach - le mani di un gigante afferrano punti precisi del mondo (es. il bordo del Muro)

	Si aggancia a un ProceduralAnimator in modo assoluto (Animator.PostStep): dopo che layer e clip
	hanno calcolato la posa, sposta spalla, gomito e polso di ogni braccio perché il centro della
	mano arrivi sul punto scelto (cinematica inversa a due ossa). Il gomito si gira verso "Pole" e la
	mano si allinea a "Dir". Il resto del corpo continua ad animarsi (ruggito, calcio...): le mani
	restano attaccate finché il punto è raggiungibile.

	Funziona con tutti i giganti che usano i nomi delle articolazioni di TitanBuilder (colosso fatto
	con le parti, modello 3D importato con MeshTitan, giganti a blocchi).
]]

local Util = require(script.Parent.Parent.Lib.Util)

local ArmReach = {}

local IDENTITY = CFrame.identity
local MAX_BEND = math.rad(150) -- il gomito non si piega oltre
local MAX_WRIST = math.rad(95) -- e il polso nemmeno

export type Target = { Target: Vector3, Dir: Vector3, Pole: Vector3 }

type Chain = {
	Root: BasePart,
	Up: { Motor6D },
	Shoulder: Motor6D,
	Elbow: Motor6D,
	Wrist: Motor6D,
}

-- posa di riposo della giuntura (come la usa l'animatore)
local function base(animator, m: Motor6D): CFrame
	local b = animator.BaseC0[m] or m.C0
	local s = animator.BaseScale or 1
	if s ~= 1 then
		b = CFrame.new(b.Position * s) * b.Rotation
	end
	return b
end

local function perp(v: Vector3, axis: Vector3): Vector3
	return v - axis * v:Dot(axis)
end

-- rotazione più breve che porta la direzione u su v (entrambe unitarie), al massimo maxAngle
local function turn(u: Vector3, v: Vector3, maxAngle: number): CFrame
	local axis = u:Cross(v)
	local s = axis.Magnitude
	if s < 1e-6 then
		return IDENTITY
	end
	return CFrame.fromAxisAngle(axis / s, math.min(math.atan2(s, u:Dot(v)), maxAngle))
end

local function motorDriving(model: Model, part: BasePart): Motor6D?
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 == part then
			return d
		end
	end
	return nil
end

-- le giunture del braccio ("Right"/"Left") e quelle dalla radice al busto
local function chainOf(animator, side: string): Chain?
	local motors = animator.Motors
	local shoulder, elbow, wrist = motors[side .. "Shoulder"], motors[side .. "Elbow"], motors[side .. "Wrist"]
	if not (shoulder and elbow and wrist and shoulder.Part0) then
		return nil
	end
	local up = {}
	local part = shoulder.Part0 :: BasePart
	for _ = 1, 16 do
		local m = motorDriving(animator.Model, part)
		if not (m and m.Part0) then
			break
		end
		table.insert(up, 1, m)
		part = m.Part0 :: BasePart
	end
	return { Root = part, Up = up, Shoulder = shoulder, Elbow = elbow, Wrist = wrist }
end

-- sposta spalla, gomito e polso di un braccio nella posa "result" (peso w: 0 = posa animata, 1 = presa)
local function solve(animator, c: Chain, result, spec: Target, w: number)
	-- dove si trova la spalla con la posa di questo fotogramma (seguendo le giunture dalla radice)
	local cf = c.Root.CFrame
	for _, m in c.Up do
		cf = cf * base(animator, m) * (result[m.Name] or IDENTITY) * m.C1:Inverse()
	end
	local s0 = cf * base(animator, c.Shoulder)

	-- il gomito e il polso visti dalla spalla (posa di riposo)
	local fe = c.Shoulder.C1:Inverse() * base(animator, c.Elbow)
	local fw = c.Elbow.C1:Inverse() * base(animator, c.Wrist)
	local handOffset = c.Wrist.C1:Inverse().Position
	local handLength = handOffset.Magnitude
	local handAxis = if handLength > 1e-4 then handOffset / handLength else Vector3.new(0, -1, 0)

	local dir = spec.Dir.Unit
	local goal = s0:PointToObjectSpace(spec.Target - dir * handLength)
	local function wristAt(theta: number): Vector3
		return fe * CFrame.Angles(theta, 0, 0) * fw.Position
	end

	-- piega del gomito: la distanza spalla-polso deve essere quella del bersaglio
	local d = goal.Magnitude
	local lo, hi = 0, MAX_BEND
	local theta
	if d >= wristAt(lo).Magnitude then
		theta = lo
	elseif d <= wristAt(hi).Magnitude then
		theta = hi
	else
		for _ = 1, 22 do
			local mid = (lo + hi) * 0.5
			if wristAt(mid).Magnitude > d then
				lo = mid
			else
				hi = mid
			end
		end
		theta = (lo + hi) * 0.5
	end

	-- rotazione della spalla: il polso sulla linea del bersaglio, il gomito verso "Pole"
	local v = wristAt(theta)
	local a0 = v.Unit
	local p0 = perp(fe.Position, a0)
	if p0.Magnitude < 1e-3 then
		p0 = perp(fe:VectorToWorldSpace(Vector3.zAxis), a0)
	end
	local a1 = if d > 1e-4 then goal.Unit else a0
	local p1 = perp(s0:VectorToObjectSpace(spec.Pole), a1)
	if p1.Magnitude < 1e-3 then
		p1 = perp(p0, a1)
	end
	if p0.Magnitude < 1e-6 or p1.Magnitude < 1e-6 then
		return
	end
	p0, p1 = p0.Unit, p1.Unit
	local from = CFrame.fromMatrix(Vector3.zero, a0, p0, a0:Cross(p0))
	local to = CFrame.fromMatrix(Vector3.zero, a1, p1, a1:Cross(p1))
	local shoulder = to * from:Inverse()
	local elbow = CFrame.Angles(theta, 0, 0)

	-- il polso gira la mano verso "Dir"
	local w0 = s0 * shoulder * fe * elbow * fw
	local wrist = turn(handAxis, w0:VectorToObjectSpace(dir).Unit, MAX_WRIST)

	local names = { c.Shoulder.Name, c.Elbow.Name, c.Wrist.Name }
	local poses = { shoulder, elbow, wrist }
	for i, name in names do
		result[name] = if w >= 0.999 then poses[i] else (result[name] or IDENTITY):Lerp(poses[i], w)
	end
end

export type Grip = {
	Weight: number,
	Goal: number,
	Speed: number,
	Arms: { [string]: Target },
	Lean: CFrame?,
	Set: (self: Grip, weight: number, seconds: number?) -> (),
}

-- Aggancia la presa all'animatore. arms = { Right = Target, Left = Target } (anche uno solo);
-- lean = piega del busto mentre tiene la presa. Con grip:Set(1, secondi) le mani vanno sui punti,
-- con grip:Set(0, secondi) tornano all'animazione normale.
function ArmReach.Attach(animator, arms: { [string]: Target }, lean: CFrame?): Grip
	local chains: { [string]: Chain } = {}
	for side in arms do
		local c = chainOf(animator, side)
		if c then
			chains[side] = c
		end
	end
	local grip = {
		Weight = 0,
		Goal = 0,
		Speed = 1,
		Arms = arms,
		Lean = lean,
	} :: any
	function grip.Set(self, weight: number, seconds: number?)
		self.Goal = math.clamp(weight, 0, 1)
		self.Speed = 1 / math.max(seconds or 0.5, 0.01)
	end
	animator.PostStep = function(result, dt: number)
		local diff = grip.Goal - grip.Weight
		local stepSize = grip.Speed * dt
		grip.Weight = if math.abs(diff) <= stepSize then grip.Goal else grip.Weight + math.sign(diff) * stepSize
		if grip.Weight <= 0.001 then
			return
		end
		local w = Util.Ease(grip.Weight, "SineInOut")
		if grip.Lean then
			result.Waist = (result.Waist or IDENTITY):Lerp(grip.Lean, w * 0.75)
		end
		for side, c in chains do
			solve(animator, c, result, grip.Arms[side], w)
		end
	end
	return grip
end

-- Le due mani sul bordo di un muro. "edge" = punto sul bordo in cima al muro, dal lato del gigante;
-- "toward" = direzione dal gigante verso il muro. Le mani si appoggiano in cima, ben oltre il bordo
-- (le dita arrivano al lato opposto) e più larghe delle spalle, con i gomiti in basso e in fuori.
function ArmReach.WallGrip(animator, height: number, edge: Vector3, toward: Vector3): Grip
	local f = Vector3.new(toward.X, 0, toward.Z).Unit
	local right = f:Cross(Vector3.yAxis)
	local arms = {}
	for side, s in { Right = 1, Left = -1 } do
		arms[side] = {
			Target = edge + right * (s * 0.22 * height) + f * (0.1 * height) + Vector3.yAxis * (0.013 * height),
			Dir = (f * 0.9 - Vector3.yAxis * 0.42).Unit,
			Pole = (right * (s * 0.7) - Vector3.yAxis - f * 0.25).Unit,
		}
	end
	return ArmReach.Attach(animator, arms, CFrame.Angles(math.rad(-8), 0, 0))
end

return ArmReach
