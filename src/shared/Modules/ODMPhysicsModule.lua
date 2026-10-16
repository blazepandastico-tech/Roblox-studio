--[[
	ODMPhysicsModule - la matematica dei Rampini a Gas, condivisa tra client e server.

	Il client la usa ogni frame per simulare il volo (è lui il proprietario fisico del personaggio,
	quindi niente ritardi di rete); il server usa le stesse formule per convalidare:
	portata degli agganci, consumo di gas e velocità massima plausibile.

	Non tocca istanze né servizi: solo Vector3 e numeri, così si può testare fuori da Studio.

	Novità rispetto al vecchio controller:
	  - la trazione scala con la VICINANZA dell'aggancio (più è vicino, più tira forte) e con
	    l'ANGOLO rispetto alla direzione di volo (tirare "in avanti" rende di più che frenare);
	  - SLANCIO CINETICO: volare veloce rasente a muri, alberi e tetti accumula slancio (0..1)
	    che alza la velocità massima e dà una piccola spinta in avanti. Si perde allontanandosi
	    dagli ostacoli o rallentando.
]]

local Config = require(script.Parent.Parent.Config)

local ODMPhysics = {}

local ODM = Config.ODM

export type Hook = {
	Target: Vector3, -- punto d'aggancio nel mondo
	RopeLength: number, -- lunghezza del cavo (si accorcia mentre il verricello tira)
	Held: boolean, -- il tasto è premuto: il verricello tira
}

export type StepInput = {
	Position: Vector3,
	Velocity: Vector3,
	Hooks: { Hook },
	Move: Vector3, -- direzione di sterzata nel mondo (WASD già ruotato dalla camera), modulo 0..1
	Boost: boolean,
	BoostDirection: Vector3, -- di solito lo sguardo della camera
	Gas: number,
	GasEfficiency: number,
	SpeedMult: number,
	Momentum: number, -- slancio accumulato 0..1
	Clearance: number?, -- distanza dall'ostacolo più vicino (nil = nessuno nel raggio)
	Range: number?, -- portata del rampino (per la scala della vicinanza)
	Gravity: number?, -- workspace.Gravity (196.2 se assente)
	dt: number,
}

export type StepOutput = {
	Velocity: Vector3,
	Acceleration: Vector3,
	GasUsed: number,
	Hanging: boolean,
	Momentum: number,
	Boosting: boolean,
}

local function unit(v: Vector3): Vector3
	local m = v.Magnitude
	if m < 1e-6 then
		return Vector3.zero
	end
	return v / m
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Moltiplicatore di velocità finale (statistica + Risveglio della stirpe)
function ODMPhysics.SpeedMult(reel: number?, awakened: boolean?): number
	local mult = if type(reel) == "number" and reel > 0 then reel else 1
	if awakened then
		mult *= ODM.AwakenedSpeedMult
	end
	return mult
end

-- Velocità massima in volo, con lo slancio cinetico
function ODMPhysics.MaxSpeed(speedMult: number, momentum: number?): number
	return ODM.MaxSpeed * math.sqrt(math.max(speedMult, 0.01)) * (1 + ODM.MomentumSpeedBonus * math.clamp(momentum or 0, 0, 1))
end

-- Fattore di vicinanza: un aggancio vicino tira più forte di uno al limite della portata
function ODMPhysics.ProximityFactor(dist: number, range: number?): number
	local r = math.max(range or 115, 1)
	return lerp(ODM.NearPullMult, ODM.FarPullMult, math.clamp(dist / r, 0, 1))
end

-- Fattore d'angolo: quanto la trazione è allineata con la direzione di volo.
-- In avanti (dot = 1) rende di più, "contromano" (dot = -1) rende di meno: per invertire
-- la rotta conviene oscillare attorno al cavo invece di tirare dritto.
function ODMPhysics.AngleFactor(velocity: Vector3, pullDir: Vector3): number
	local speed = velocity.Magnitude
	if speed < 5 then
		return 1
	end
	local align = (velocity / speed):Dot(pullDir)
	if align >= 0 then
		return 1 + ODM.AlignedPullBonus * align
	end
	return 1 + ODM.OpposedPullPenalty * align
end

-- Aggiorna lo slancio cinetico (0..1)
function ODMPhysics.UpdateMomentum(momentum: number, speed: number, clearance: number?, dt: number): number
	local radius = ODM.ProximityRadius
	if clearance and clearance < radius and speed >= ODM.MomentumMinSpeed then
		local closeness = 1 - math.clamp(clearance / radius, 0, 1)
		local fast = math.clamp((speed - ODM.MomentumMinSpeed) / ODM.MomentumMinSpeed, 0.25, 1)
		return math.min(1, momentum + ODM.MomentumGain * closeness * fast * dt)
	end
	local decay = if speed < ODM.MomentumMinSpeed * 0.6 then ODM.MomentumDecay * 3 else ODM.MomentumDecay
	return math.max(0, momentum - decay * dt)
