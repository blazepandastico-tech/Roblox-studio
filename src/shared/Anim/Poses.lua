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
