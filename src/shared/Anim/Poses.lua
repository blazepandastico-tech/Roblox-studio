--[[
	Poses - libreria di animazioni procedurali
	Assi delle articolazioni R15 (e dei giganti, che usano gli stessi nomi):
	  Spalla:  +X = braccio in avanti/alto | Destra +Z / Sinistra -Z = braccio in fuori
	  Gomito:  +X = piega                 | Ginocchio: -X = piega
	  Anca:    +X = gamba in avanti       | Busto (Waist) / Root: -X = piegati in avanti, +Y = ruota a sinistra
	  Collo:   -X = guarda in basso        | Mandibola (solo giganti): +X = bocca aperta
	Le posizioni nelle clip dei giganti sono frazioni dell'altezza (PositionScale = altezza).
]]

local Poses = {}

local rad = math.rad
local sin, cos, abs = math.sin, math.cos, math.abs

local function A(x: number?, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0))
end

local function TA(px: number, py: number, pz: number, x: number?, y: number?, z: number?): CFrame
	return CFrame.new(px, py, pz) * A(x, y, z)
end

Poses.A = A
Poses.TA = TA

-- Crea una clip normalizzando le articolazioni mancanti
local function clip(name: string, keys, options)
	local joints = {}
	for _, key in keys do
		for joint in key.Pose do
			joints[joint] = true
		end
	end
	for _, key in keys do
		for joint in joints do
			if key.Pose[joint] == nil then
				key.Pose[joint] = CFrame.identity
			end
		end
	end
	local def = {
		Name = name,
		Keys = keys,
		Duration = keys[#keys].T,
		FadeIn = 0.05,
		FadeOut = 0.15,
		Priority = 2,
		Loop = false,
	}
	if options then
		for k, v in options do
			def[k] = v
		end
	end
	return def
end

local function K(t: number, pose, ease: string?)
	return { T = t, Pose = pose, Ease = ease }
end

-- Rotazione completa su un asse (servono più fotogrammi: 360° = identità)
local function spinKeys(duration: number, turns: number, axis: string, joint: string, extra, steps: number?)
	local keys = {}
	local n = (steps or 3) * turns
	for i = 0, n do
		local angle = 360 * turns * i / n
		local rot
		if axis == "X" then
			rot = A(-angle, 0, 0)
		elseif axis == "Y" then
			rot = A(0, angle, 0)
		else
			rot = A(0, 0, angle)
		end
		local pose = {}
		if extra then
			for j, cf in extra do
				pose[j] = cf
			end
		end
		pose[joint] = if extra and extra[joint] then rot * extra[joint] else rot
		table.insert(keys, K(duration * i / n, pose, "Linear"))
	end
	return keys
end

-- =====================================================================================
-- UMANI
-- =====================================================================================

Poses.Human = {}

-- Lame in mano (layer sempre attivo quando sei a terra con le lame)
function Poses.Human.BladeStance(_t, ctx)
	local moving = ctx.Moving or 0
	return {
		RightShoulder = A(22 - moving * 10, 0, 12),
		RightElbow = A(32, 0, 0),
		RightWrist = A(-15, 0, 0),
		LeftShoulder = A(22 - moving * 10, 0, -12),
		LeftElbow = A(32, 0, 0),
		LeftWrist = A(-15, 0, 0),
	}
end

-- LOCOMOZIONE DA BATTAGLIA DEL GIOCATORE -------------------------------------------------------
-- Sostituisce camminata e corsa standard di Roblox (lo script Animate viene disattivato):
--   fermo  = guardia con le ginocchia piegate e le lame pronte
--   cammina = passo tattico, basso e corto, lame in avanti
--   corre   = corsa d'assalto piegato in avanti con le lame portate indietro
--   salto   = ginocchio alto e braccia slanciate
--   caduta  = braccia alzate che si agitano, gambe a penzoloni (più agitate se la caduta è lunga)
-- ctx: Flat (velocità orizzontale), Phase (ciclo del passo), Air (0..1), VY (velocità verticale),
--      FallT (secondi di caduta), Land (0..1 atterraggio), Blades (bool)

-- angoli: { X, Y, Z } in gradi; Root può avere anche la quota (P)
local function lerpN(a: number, b: number, k: number): number
	return a + (b - a) * k
end

local function blendPose(a, b, k: number)
	if k <= 0 then
		return a
	elseif k >= 1 then
		return b
	end
	local out = {}
	for joint, va in a do
		local vb = b[joint] or { 0, 0, 0, 0 }
		out[joint] = { lerpN(va[1], vb[1], k), lerpN(va[2], vb[2], k), lerpN(va[3], vb[3], k), lerpN(va[4] or 0, vb[4] or 0, k) }
	end
	for joint, vb in b do
		if not out[joint] then
			out[joint] = { vb[1] * k, vb[2] * k, vb[3] * k, (vb[4] or 0) * k }
		end
	end
	return out
end

-- FERMO: in piedi, peso sulle gambe leggermente piegate, lame basse ai fianchi puntate indietro
local function guardPose(t: number, blades: boolean)
	local br = sin(t * 2.2)
	local shift = sin(t * 0.45) -- ogni tanto sposta il peso da una gamba all'altra
	local pose = {
		Root = { -3, 6, shift * 2, -0.18 + br * 0.025 },
		Waist = { -4 + br * 1.4, -4, -shift * 1.5 },
		Neck = { 3, -3, 0 },
		RightHip = { 8, 0, 6 + shift * 2 },
		RightKnee = { -14, 0, 0 },
		RightAnkle = { 6, 0, 0 },
		LeftHip = { 2, 0, -6 + shift * 2 },
		LeftKnee = { -10, 0, 0 },
		LeftAnkle = { 8, 0, 0 },
	}
	if blades then
		pose.RightShoulder = { -8 + br * 1.5, 0, 16 }
		pose.RightElbow = { 18, 0, 0 }
		pose.RightWrist = { 22, 0, 0 }
		pose.LeftShoulder = { -8 + br * 1.5, 0, -16 }
		pose.LeftElbow = { 18, 0, 0 }
		pose.LeftWrist = { 22, 0, 0 }
	else
		pose.RightShoulder = { br * 1.5, 0, 6 }
		pose.RightElbow = { 10, 0, 0 }
		pose.LeftShoulder = { br * 1.5, 0, -6 }
		pose.LeftElbow = { 10, 0, 0 }
	end
	return pose
end

-- CAMMINATA: busto dritto, braccia già un po' aperte e indietro, passo deciso
local function walkPose(p: number, blades: boolean)
	local s = sin(p)
	local kneeR = -(10 + 40 * math.max(0, sin(p + 1.6)))
	local kneeL = -(10 + 40 * math.max(0, sin(p + 1.6 + math.pi)))
	local pose = {
		Root = { -6, 0, s * 2, -0.08 - abs(cos(p)) * 0.07 },
		Waist = { -3, -s * 6, 0 },
		Neck = { 5, s * 3, 0 },
		RightHip = { s * 34, 0, 3 },
		LeftHip = { -s * 34, 0, -3 },
		RightKnee = { kneeR, 0, 0 },
		LeftKnee = { kneeL, 0, 0 },
		RightAnkle = { sin(p + 0.6) * 14, 0, 0 },
		LeftAnkle = { -sin(p + 0.6) * 14, 0, 0 },
	}
	if blades then
		pose.RightShoulder = { -22 - s * 4, 0, 24 }
		pose.RightElbow = { 10, 0, 0 }
		pose.RightWrist = { 12, 0, 0 }
		pose.LeftShoulder = { -22 + s * 4, 0, -24 }
		pose.LeftElbow = { 10, 0, 0 }
		pose.LeftWrist = { 12, 0, 0 }
	else
		pose.RightShoulder = { -s * 30, 0, 6 }
		pose.RightElbow = { 25, 0, 0 }
		pose.LeftShoulder = { s * 30, 0, -6 }
		pose.LeftElbow = { 25, 0, 0 }
	end
	return pose
end

-- CORSA (come nel riferimento): busto poco inclinato, braccia TESE e FERME,
-- aperte ai lati e spinte all'indietro, gambe con passi corti e rapidi
local function runPose(p: number, blades: boolean)
	local s = sin(p)
	local kneeR = -(15 + 70 * math.max(0, sin(p + 1.4)))
	local kneeL = -(15 + 70 * math.max(0, sin(p + 1.4 + math.pi)))
	local pose = {
		Root = { -15, 0, s * 2, -0.1 - abs(cos(p)) * 0.1 },
		Waist = { -6, -s * 5, 0 },
		Neck = { 12, s * 2, 0 },
		RightHip = { s * 50 + 8, 0, 2 },
		LeftHip = { -s * 50 + 8, 0, -2 },
		RightKnee = { kneeR, 0, 0 },
		LeftKnee = { kneeL, 0, 0 },
		RightAnkle = { sin(p + 0.35) * 22, 0, 0 },
		LeftAnkle = { -sin(p + 0.35) * 22, 0, 0 },
	}
	if blades then
		pose.RightShoulder = { -40 + s * 2, 0, 40 }
		pose.RightElbow = { 6, 0, 0 }
		pose.RightWrist = { 10, 0, 0 }
		pose.LeftShoulder = { -40 - s * 2, 0, -40 }
		pose.LeftElbow = { 6, 0, 0 }
		pose.LeftWrist = { 10, 0, 0 }
	else
		pose.RightShoulder = { -38, 0, 38 }
		pose.RightElbow = { 6, 0, 0 }
		pose.LeftShoulder = { -38, 0, -38 }
		pose.LeftElbow = { 6, 0, 0 }
	end
	return pose
end

-- SALTO (in salita): un ginocchio alto, l'altra gamba distesa sotto, braccia slanciate verso l'alto
local function jumpPose(t: number, blades: boolean)
	local f = sin(t * 5) * 3
	return {
		Root = { -6, 0, 0, 0 },
		Waist = { -8, 6, 0 },
		Neck = { 10, -4, 0 },
		RightHip = { 75 + f, 0, 8 },
		RightKnee = { -100, 0, 0 },
		RightAnkle = { 25, 0, 0 },
		LeftHip = { -12 - f, 0, -6 },
		LeftKnee = { -38, 0, 0 },
		LeftAnkle = { 30, 0, 0 },
		RightShoulder = { if blades then 55 else 75, 0, 38 + f },
		RightElbow = { 40, 0, 0 },
		RightWrist = { 10, 0, 0 },
		LeftShoulder = { if blades then -25 else -35, 0, -42 - f },
		LeftElbow = { 30, 0, 0 },
		LeftWrist = { 10, 0, 0 },
	}
end

-- CADUTA (in discesa): busto all'indietro, braccia ALZATE e larghe che si agitano per l'equilibrio,
-- gambe a penzoloni che scalciano; più dura la caduta, più i movimenti diventano ampi e disperati
local function fallPose(t: number, blades: boolean, panic: number)
	local w = t * (6 + 7 * panic)
	local a = sin(w)
	local b = sin(w * 1.35 + 1.2)
	local c = cos(w)
	local wide = 0.35 + 0.65 * panic
	local arm = if blades then 0.8 else 1
	return {
		Root = { 12 + 8 * panic, sin(t * 1.9) * 6 * panic, sin(t * 2.6) * 5 * panic, 0 },
		Waist = { 8 + 4 * panic, a * 5 * panic, b * 4 * panic },
		Neck = { -20 - 6 * panic, b * 6 * panic, 0 },
		-- braccia: alte e aperte, mulinello quando la caduta si fa lunga
		RightShoulder = { (115 + a * 40 * wide) * arm, c * 18 * panic, 55 + b * 22 * wide },
		RightElbow = { 30 + (b + 1) * 18 * wide, 0, 0 },
		RightWrist = { a * 15, 0, 0 },
		LeftShoulder = { (115 - a * 40 * wide) * arm, -c * 18 * panic, -55 - b * 22 * wide },
		LeftElbow = { 30 + (1 - b) * 18 * wide, 0, 0 },
		LeftWrist = { -a * 15, 0, 0 },
		-- gambe: penzolano e pedalano nel vuoto
		RightHip = { 22 + a * 28 * wide, 0, 12 + panic * 8 },
		RightKnee = { -35 - math.max(0, a) * 55 * wide, 0, 0 },
		RightAnkle = { -15 + a * 10, 0, 0 },
		LeftHip = { 2 - a * 28 * wide, 0, -12 - panic * 8 },
		LeftKnee = { -20 - math.max(0, -a) * 55 * wide, 0, 0 },
		LeftAnkle = { -15 - a * 10, 0, 0 },
	}
end

function Poses.Human.BattleLoco(t, ctx)
	local speed = ctx.Flat or 0
	local blades = ctx.Blades == true
	local walk = math.clamp(speed / 5, 0, 1)
	local run = math.clamp((speed - (ctx.RunThreshold or 13)) / 6, 0, 1)
	local p = ctx.Phase or 0
	local fwd = ctx.Forward or 1 -- 1 avanti, -1 indietro
	local side = ctx.Side or 0 -- -1 sinistra, 1 destra
	local back = math.clamp(-fwd, 0, 1)
	local strafe = math.clamp(abs(side) - 0.2, 0, 1) * (1 - back * 0.5)
	-- all'indietro e di lato non si corre mai a testa bassa
	run *= 1 - math.max(back, strafe * 0.6)
	local pose = guardPose(t, blades)
	pose = blendPose(pose, walkPose(p, blades), walk)
	pose = blendPose(pose, runPose(p, blades), run)

	-- DIREZIONE: indietro (busto dritto, passo più corto), di lato (passo laterale incrociato)
	local s = sin(p)
	local moving = walk
	if moving > 0 then
		local root = pose.Root
		root[1] = root[1] * (1 - back * 1.2) + back * 6 * moving
		root[2] += side * 32 * strafe * moving
		pose.Waist[2] -= side * 22 * strafe * moving
		pose.Neck[2] -= side * 12 * strafe * moving
		local swing = 1 - 0.55 * strafe
		for _, j in { "RightHip", "LeftHip" } do
			pose[j][1] = 5 + (pose[j][1] - 5) * swing
		end
		pose.RightHip[3] += s * 20 * strafe * moving * (if side > 0 then 1 else -1)
		pose.LeftHip[3] += s * 20 * strafe * moving * (if side > 0 then 1 else -1)
	end

	-- CURVE: ci si inclina dentro la curva, tanto più quanto più si corre
	local turn = math.clamp((ctx.Turn or 0) * 0.06, -14, 14) * (0.35 + 0.65 * run) * walk
	pose.Root[3] -= turn
	pose.Waist[3] -= turn * 0.4

	-- ATTERRAGGIO: piegamento sulle ginocchia che assorbe l'impatto
	local land = ctx.Land or 0
	if land > 0 then
		pose.Root[4] = (pose.Root[4] or 0) - land * 0.7
		pose.Root[1] -= land * 8
		pose.Waist[1] -= land * 12
		pose.RightKnee[1] -= land * 45
		pose.LeftKnee[1] -= land * 45
		pose.RightHip[1] += land * 28
		pose.LeftHip[1] += land * 28
		pose.RightAnkle[1] += land * 15
		pose.LeftAnkle[1] += land * 15
	end

	-- ARIA: in salita ginocchio alto e braccia slanciate, in discesa braccia alzate che si agitano
	local air = math.clamp(ctx.Air or 0, 0, 1)
	if air > 0 then
		local falling = math.clamp((-(ctx.VY or 0) - 4) / 22, 0, 1)
		local panic = math.clamp((ctx.FallT or 0) / 1.1, 0, 1)
		local airP = blendPose(jumpPose(t, blades), fallPose(t, blades, panic), falling)
		pose = blendPose(pose, airP, air)
	end

	local out = {}
	for joint, v in pose do
		if joint == "Root" then
			out.Root = TA(0, v[4] or 0, 0, v[1], v[2], v[3])
		else
			out[joint] = A(v[1], v[2], v[3])
		end
	end
	return out
end

-- Volo con i Rampini: il corpo si allinea alla direzione del movimento
function Poses.Human.ODMFly(t, ctx)
	local speed = ctx.Speed or 0
	local fly = math.clamp(speed / 110, 0, 1)
	local pitch = (ctx.Pitch or 90) * fly -- 0 = in piedi, 90 = orizzontale, 180 = in picchiata
	local roll = ctx.Roll or 0
	local flutter = sin(t * 18) * 3 * fly
	return {
		Root = A(-pitch, 0, roll),
		Waist = A(-6 + flutter * 0.3, 0, 0),
		Neck = A(math.min(pitch * 0.55, 60), 0, 0),
		RightShoulder = A(-30 - 20 * fly, 0, 30 + 15 * fly),
		RightElbow = A(25, 0, 0),
		RightWrist = A(-25, 0, 0),
		LeftShoulder = A(-30 - 20 * fly, 0, -30 - 15 * fly),
		LeftElbow = A(25, 0, 0),
		LeftWrist = A(-25, 0, 0),
		RightHip = A(-10 - 12 * fly + flutter, 0, 4),
		LeftHip = A(-14 - 12 * fly - flutter, 0, -4),
		RightKnee = A(-30 - 10 * fly, 0, 0),
		LeftKnee = A(-20 - 10 * fly, 0, 0),
	}
end

-- Appeso a una parete con il rampino
function Poses.Human.Hang(t, ctx)
	local side = ctx.HangSide or 1
	local sway = sin(t * 2) * 3
	if side > 0 then
		return {
			RightShoulder = A(165, 0, 10),
			RightElbow = A(15, 0, 0),
			LeftShoulder = A(20, 0, -20),
			Waist = A(sway, 0, 0),
			RightKnee = A(-25, 0, 0),
			LeftKnee = A(-40, 0, 0),
		}
	end
	return {
		LeftShoulder = A(165, 0, -10),
		LeftElbow = A(15, 0, 0),
		RightShoulder = A(20, 0, 20),
		Waist = A(sway, 0, 0),
		RightKnee = A(-40, 0, 0),
		LeftKnee = A(-25, 0, 0),
	}
end

-- Afferrato da un gigante: si dimena
function Poses.Human.Struggle(t, _ctx)
	local s = sin(t * 16)
	local c = cos(t * 13)
	return {
		RightShoulder = A(100 + s * 30, 0, 40),
		LeftShoulder = A(100 - s * 30, 0, -40),
		RightElbow = A(40 + c * 20, 0, 0),
		LeftElbow = A(40 - c * 20, 0, 0),
		RightHip = A(30 * s, 0, 0),
		LeftHip = A(-30 * s, 0, 0),
		RightKnee = A(-40 - 20 * c, 0, 0),
		LeftKnee = A(-40 + 20 * c, 0, 0),
		Neck = A(10 * c, 20 * s, 0),
	}
end

-- PNG fermi: respiro e sguardo che si muove
function Poses.Human.Idle(t, ctx)
	local seed = ctx.Seed or 0
	return {
		Waist = A(sin(t * 1.6 + seed) * 1.6, sin(t * 0.3 + seed) * 4, 0),
		Neck = A(sin(t * 0.5 + seed) * 4, (ctx.LookYaw or sin(t * 0.35 + seed) * 18), 0),
		RightShoulder = A(sin(t * 1.6 + seed) * 2, 0, 3),
		LeftShoulder = A(sin(t * 1.6 + seed) * 2, 0, -3),
	}
end

-- Mantello che svolazza (articolazione "Cloak")
function Poses.Human.Cloak(t, ctx)
	local speed = ctx.Speed or 0
	local lift = math.clamp(speed / 120, 0, 1)
	local flutter = sin(t * (6 + lift * 14)) * (3 + lift * 9)
	return {
		Cloak = A(10 + lift * 55 + flutter, 0, sin(t * 4) * 2 * lift),
	}
end

-- Seduto (barche e panche): gambe piegate, mani sulle ginocchia
function Poses.Human.Sit(t, _ctx)
	local sway = sin(t * 1.2) * 1.5
	return {
		Root = A(0, 0, sway * 0.3),
		Waist = A(-4, 0, 0),
		RightHip = A(88, 0, 6),
		LeftHip = A(88, 0, -6),
		RightKnee = A(-86, 0, 0),
		LeftKnee = A(-86, 0, 0),
		RightShoulder = A(28, 0, 10),
		LeftShoulder = A(28, 0, -10),
		RightElbow = A(30, 0, 0),
		LeftElbow = A(30, 0, 0),
		Neck = A(sway * 0.5, 0, 0),
	}
end

-- A cavallo: gambe aperte ai lati della sella, redini in mano, busto che segue il galoppo
-- ctx.RideGallop (0..1) e ctx.RidePhase (ciclo del galoppo)
function Poses.Human.Ride(_t, ctx)
	local gallop = ctx.RideGallop or 0
	local cycle = (ctx.RidePhase or 0) * math.pi * 2
	local bounce = abs(sin(cycle)) * gallop
	local lean = 6 + 14 * gallop
	return {
		Root = TA(0, bounce * 0.35, 0, -lean + sin(cycle) * 4 * gallop, 0, 0),
		Waist = A(-4 - 4 * gallop, 0, 0),
		Neck = A(lean * 0.6, 0, 0),
		RightHip = A(62, 0, 30),
		LeftHip = A(62, 0, -30),
		RightKnee = A(-78, 0, 0),
		LeftKnee = A(-78, 0, 0),
		RightShoulder = A(42 + 10 * gallop + sin(cycle) * 6 * gallop, 0, 8),
		LeftShoulder = A(42 + 10 * gallop + sin(cycle) * 6 * gallop, 0, -8),
		RightElbow = A(48, 0, 0),
		LeftElbow = A(48, 0, 0),
		RightWrist = A(-10, 0, 0),
		LeftWrist = A(-10, 0, 0),
	}
end

local H = Poses.Human
H.Clips = {}

local function addHuman(def)
	H.Clips[def.Name] = def
end

addHuman(clip("Slash1", {
	K(0, {}),
	K(0.07, { RightShoulder = A(150, 0, 45), RightElbow = A(40, 0, 0), Waist = A(0, -25, 0), LeftShoulder = A(35, 0, -20) }, "QuadOut"),
	K(0.16, { RightShoulder = A(35, 0, -45), RightElbow = A(8, 0, 0), Waist = A(-8, 30, 0), LeftShoulder = A(20, 0, -30) }, "ExpoOut"),
	K(0.3, { RightShoulder = A(25, 0, -25), RightElbow = A(20, 0, 0), Waist = A(-4, 15, 0), LeftShoulder = A(20, 0, -20) }, "QuadOut"),
}, { FadeOut = 0.18 }))

addHuman(clip("Slash2", {
	K(0, {}),
	K(0.07, { LeftShoulder = A(150, 0, -45), LeftElbow = A(40, 0, 0), Waist = A(0, 25, 0), RightShoulder = A(35, 0, 20) }, "QuadOut"),
	K(0.16, { LeftShoulder = A(35, 0, 45), LeftElbow = A(8, 0, 0), Waist = A(-8, -30, 0), RightShoulder = A(20, 0, 30) }, "ExpoOut"),
	K(0.3, { LeftShoulder = A(25, 0, 25), LeftElbow = A(20, 0, 0), Waist = A(-4, -15, 0), RightShoulder = A(20, 0, 20) }, "QuadOut"),
}, { FadeOut = 0.18 }))

addHuman(clip("Slash3", {
	K(0, {}),
	K(0.08, { RightShoulder = A(165, 0, 30), LeftShoulder = A(165, 0, -30), RightElbow = A(30, 0, 0), LeftElbow = A(30, 0, 0), Waist = A(12, 0, 0) }, "QuadOut"),
	K(0.18, { RightShoulder = A(30, 0, -55), LeftShoulder = A(30, 0, 55), RightElbow = A(5, 0, 0), LeftElbow = A(5, 0, 0), Waist = A(-18, 0, 0) }, "ExpoOut"),
	K(0.34, { RightShoulder = A(25, 0, -30), LeftShoulder = A(25, 0, 30), Waist = A(-8, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.2 }))

do
	local arms = { RightShoulder = A(90, 0, 80), LeftShoulder = A(90, 0, -80), RightElbow = A(5, 0, 0), LeftElbow = A(5, 0, 0) }
	addHuman(clip("Slash4", spinKeys(0.38, 1, "Y", "Root", arms, 4), { FadeOut = 0.2, FadeIn = 0.03 }))
	addHuman(clip("SpinSlash", spinKeys(0.55, 2, "Y", "Root", arms, 3), { FadeOut = 0.2, FadeIn = 0.03, Priority = 3 }))
	local drill = {
		Root = A(-80, 0, 0),
		RightShoulder = A(20, 0, 95),
		LeftShoulder = A(20, 0, -95),
		RightHip = A(-15, 0, 5),
		LeftHip = A(-15, 0, -5),
		RightKnee = A(-20, 0, 0),
		LeftKnee = A(-20, 0, 0),
	}
	addHuman(clip("Tornado", spinKeys(1.4, 6, "Z", "Root", drill, 3), { FadeOut = 0.25, FadeIn = 0.08, Priority = 3 }))
	addHuman(clip("Dodge", spinKeys(0.34, 1, "Z", "Root", { RightKnee = A(-70, 0, 0), LeftKnee = A(-70, 0, 0), RightHip = A(50, 0, 0), LeftHip = A(50, 0, 0) }, 4), { FadeOut = 0.12, FadeIn = 0.02, Priority = 4 }))
	local tuck = {
		RightHip = A(100, 0, 0),
		LeftHip = A(100, 0, 0),
		RightKnee = A(-120, 0, 0),
		LeftKnee = A(-120, 0, 0),
		RightShoulder = A(60, 0, 10),
		LeftShoulder = A(60, 0, -10),
		Neck = A(-30, 0, 0),
	}
	addHuman(clip("LandRoll", spinKeys(0.5, 1, "X", "Root", tuck, 4), { FadeOut = 0.15, FadeIn = 0.02, Priority = 4 }))
end

addHuman(clip("Lunge", {
	K(0, {}),
	K(0.08, { Waist = A(-25, 0, 0), RightShoulder = A(-30, 0, 25), LeftShoulder = A(-30, 0, -25), RightHip = A(40, 0, 0), RightKnee = A(-60, 0, 0), LeftKnee = A(-30, 0, 0) }, "QuadOut"),
	K(0.16, { Root = A(-25, 0, 0), RightShoulder = A(85, 0, 10), LeftShoulder = A(85, 0, -10), RightElbow = A(0, 0, 0), LeftElbow = A(0, 0, 0), RightHip = A(-30, 0, 0), LeftHip = A(-15, 0, 0) }, "ExpoOut"),
	K(0.45, { Root = A(-15, 0, 0), RightShoulder = A(70, 0, 15), LeftShoulder = A(70, 0, -15), RightHip = A(-20, 0, 0), LeftHip = A(-10, 0, 0) }, "QuadOut"),
}, { Priority = 3 }))

addHuman(clip("BladeDance", {
	K(0, {}),
	K(0.12, { Root = A(-40, 0, 0), RightShoulder = A(150, 0, 40), LeftShoulder = A(150, 0, -40) }, "QuadOut"),
	K(0.26, { Root = A(-40, 120, 0), RightShoulder = A(30, 0, -50), LeftShoulder = A(30, 0, 50) }, "ExpoOut"),
	K(0.4, { Root = A(-40, 240, 0), RightShoulder = A(150, 0, 40), LeftShoulder = A(150, 0, -40) }, "Linear"),
	K(0.54, { Root = A(-40, 359, 0), RightShoulder = A(30, 0, -50), LeftShoulder = A(30, 0, 50) }, "ExpoOut"),
	K(0.68, { Root = A(-40, 120, 0), RightShoulder = A(90, 0, 80), LeftShoulder = A(90, 0, -80) }, "Linear"),
	K(0.82, { Root = A(-40, 240, 0), RightShoulder = A(150, 0, 40), LeftShoulder = A(150, 0, -40) }, "Linear"),
	K(0.96, { Root = A(-40, 359, 0), RightShoulder = A(30, 0, -50), LeftShoulder = A(30, 0, 50) }, "ExpoOut"),
	K(1.15, { Root = A(-60, 0, 0), RightShoulder = A(165, 0, 20), LeftShoulder = A(165, 0, -20), Waist = A(15, 0, 0) }, "QuadOut"),
	K(1.4, { Root = A(-20, 0, 0), RightShoulder = A(20, 0, -40), LeftShoulder = A(20, 0, 40), Waist = A(-25, 0, 0) }, "ExpoOut"),
}, { Priority = 3, FadeOut = 0.25 }))

addHuman(clip("Reload", {
	K(0, {}),
	K(0.2, { RightShoulder = A(-15, 0, 18), LeftShoulder = A(-15, 0, -18), RightElbow = A(75, 0, 0), LeftElbow = A(75, 0, 0), Waist = A(-10, 0, 0) }, "QuadOut"),
	K(0.45, { RightShoulder = A(-20, 0, 22), LeftShoulder = A(-20, 0, -22), RightElbow = A(85, 0, 0), LeftElbow = A(85, 0, 0), Waist = A(-12, 0, 0) }, "Linear"),
	K(0.7, { RightShoulder = A(45, 0, 25), LeftShoulder = A(45, 0, -25), RightElbow = A(10, 0, 0), LeftElbow = A(10, 0, 0) }, "BackOut"),
}, { Priority = 2 }))

addHuman(clip("FireSpear", {
	K(0, {}),
	K(0.08, { RightShoulder = A(95, 0, 0), RightElbow = A(0, 0, 0), Waist = A(0, -15, 0) }, "QuadOut"),
	K(0.16, { RightShoulder = A(115, 0, 5), RightElbow = A(15, 0, 0), Waist = A(8, -10, 0) }, "ExpoOut"),
	K(0.4, { RightShoulder = A(70, 0, 5), RightElbow = A(20, 0, 0) }, "QuadOut"),
}, { Priority = 3 }))

addHuman(clip("FireGun", {
	K(0, {}),
	K(0.05, { RightShoulder = A(88, 0, -4), LeftShoulder = A(88, 0, 4), RightElbow = A(0, 0, 0), LeftElbow = A(0, 0, 0) }, "QuadOut"),
	K(0.1, { RightShoulder = A(105, 0, -4), LeftShoulder = A(105, 0, 4), RightElbow = A(15, 0, 0), LeftElbow = A(15, 0, 0) }, "ExpoOut"),
	K(0.28, { RightShoulder = A(80, 0, -4), LeftShoulder = A(80, 0, 4) }, "QuadOut"),
}, { Priority = 3 }))

addHuman(clip("Flare", {
	K(0, {}),
	K(0.12, { RightShoulder = A(165, 0, 10), RightElbow = A(0, 0, 0), Neck = A(20, 0, 0) }, "QuadOut"),
	K(0.4, { RightShoulder = A(160, 0, 10), RightElbow = A(10, 0, 0), Neck = A(15, 0, 0) }, "Linear"),
}, { Priority = 3 }))

addHuman(clip("Inject", {
	K(0, {}),
	K(0.35, { RightShoulder = A(110, 0, -40), RightElbow = A(110, 0, 0), Neck = A(0, 0, 25), Waist = A(-5, 0, 0) }, "QuadOut"),
	K(0.6, { RightShoulder = A(115, 0, -45), RightElbow = A(115, 0, 0), Neck = A(10, 0, 30), Waist = A(5, 0, 0) }, "ExpoOut"),
	K(0.8, { Waist = A(25, 0, 0), Neck = A(35, 0, 0), RightShoulder = A(40, 0, 60), LeftShoulder = A(40, 0, -60) }, "ExpoOut"),
	K(1.0, { Waist = A(-30, 0, 5), Neck = A(-20, 0, 0), RightShoulder = A(10, 0, 20), LeftShoulder = A(10, 0, -20), RightKnee = A(-50, 0, 0), LeftKnee = A(-50, 0, 0), RightHip = A(40, 0, 0), LeftHip = A(40, 0, 0) }, "QuadOut"),
	K(1.2, { Waist = A(-25, 0, -6), Neck = A(-25, 0, 0), RightKnee = A(-55, 0, 0), LeftKnee = A(-55, 0, 0), RightHip = A(45, 0, 0), LeftHip = A(45, 0, 0) }, "Linear"),
	K(1.6, { Waist = A(0, 0, 0), Neck = A(10, 0, 0), RightShoulder = A(30, 0, 10) }, "QuadOut"),
}, { Priority = 4, FadeOut = 0.3 }))

addHuman(clip("Transform", {
	K(0, {}),
	K(0.25, { RightShoulder = A(135, 0, -25), RightElbow = A(125, 0, 0), Neck = A(-10, 0, 0), Waist = A(-10, 0, 0) }, "QuadOut"),
	K(0.5, { RightShoulder = A(140, 0, -25), RightElbow = A(130, 0, 0), Neck = A(-15, 0, 0) }, "Linear"),
	K(0.8, { RightShoulder = A(60, 0, 80), LeftShoulder = A(60, 0, -80), Neck = A(30, 0, 0), Waist = A(20, 0, 0) }, "ExpoOut"),
}, { Priority = 4, FadeOut = 0.2 }))

addHuman(clip("Salute", {
	K(0, {}),
	-- saluto militare: mano destra alla fronte, braccio sinistro lungo il fianco
	K(0.25, { RightShoulder = A(45, 0, 75), RightElbow = A(125, 0, 0), LeftShoulder = A(0, 0, -4), LeftElbow = A(5, 0, 0), Neck = A(-4, 0, 0) }, "BackOut"),
	K(1.4, { RightShoulder = A(45, 0, 75), RightElbow = A(125, 0, 0), LeftShoulder = A(0, 0, -4), LeftElbow = A(5, 0, 0), Neck = A(-4, 0, 0) }, "Linear"),
}, { Priority = 3, FadeOut = 0.35 }))

addHuman(clip("HitReact", {
	K(0, {}),
	K(0.06, { Waist = A(18, 0, 6), Neck = A(14, 0, 0), RightShoulder = A(30, 0, 30), LeftShoulder = A(30, 0, -30) }, "ExpoOut"),
	K(0.25, { Waist = A(4, 0, 0) }, "QuadOut"),
}, { Priority = 5, FadeOut = 0.12 }))

addHuman(clip("Awaken", {
	K(0, {}),
	K(0.3, { Waist = A(-25, 0, 0), RightShoulder = A(-20, 0, 40), LeftShoulder = A(-20, 0, -40), RightKnee = A(-40, 0, 0), LeftKnee = A(-40, 0, 0), RightHip = A(30, 0, 0), LeftHip = A(30, 0, 0) }, "QuadOut"),
	K(0.7, { Waist = A(15, 0, 0), Neck = A(25, 0, 0), RightShoulder = A(30, 0, 100), LeftShoulder = A(30, 0, -100) }, "ExpoOut"),
	K(1.1, { Waist = A(5, 0, 0), Neck = A(10, 0, 0), RightShoulder = A(25, 0, 30), LeftShoulder = A(25, 0, -30) }, "QuadOut"),
}, { Priority = 4 }))

addHuman(clip("TitanPunchSmall", {
	K(0, {}),
	K(0.15, { RightShoulder = A(20, 0, 30), RightElbow = A(120, 0, 0), Waist = A(0, -25, 0) }, "QuadOut"),
	K(0.3, { RightShoulder = A(95, 0, -5), RightElbow = A(0, 0, 0), Waist = A(-10, 30, 0) }, "ExpoOut"),
	K(0.6, { RightShoulder = A(40, 0, 10), RightElbow = A(30, 0, 0) }, "QuadOut"),
}, { Priority = 3 }))

addHuman(clip("TitanKickSmall", {
	K(0, {}),
	K(0.15, { RightHip = A(30, 0, 30), RightKnee = A(-80, 0, 0), Waist = A(0, 20, 0) }, "QuadOut"),
	K(0.3, { RightHip = A(85, 0, 40), RightKnee = A(-5, 0, 0), Waist = A(10, -30, 0), RightShoulder = A(20, 0, 60), LeftShoulder = A(20, 0, -60) }, "ExpoOut"),
	K(0.6, { RightHip = A(10, 0, 0), RightKnee = A(-15, 0, 0) }, "QuadOut"),
}, { Priority = 3 }))

addHuman(clip("TitanRoarSmall", {
	K(0, {}),
	K(0.3, { Neck = A(35, 0, 0), Waist = A(15, 0, 0), RightShoulder = A(30, 0, 75), LeftShoulder = A(30, 0, -75), RightElbow = A(30, 0, 0), LeftElbow = A(30, 0, 0) }, "ExpoOut"),
	K(1.0, { Neck = A(30, 0, 0), Waist = A(12, 0, 0), RightShoulder = A(30, 0, 75), LeftShoulder = A(30, 0, -75) }, "Linear"),
}, { Priority = 3 }))

addHuman(clip("TitanThrowSmall", {
	K(0, {}),
	K(0.3, { RightShoulder = A(170, 0, 20), RightElbow = A(60, 0, 0), Waist = A(15, -30, 0) }, "QuadOut"),
	K(0.45, { RightShoulder = A(50, 0, -10), RightElbow = A(5, 0, 0), Waist = A(-20, 25, 0) }, "ExpoOut"),
	K(0.8, { RightShoulder = A(30, 0, 0) }, "QuadOut"),
}, { Priority = 3 }))

addHuman(clip("TitanSlamSmall", {
	K(0, {}),
	K(0.3, { RightShoulder = A(170, 0, 10), LeftShoulder = A(170, 0, -10), Waist = A(15, 0, 0) }, "QuadOut"),
	K(0.45, { RightShoulder = A(50, 0, 5), LeftShoulder = A(50, 0, -5), Waist = A(-35, 0, 0) }, "ExpoOut"),
	K(0.8, { Waist = A(-10, 0, 0) }, "QuadOut"),
}, { Priority = 3 }))

-- MOSSE DEL GIGANTE DELLA FURIA (forma di gigante del giocatore) ------------------------------
-- Gancio destro e sinistro (attacco base, si alternano)
addHuman(clip("FuriaHookR", {
	K(0, {}),
	K(0.12, { RightShoulder = A(30, 0, 45), RightElbow = A(100, 0, 0), Waist = A(-5, -30, 0), LeftShoulder = A(45, 0, -25), LeftElbow = A(100, 0, 0) }, "QuadOut"),
	K(0.24, { RightShoulder = A(90, 0, -15), RightElbow = A(15, 0, 0), Waist = A(-12, 35, 0), Root = A(-6, 10, 0), LeftShoulder = A(40, 0, -20), LeftElbow = A(95, 0, 0), RightHip = A(-10, 0, 0), LeftHip = A(25, 0, 0), LeftKnee = A(-30, 0, 0) }, "ExpoOut"),
	K(0.55, { RightShoulder = A(35, 0, 10), RightElbow = A(40, 0, 0), LeftShoulder = A(35, 0, -10), LeftElbow = A(60, 0, 0), Waist = A(-5, 5, 0) }, "QuadOut"),
}, { Priority = 3, FadeOut = 0.2 }))
addHuman(clip("FuriaHookL", {
	K(0, {}),
	K(0.12, { LeftShoulder = A(30, 0, -45), LeftElbow = A(100, 0, 0), Waist = A(-5, 30, 0), RightShoulder = A(45, 0, 25), RightElbow = A(100, 0, 0) }, "QuadOut"),
	K(0.24, { LeftShoulder = A(90, 0, 15), LeftElbow = A(15, 0, 0), Waist = A(-12, -35, 0), Root = A(-6, -10, 0), RightShoulder = A(40, 0, 20), RightElbow = A(95, 0, 0), LeftHip = A(-10, 0, 0), RightHip = A(25, 0, 0), RightKnee = A(-30, 0, 0) }, "ExpoOut"),
	K(0.55, { LeftShoulder = A(35, 0, -10), LeftElbow = A(40, 0, 0), RightShoulder = A(35, 0, 10), RightElbow = A(60, 0, 0), Waist = A(-5, -5, 0) }, "QuadOut"),
}, { Priority = 3, FadeOut = 0.2 }))

-- Z - Pugno Indurito: lunga carica all'indietro, poi un diretto devastante con affondo
addHuman(clip("FuriaHardPunch", {
	K(0, {}),
	K(0.3, { RightShoulder = A(-30, 0, 30), RightElbow = A(115, 0, 0), RightWrist = A(-20, 0, 0), Waist = A(5, -45, 0), Root = A(5, -20, 0), LeftShoulder = A(60, 0, -30), LeftElbow = A(40, 0, 0), RightHip = A(-15, 0, 0), LeftHip = A(35, 0, 0), LeftKnee = A(-45, 0, 0), RightKnee = A(-25, 0, 0) }, "QuadOut"),
	K(0.42, { RightShoulder = A(95, 0, 0), RightElbow = A(0, 0, 0), RightWrist = A(0, 0, 0), Waist = A(-18, 40, 0), Root = A(-20, 15, 0), LeftShoulder = A(-20, 0, -40), LeftElbow = A(60, 0, 0), RightHip = A(-30, 0, 0), LeftHip = A(50, 0, 0), LeftKnee = A(-60, 0, 0), RightKnee = A(-10, 0, 0) }, "ExpoOut"),
	K(0.65, { RightShoulder = A(90, 0, 0), RightElbow = A(5, 0, 0), Waist = A(-15, 35, 0), Root = A(-16, 12, 0), LeftHip = A(45, 0, 0), LeftKnee = A(-55, 0, 0) }, "Linear"),
	K(1.0, { RightShoulder = A(30, 0, 10), RightElbow = A(40, 0, 0), Waist = A(-5, 5, 0) }, "QuadOut"),
}, { Priority = 4, FadeOut = 0.25 }))

-- X - Calcio Rotante: giro completo su se stesso con la gamba tesa
addHuman(clip("FuriaSpinKick", spinKeys(0.6, 1, "Y", "Root", {
	RightHip = A(80, 0, 45),
	RightKnee = A(-5, 0, 0),
	LeftKnee = A(-25, 0, 0),
	LeftHip = A(10, 0, 0),
	RightShoulder = A(25, 0, 70),
	LeftShoulder = A(25, 0, -70),
	Waist = A(5, 0, 0),
}, 4), { Priority = 4, FadeIn = 0.04, FadeOut = 0.2 }))

-- C - Ruggito della Furia: si raccoglie, poi spalanca braccia e petto e urla al cielo
addHuman(clip("FuriaRoar", {
	K(0, {}),
	K(0.25, { Waist = A(-25, 0, 0), Neck = A(-20, 0, 0), RightShoulder = A(-20, 0, 20), LeftShoulder = A(-20, 0, -20), RightElbow = A(90, 0, 0), LeftElbow = A(90, 0, 0), RightKnee = A(-35, 0, 0), LeftKnee = A(-35, 0, 0), RightHip = A(25, 0, 0), LeftHip = A(25, 0, 0) }, "QuadOut"),
	K(0.45, { Waist = A(18, 0, 0), Neck = A(35, 0, 0), RightShoulder = A(35, 0, 95), LeftShoulder = A(35, 0, -95), RightElbow = A(25, 0, 0), LeftElbow = A(25, 0, 0), RightWrist = A(-30, 0, 0), LeftWrist = A(-30, 0, 0) }, "ExpoOut"),
	K(1.4, { Waist = A(15, 0, 0), Neck = A(32, 0, 0), RightShoulder = A(35, 0, 90), LeftShoulder = A(35, 0, -90), RightElbow = A(30, 0, 0), LeftElbow = A(30, 0, 0) }, "Linear"),
	K(1.8, {}, "QuadOut"),
}, { Priority = 4, FadeOut = 0.3 }))

-- V - Visione del Futuro: mani al volto, poi si apre e gli occhi si accendono
addHuman(clip("FuriaFocus", {
	K(0, {}),
	K(0.3, { RightShoulder = A(120, 0, -20), RightElbow = A(110, 0, 0), LeftShoulder = A(120, 0, 20), LeftElbow = A(110, 0, 0), Neck = A(-15, 0, 0), Waist = A(-10, 0, 0) }, "QuadOut"),
	K(0.7, { RightShoulder = A(10, 0, 60), LeftShoulder = A(10, 0, -60), RightElbow = A(20, 0, 0), LeftElbow = A(20, 0, 0), Neck = A(20, 0, 0), Waist = A(10, 0, 0) }, "ExpoOut"),
	K(1.1, {}, "QuadOut"),
}, { Priority = 4, FadeOut = 0.25 }))

-- =====================================================================================
-- GIGANTI (Absolute: la posa è il Transform completo)
-- =====================================================================================

Poses.Titan = {}
local T = Poses.Titan

-- Camminata/corsa: ctx.Phase avanza con la velocità, ctx.Run 0..1 (anomali che corrono)
function T.Locomotion(t, ctx)
	local p = ctx.Phase or 0
	local move = ctx.Move or 0 -- 0 fermo, 1 in movimento
	local run = ctx.Run or 0
	local creep = ctx.Creep or 0
	local s = sin(p)
	local hipAmp = (26 + run * 24) * move
	local kneeR = -(8 + (22 + run * 30) * math.max(0, sin(p + 1.4))) * move - 3
	local kneeL = -(8 + (22 + run * 30) * math.max(0, sin(p + 1.4 + math.pi))) * move - 3
	local armAmp = (22 + run * 50) * move
	local breathe = sin(t * 1.7 + (ctx.Seed or 0)) * 2
	local bob = -abs(s) * 0.018 * move
	local lean = -(4 + run * 26) * move
	return {
		Root = TA(0, bob, 0, lean, 0, s * (3 + run * 4) * move),
		-- i giganti "curvi" camminano piegati in avanti con la testa sollevata
		Waist = A(breathe + creep * 8 - (if ctx.Hunch then 22 else 0), s * 7 * move, 0),
		Neck = A(-6 * creep + breathe * 0.5 + (if ctx.Hunch then 16 else 0), 0, (ctx.HeadTilt or 0)),
		Jaw = A(4 + (ctx.JawIdle or 0) + abs(sin(t * 0.8)) * 6, 0, 0),
		RightHip = A(s * hipAmp, 0, 2),
		LeftHip = A(-s * hipAmp, 0, -2),
		RightKnee = A(kneeR, 0, 0),
		LeftKnee = A(kneeL, 0, 0),
		RightAnkle = A(sin(p + 0.6) * 10 * move, 0, 0),
		LeftAnkle = A(-sin(p + 0.6) * 10 * move, 0, 0),
		RightShoulder = A(-s * armAmp + run * 25 + breathe, 0, 8 + run * 30 * abs(s)),
		LeftShoulder = A(s * armAmp + run * 25 + breathe, 0, -8 - run * 30 * abs(cos(p))),
		RightElbow = A(12 + run * 40, 0, 0),
		LeftElbow = A(12 + run * 40, 0, 0),
	}
end

-- Andatura a quattro zampe (Carro, Strisciante)
function T.Crawl(t, ctx)
	local p = ctx.Phase or 0
	local move = ctx.Move or 0
	local s = sin(p)
	local c = cos(p)
	return {
		Root = TA(0, -0.28, 0, -72, 0, s * 3 * move),
		Waist = A(-10, s * 6 * move, 0),
		Neck = A(65, 0, 0),
		Jaw = A(10 + abs(sin(t)) * 10, 0, 0),
		RightShoulder = A(95 + s * 30 * move, 0, 10),
		LeftShoulder = A(95 - s * 30 * move, 0, -10),
		RightElbow = A(-10 + math.max(0, c) * 30 * move, 0, 0),
		LeftElbow = A(-10 + math.max(0, -c) * 30 * move, 0, 0),
		RightHip = A(80 - s * 25 * move, 0, 8),
		LeftHip = A(80 + s * 25 * move, 0, -8),
		RightKnee = A(-100 + math.max(0, -c) * 30 * move, 0, 0),
		LeftKnee = A(-100 + math.max(0, c) * 30 * move, 0, 0),
	}
end

-- Sagoma di legno: dondola un po' quando colpita
function T.Dummy(t, ctx)
	local wobble = (ctx.Wobble or 0)
	return {
		Root = A(sin(t * 14) * wobble * 6, 0, cos(t * 11) * wobble * 4),
	}
end

T.Clips = {}
local function addTitan(def)
	T.Clips[def.Name] = def
end

-- Gli attacchi durano Windup + Recover (vedi Titans.Attacks): i tempi coincidono col server
addTitan(clip("Swipe", {
	K(0, {}),
	K(0.6, { RightShoulder = A(55, 0, 85), RightElbow = A(20, 0, 0), Waist = A(-5, -35, 0), Neck = A(-5, -10, 0) }, "QuadOut"),
	K(0.78, { RightShoulder = A(65, 0, -35), RightElbow = A(5, 0, 0), Waist = A(-12, 40, 0) }, "ExpoOut"),
	K(1.2, { RightShoulder = A(30, 0, -10), Waist = A(-5, 15, 0) }, "QuadOut"),
}, { FadeOut = 0.3 }))

addTitan(clip("Grab", {
	K(0, {}),
	K(0.3, { RightShoulder = A(60, 0, 25), RightElbow = A(40, 0, 0), Waist = A(-15, -10, 0), Neck = A(-10, 0, 0), Jaw = A(20, 0, 0) }, "QuadOut"),
	K(0.55, { RightShoulder = A(88, 0, 5), RightElbow = A(8, 0, 0), Waist = A(-28, 5, 0), Neck = A(-15, 0, 0), Jaw = A(25, 0, 0) }, "ExpoOut"),
	K(0.8, { RightShoulder = A(80, 0, 0), RightElbow = A(20, 0, 0), Waist = A(-20, 0, 0) }, "QuadOut"),
	K(1.25, { RightShoulder = A(30, 0, 0), RightElbow = A(15, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.3 }))

-- Tiene il giocatore davanti alla faccia, poi lo divora
addTitan(clip("Hold", {
	K(0, { RightShoulder = A(80, 0, 0), RightElbow = A(20, 0, 0), Waist = A(-20, 0, 0) }),
	K(0.4, { RightShoulder = A(75, 0, -25), RightElbow = A(70, 0, 0), Neck = A(-12, 0, 0), Jaw = A(15, 0, 0) }, "QuadOut"),
	K(2.0, { RightShoulder = A(80, 0, -28), RightElbow = A(85, 0, 0), Neck = A(-15, 8, 6), Jaw = A(30, 0, 0) }, "SineInOut"),
	K(2.3, { RightShoulder = A(95, 0, -30), RightElbow = A(100, 0, 0), Neck = A(-20, 0, 0), Jaw = A(45, 0, 0) }, "QuadIn"),
	K(2.6, { RightShoulder = A(95, 0, -30), RightElbow = A(105, 0, 0), Neck = A(-8, 0, 0), Jaw = A(0, 0, 0) }, "ExpoOut"),
}, { FadeOut = 0.4, Hold = 0.3 }))

addTitan(clip("Stomp", {
	K(0, {}),
	K(0.55, { RightHip = A(75, 0, 4), RightKnee = A(-75, 0, 0), Waist = A(8, 0, 0), Root = TA(0, 0.02, 0, 6, 0, 0), RightShoulder = A(20, 0, 30), LeftShoulder = A(20, 0, -30) }, "QuadOut"),
	K(0.75, { RightHip = A(10, 0, 4), RightKnee = A(-8, 0, 0), Waist = A(-12, 0, 0), Root = TA(0, -0.03, 0, -8, 0, 0) }, "ExpoOut"),
	K(1.35, { Waist = A(-4, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.3 }))

addTitan(clip("Bite", {
	K(0, {}),
	K(0.3, { Waist = A(-30, 0, 0), Neck = A(-25, 0, 0), Jaw = A(45, 0, 0), RightShoulder = A(30, 0, 40), LeftShoulder = A(30, 0, -40) }, "QuadOut"),
	K(0.45, { Waist = A(-42, 0, 0), Neck = A(-30, 0, 0), Jaw = A(0, 0, 0) }, "ExpoOut"),
	K(1.05, { Waist = A(-10, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.3 }))

addTitan(clip("NapeSwat", {
	K(0, {}),
	K(0.3, { RightShoulder = A(170, 0, -15), RightElbow = A(95, 0, 0), Neck = A(-20, 0, 0), Waist = A(-10, 15, 0) }, "QuadOut"),
	K(0.45, { RightShoulder = A(175, 0, -35), RightElbow = A(130, 0, 0), Neck = A(-25, 0, 0) }, "ExpoOut"),
	K(0.95, { RightShoulder = A(40, 0, 0), RightElbow = A(20, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.3 }))

addTitan(clip("Leap", {
	K(0, {}),
	K(0.45, { Root = TA(0, -0.12, 0, -20, 0, 0), RightHip = A(70, 0, 0), LeftHip = A(70, 0, 0), RightKnee = A(-100, 0, 0), LeftKnee = A(-100, 0, 0), Waist = A(-25, 0, 0), RightShoulder = A(-40, 0, 20), LeftShoulder = A(-40, 0, -20) }, "QuadOut"),
	K(0.7, { Root = TA(0, 0, 0, -35, 0, 0), RightHip = A(-20, 0, 0), LeftHip = A(-30, 0, 0), RightKnee = A(-10, 0, 0), LeftKnee = A(-20, 0, 0), RightShoulder = A(120, 0, 30), LeftShoulder = A(120, 0, -30), Jaw = A(40, 0, 0) }, "ExpoOut"),
	K(1.35, { Root = TA(0, 0, 0, -20, 0, 0), RightHip = A(40, 0, 0), LeftHip = A(30, 0, 0), RightShoulder = A(100, 0, 40), LeftShoulder = A(100, 0, -40), Jaw = A(45, 0, 0) }, "Linear"),
	K(1.55, { Root = TA(0, -0.1, 0, -25, 0, 0), RightHip = A(70, 0, 0), LeftHip = A(70, 0, 0), RightKnee = A(-90, 0, 0), LeftKnee = A(-90, 0, 0), RightShoulder = A(40, 0, 50), LeftShoulder = A(40, 0, -50) }, "ExpoOut"),
	K(2.25, { Root = TA(0, 0, 0, -5, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.35 }))

addTitan(clip("Kick", {
	K(0, {}),
	K(0.4, { RightHip = A(30, 0, 25), RightKnee = A(-85, 0, 0), Waist = A(0, 25, 0), Root = A(0, 20, 0), RightShoulder = A(20, 0, 50), LeftShoulder = A(20, 0, -50) }, "QuadOut"),
	K(0.58, { RightHip = A(90, 0, 45), RightKnee = A(-4, 0, 0), Waist = A(12, -35, 0), Root = A(0, -50, 0) }, "ExpoOut"),
	K(1.05, { RightHip = A(10, 0, 5), RightKnee = A(-10, 0, 0), Root = A(0, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.3 }))

-- Calcio dei filmati con le mani aggrappate al Muro (ArmReach): solo la gamba e un po' il busto,
-- senza girare il corpo, così le mani restano ferme sul bordo. Il colpo arriva a 0.62 s.
addTitan(clip("WallKick", {
	K(0, {}),
	K(0.45, { RightHip = A(-30, 0, 6), RightKnee = A(-75, 0, 0), RightAnkle = A(-15, 0, 0), Waist = A(6, 0, 0), Root = A(4, 0, 0), LeftKnee = A(-10, 0, 0) }, "QuadOut"),
	K(0.62, { RightHip = A(64, 0, 4), RightKnee = A(-6, 0, 0), RightAnkle = A(20, 0, 0), Waist = A(-10, 0, 0), Root = A(-6, 0, 0), LeftKnee = A(-14, 0, 0) }, "ExpoOut"),
	K(1.4, { RightHip = A(12, 0, 2), RightKnee = A(-14, 0, 0), LeftKnee = A(-4, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.35 }))

addTitan(clip("Punch", {
	K(0, {}),
	K(0.4, { RightShoulder = A(25, 0, 35), RightElbow = A(125, 0, 0), Waist = A(0, -30, 0), LeftShoulder = A(60, 0, -20), LeftElbow = A(80, 0, 0) }, "QuadOut"),
	K(0.55, { RightShoulder = A(95, 0, -5), RightElbow = A(0, 0, 0), Waist = A(-12, 35, 0) }, "ExpoOut"),
	K(1.0, { RightShoulder = A(40, 0, 5), RightElbow = A(20, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.3 }))

addTitan(clip("Roar", {
	K(0, {}),
	K(0.5, { Neck = A(38, 0, 0), Jaw = A(48, 0, 0), Waist = A(16, 0, 0), RightShoulder = A(25, 0, 75), LeftShoulder = A(25, 0, -75), RightElbow = A(30, 0, 0), LeftElbow = A(30, 0, 0) }, "ExpoOut"),
	K(1.1, { Neck = A(35, 6, 0), Jaw = A(50, 0, 0), Waist = A(14, 0, 0), RightShoulder = A(25, 0, 72), LeftShoulder = A(25, 0, -72) }, "SineInOut"),
	K(1.4, { Neck = A(5, 0, 0), Jaw = A(10, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.35 }))

addTitan(clip("Harden", {
	K(0, {}),
	K(0.3, { RightShoulder = A(95, 0, -60), LeftShoulder = A(95, 0, 60), RightElbow = A(100, 0, 0), LeftElbow = A(100, 0, 0), Waist = A(-15, 0, 0), Neck = A(-15, 0, 0) }, "ExpoOut"),
	K(0.7, { RightShoulder = A(95, 0, -60), LeftShoulder = A(95, 0, 60), RightElbow = A(100, 0, 0), LeftElbow = A(100, 0, 0), Waist = A(-15, 0, 0) }, "Linear"),
}, { FadeOut = 0.4 }))

addTitan(clip("Throw", {
	K(0, {}),
	K(0.35, { RightShoulder = A(-30, 0, 30), RightElbow = A(60, 0, 0), Waist = A(-30, 0, 0), Root = A(-10, 0, 0) }, "QuadOut"),
	K(0.75, { RightShoulder = A(175, 0, 20), RightElbow = A(50, 0, 0), Waist = A(18, -30, 0), Root = A(0, 0, 0) }, "QuadOut"),
	K(0.92, { RightShoulder = A(50, 0, -15), RightElbow = A(5, 0, 0), Waist = A(-25, 30, 0) }, "ExpoOut"),
	K(1.6, { RightShoulder = A(25, 0, 0), Waist = A(-5, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.3 }))

addTitan(clip("Charge", {
	K(0, {}),
	K(0.5, { Root = TA(0, -0.05, 0, -30, 0, 0), Waist = A(-20, 0, 0), Neck = A(20, 0, 0), RightShoulder = A(-50, 0, 20), LeftShoulder = A(-50, 0, -20), RightElbow = A(60, 0, 0), LeftElbow = A(60, 0, 0) }, "QuadOut"),
	K(1.6, { Root = TA(0, -0.05, 0, -32, 0, 0), Waist = A(-22, 0, 0), Neck = A(22, 0, 0), RightShoulder = A(-55, 0, 20), LeftShoulder = A(-55, 0, -20) }, "Linear"),
}, { FadeOut = 0.4 }))

addTitan(clip("Steam", {
	K(0, {}),
	K(0.5, { RightShoulder = A(30, 0, 60), LeftShoulder = A(30, 0, -60), Neck = A(25, 0, 0), Jaw = A(30, 0, 0), Waist = A(10, 0, 0) }, "QuadOut"),
	K(1.0, { RightShoulder = A(30, 0, 62), LeftShoulder = A(30, 0, -62), Neck = A(28, 0, 0), Jaw = A(32, 0, 0) }, "Linear"),
}, { FadeOut = 0.5 }))

addTitan(clip("Slam", {
	K(0, {}),
	K(0.7, { RightShoulder = A(170, 0, 10), LeftShoulder = A(170, 0, -10), RightElbow = A(30, 0, 0), LeftElbow = A(30, 0, 0), Waist = A(15, 0, 0) }, "QuadOut"),
	K(0.9, { RightShoulder = A(40, 0, 5), LeftShoulder = A(40, 0, -5), Waist = A(-45, 0, 0), Root = TA(0, -0.04, 0, -10, 0, 0) }, "ExpoOut"),
	K(1.6, { Waist = A(-10, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.35 }))

addTitan(clip("GroundSpikes", {
	K(0, {}),
	K(0.6, { Waist = A(-55, 0, 0), RightShoulder = A(35, 0, -5), RightElbow = A(5, 0, 0), LeftShoulder = A(35, 0, 5), RightKnee = A(-40, 0, 0), LeftKnee = A(-40, 0, 0), RightHip = A(35, 0, 0), LeftHip = A(35, 0, 0) }, "QuadOut"),
	K(0.8, { Waist = A(-60, 0, 0), RightShoulder = A(30, 0, -5), LeftShoulder = A(30, 0, 5) }, "ExpoOut"),
	K(1.4, { Waist = A(-10, 0, 0) }, "QuadOut"),
}, { FadeOut = 0.35 }))

addTitan(clip("Blinded", {
	K(0, {}),
	K(0.3, { RightShoulder = A(145, 0, -35), RightElbow = A(125, 0, 0), LeftShoulder = A(145, 0, 35), LeftElbow = A(125, 0, 0), Neck = A(-15, 0, 0), Waist = A(-10, 0, 0) }, "ExpoOut"),
	K(1.0, { RightShoulder = A(140, 10, -35), RightElbow = A(120, 0, 0), LeftShoulder = A(140, -10, 35), LeftElbow = A(120, 0, 0), Neck = A(-10, 15, 0) }, "SineInOut"),
	K(2.0, { RightShoulder = A(145, -10, -35), RightElbow = A(125, 0, 0), LeftShoulder = A(145, 10, 35), LeftElbow = A(125, 0, 0), Neck = A(-15, -15, 0) }, "SineInOut"),
}, { Loop = true, FadeOut = 0.4, Priority = 1 }))

addTitan(clip("Fallen", {
	K(0, {}),
	K(0.5, { Root = TA(0, -0.32, 0, -20, 0, 0), RightHip = A(95, 0, 10), LeftHip = A(95, 0, -10), RightKnee = A(-110, 0, 0), LeftKnee = A(-110, 0, 0), Waist = A(-25, 0, 0), RightShoulder = A(40, 0, 20), LeftShoulder = A(40, 0, -20) }, "QuadOut"),
}, { Hold = 999, FadeOut = 0.5, Priority = 1 }))

addTitan(clip("Death", {
	K(0, {}),
	K(0.35, { Root = TA(0, -0.05, 0, -10, 0, 8), Neck = A(20, 0, 0), Jaw = A(30, 0, 0), RightShoulder = A(30, 0, 40), LeftShoulder = A(30, 0, -40) }, "QuadOut"),
	K(1.0, { Root = TA(0, -0.3, -0.1, -40, 0, 12), RightKnee = A(-80, 0, 0), LeftKnee = A(-70, 0, 0), RightHip = A(60, 0, 0), LeftHip = A(50, 0, 0), Neck = A(-25, 0, 0), Jaw = A(35, 0, 0), RightShoulder = A(60, 0, 30), LeftShoulder = A(50, 0, -30) }, "QuadIn"),
	K(1.5, { Root = TA(0, -0.45, -0.25, -84, 0, 10), RightKnee = A(-20, 0, 0), LeftKnee = A(-30, 0, 0), RightHip = A(10, 0, 5), LeftHip = A(10, 0, -5), Neck = A(-10, 20, 0), Jaw = A(25, 0, 0), RightShoulder = A(150, 0, 30), LeftShoulder = A(100, 0, -40) }, "QuadIn"),
	K(1.75, { Root = TA(0, -0.43, -0.25, -86, 0, 10), Neck = A(-6, 20, 0), RightShoulder = A(145, 0, 32), LeftShoulder = A(105, 0, -38) }, "QuadOut"),
}, { Hold = 999, FadeOut = 0.1, Priority = 10 }))

-- Mappa attacco del server -> clip del gigante
Poses.TitanAttackClip = {
	Swipe = "Swipe",
	Grab = "Grab",
	Stomp = "Stomp",
	Bite = "Bite",
	NapeSwat = "NapeSwat",
	Leap = "Leap",
	Kick = "Kick",
	Punch = "Punch",
	Roar = "Roar",
	Scream = "Roar",
	Dominio = "Roar",
	Summon = "Roar",
	Harden = "Harden",
	RockThrow = "Throw",
	RockBarrage = "Throw",
	Cannon = "Punch",
	Charge = "Charge",
	Steam = "Steam",
	Spikes = "GroundSpikes",
	SpikeArena = "GroundSpikes",
	HammerSlam = "Slam",
}

return Poses
