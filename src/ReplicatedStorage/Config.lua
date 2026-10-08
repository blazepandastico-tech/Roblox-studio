-- Tutti i numeri di bilanciamento del gioco stanno qui.
local Config = {}

Config.GameName = "Calcio Fuorilegge"

Config.Teams = {
	Red = { Name = "Rossi", Color = Color3.fromRGB(235, 64, 52), BrickColor = "Really red" },
	Blue = { Name = "Blu", Color = Color3.fromRGB(41, 160, 255), BrickColor = "Bright blue" },
}

Config.Match = {
	Duration = 360, -- 6:00
	Intermission = 15,
	MinPlayers = 1, -- metti 2 per il gioco vero; 1 permette di provare da soli
	MaxPerTeam = 4,
	KickoffCountdown = 3,
	GoalCelebration = 4.5,
	ResumeCountdown = 2,
	EndScreen = 9,
}

Config.Field = {
	Length = 220, -- asse X, linea di porta - linea di porta
	Width = 140, -- asse Z
	GoalWidth = 26,
	GoalHeight = 10,
	GoalDepth = 9,
	WallHeight = 45,
	-- distanze dal centro (stud) degli slot di calcio d'inizio: portiere, 2 mediani, attaccante
	KickoffSlots = {
		{ x = 95, z = 0 },
		{ x = 45, z = -26 },
		{ x = 45, z = 26 },
		{ x = 12, z = 0 },
	},
}

-- Belvedere di legno sulla parete sud del canyon: Y e' la quota del pavimento, il campo si vede davanti (verso +Z).
Config.Lobby = {
	Center = Vector3.new(0, 60, -420),
}

Config.Move = {
	WalkSpeed = 18,
	SprintSpeed = 27,
	JumpPower = 0, -- Spazio e' il dribbling: niente salto normale (il jetpack arriva con i gadget)
}

Config.Stamina = {
	Pips = 4,
	SprintDrainPerSec = 1 / 1.2, -- 1 tacca ogni 1,2 s
	KickTap = 0.25,
	KickChargedMin = 0.5,
	KickChargedMax = 1.0,
	Pass = 0.25,
	Flick = 0.25,
	Lob = 0.35,
	Tackle = 0.5,
	Dash = 0.3,
	RegenDelay = 1.0,
	RegenPerSec = 1 / 1.5, -- 1 tacca ogni 1,5 s
	ExhaustedRecover = 0.5, -- dopo lo zero serve questo livello per rimettersi a correre
	WeakKickMultiplier = 0.45,
}

Config.Kick = {
	ChargeTime = 1.0,
	TapThreshold = 0.18,
	MinPower = 55,
	MaxPower = 125,
	Reach = 7.5,
	Cooldown = 0.3,
	ArcBase = 0.07, -- radianti, leggero arco
	MaxPitch = math.rad(38),
	MinPitch = math.rad(-4),
	PowerShotThreshold = 0.95,
	PowerHitSpeed = 55,
	PowerHitImpulse = 62,
	PassBase = 28,
	PassPerStud = 1.5,
	PassMin = 42,
	PassMax = 95,
	PassMinDot = 0.45,
	FlickForward = 24,
	FlickUp = 32,
	LobForward = 62,
	LobUp = 80,
	CallBallDuration = 3,
}

Config.Ball = {
	Diameter = 2.8,
	ControlRadius = 4.4,
	ReleaseRadius = 6.4,
	CarryDistance = 3.7,
	CarryDistanceTight = 3.0,
	MinControlSpeed = 1.5,
	FollowRate = 15,
	MaxCarrySpeed = 70,
	GroundDrag = 0.38, -- frazione di velocita' persa al secondo a terra
	AirDrag = 0.03,
	TouchLockAfterKick = 0.35,
	Magnus = 0.2, -- accelerazione laterale = Magnus * velocita' * effetto
	SpinDecay = 0.45, -- frazione di effetto persa al secondo
}

Config.Tackle = {
	Duration = 0.65,
	Speed = 52,
	Reach = 5.6,
	Cooldown = 1.2,
	BallKnock = 46,
	BallKnockUp = 16,
	VictimImpulse = 34,
}

Config.Dash = {
	Speed = 46,
	Duration = 0.22,
	Cooldown = 0.9,
	EvadeTime = 0.4,
}

Config.Ragdoll = {
	Duration = 1.2,
}

-- Tasti di default (la rimappatura da menu arriva in Fase 6)
Config.Controls = {
	Flick = Enum.KeyCode.Q,
	Lob = Enum.KeyCode.F,
	Tackle = Enum.KeyCode.E,
	Dribble = Enum.KeyCode.Space,
	Sprint = Enum.KeyCode.LeftShift,
	CallBall = Enum.KeyCode.R,
	Lobby = Enum.KeyCode.L,
	Gadget1 = Enum.KeyCode.One,
	Gadget2 = Enum.KeyCode.Two,
}

return Config