end

-- Gas consumato in dt (stesse regole per client e server)
function ODMPhysics.GasDrain(reeling: number, boosting: boolean, gasEfficiency: number, dt: number): number
	local eff = math.max(gasEfficiency, 0.1)
	local used = reeling * ODM.GasDrainReel * dt
	if boosting then
		used += ODM.GasDrainBoost * dt
	end
	return used / eff
end

function ODMPhysics.HookCost(gasEfficiency: number): number
	return ODM.GasPerHook / math.max(gasEfficiency, 0.1)
end

function ODMPhysics.DodgeCost(gasEfficiency: number): number
	return ODM.GasPerDodge / math.max(gasEfficiency, 0.1)
end

--[[
	Un passo di simulazione in volo. Le lunghezze dei cavi vengono accorciate sul posto
	(il verricello riavvolge); tutto il resto viene restituito.
]]
function ODMPhysics.Step(input: StepInput): StepOutput
	local dt = input.dt
	local position = input.Position
	local velocity = input.Velocity
	local mult = input.SpeedMult
	local accel = Vector3.zero
	local hasGas = input.Gas > 0
	local reeling = 0
	local hanging = false
	local attached = #input.Hooks

	for _, h in input.Hooks do
		local to = h.Target - position
		local dist = to.Magnitude
		if dist > 0.5 then
			local dir = to / dist
			if hasGas and h.Held then
				local reel = ODM.ReelAcceleration * mult * ODMPhysics.ProximityFactor(dist, input.Range) * ODMPhysics.AngleFactor(velocity, dir)
				local minDist = ODM.MinAttachDistance
				if dist < minDist * 2.5 then
					-- arrivando alla parete il verricello rallenta: ci si appende invece di schiantarsi
					reel *= math.clamp((dist - minDist * 0.5) / (minDist * 2), 0, 1)
					hanging = hanging or (dist < minDist * 1.6 and velocity.Magnitude < 25)
				end
				accel += dir * reel
				reeling += 1
			end
			-- il cavo è teso: non ci si può allontanare oltre la sua lunghezza (pendolo)
			h.RopeLength = math.min(h.RopeLength, dist + 0.3)
			if dist >= h.RopeLength - 0.3 then
				local radial = velocity:Dot(dir)
				if radial < 0 then
					velocity -= dir * radial
				end
			end
		end
	end
	if hanging then
		velocity *= 1 - math.min(1, dt * 6)
	end
	if attached > 0 then
		accel += Vector3.new(0, (input.Gravity or 196.2) * ODM.AntiGravity, 0)
	end

	if input.Move.Magnitude > 0.05 then
		accel += input.Move * (if attached > 0 then ODM.SteerAcceleration else ODM.AirSteer) * mult
	end
	local boosting = input.Boost and hasGas
	if boosting then
		accel += unit(input.BoostDirection) * ODM.BoostAcceleration * mult
	end

	-- slancio cinetico: piccola spinta lungo la direzione di volo
	local momentum = ODMPhysics.UpdateMomentum(input.Momentum, velocity.Magnitude, input.Clearance, dt)
	if momentum > 0 and velocity.Magnitude > 1 then
		accel += unit(velocity) * ODM.MomentumThrust * momentum
	end

	velocity += accel * dt
	velocity *= 1 - ODM.Drag * dt
	local maxSpeed = ODMPhysics.MaxSpeed(mult, momentum)
	if velocity.Magnitude > maxSpeed then
		velocity = velocity.Unit * maxSpeed
	end

	return {
		Velocity = velocity,
		Acceleration = accel,
		GasUsed = ODMPhysics.GasDrain(reeling, boosting, input.GasEfficiency, dt),
		Hanging = hanging,
		Momentum = momentum,
		Boosting = boosting,
	}
end

-- CONVALIDA (server) ---------------------------------------------------------------------

-- Il punto d'aggancio è raggiungibile? Si tollera lo spostamento dovuto alla latenza.
function ODMPhysics.ValidateAnchor(rootPosition: Vector3, anchor: Vector3, range: number, speed: number): boolean
	local slack = ODM.Validation.AnchorSlack + speed * ODM.Validation.LatencyWindow
	return (anchor - rootPosition).Magnitude <= range + slack
end

-- Spostamento massimo credibile in dt secondi (volo, abilità, spinte dei giganti)
function ODMPhysics.MaxDisplacement(speedMult: number, dt: number): number
	local v = ODM.Validation
	local speed = math.max(ODMPhysics.MaxSpeed(speedMult, 1), v.MinSpeedCap)
	return speed * dt * v.SpeedTolerance + v.DisplacementSlack
end

return ODMPhysics
