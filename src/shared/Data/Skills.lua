--[[
	Skills - abilità delle lame (tasti Z, X, C, V)
	Si sbloccano con la Maestria dell'arma (si guadagna colpendo con quelle lame).
]]

local Skills = {}

Skills.Order = { "Z", "X", "C", "V" }

Skills.Blade = {
	Z = {
		Key = "Z",
		Name = "Taglio Rotante",
		Mastery = 0,
		Cooldown = 6,
		Damage = 2.2,
		Radius = 16,
		Duration = 0.55,
		MaxHits = 6,
		Anim = "SpinSlash",
		Description = "Ruoti su te stesso colpendo tutto intorno.",
	},
	X = {
		Key = "X",
		Name = "Affondo Fulmineo",
		Mastery = 25,
		Cooldown = 9,
		Damage = 3.0,
		Distance = 50,
		Radius = 12,
		Duration = 0.45,
		MaxHits = 4,
		Anim = "Lunge",
		Description = "Uno scatto in avanti che trapassa i nemici sulla traiettoria.",
	},
	C = {
		Key = "C",
		Name = "Tornado d'Acciaio",
		Mastery = 75,
		Cooldown = 16,
		Damage = 1.1,
		Radius = 15,
		Duration = 1.4,
		Ticks = 7,
		MaxHits = 14,
		Anim = "Tornado",
		Description = "Ti trasformi in un vortice di lame. Ancora più letale in volo.",
	},
	V = {
		Key = "V",
		Name = "Danza delle Lame",
		Mastery = 150,
		Cooldown = 40,
		Damage = 2.4,
		Range = 130,
		Duration = 1.4,
		Hits = 5,
		MaxHits = 5,
		Anim = "BladeDance",
		TargetNape = true,
		Description = "Ti scagli sulla nuca del gigante più vicino e la colpisci cinque volte.",
	},
}

-- Il Risveglio Valkar (tasto G) è definito in Bloodlines.

return Skills
