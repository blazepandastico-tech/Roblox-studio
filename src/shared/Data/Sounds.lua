--[[
	Sounds - effetti sonori
	Di base usiamo i suoni integrati in Roblox (rbxasset://), che funzionano sempre.
	Per suoni migliori: cerca nel Creator Store (Toolbox > Audio), copia l'ID
	e sostituiscilo qui, ad esempio "rbxassetid://1234567890".
]]

local Sounds = {
	Slash = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.55 },
	SlashHeavy = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.6 },
	Unsheath = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.5 },
	HookFire = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.35, Pitch = 1.8 },
	HookHit = { Id = "rbxasset://sounds/collide.wav", Volume = 0.5, Pitch = 1.4 },
	Gas = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.25, Pitch = 1.6 },
	Explosion = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.9, Pitch = 0.45 },
	Shot = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.45, Pitch = 2.4 },
	Jump = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.4 },
	Land = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.6 },
	Step = { Id = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.5, Pitch = 0.35 },
	Splash = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.6 },
	UI = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25, Pitch = 1.3 },
	Reward = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 0.8 },
	Type = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.05, Pitch = 2.4 },
	Coins = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Pitch = 1.8 },
	Steam = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.6, Pitch = 0.4 },
	Thunder = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 1, Pitch = 0.3 },
	Roar = { Id = "rbxasset://sounds/action_falling.mp3", Volume = 1, Pitch = 0.25 },
}

-- Musica di sottofondo (lascia vuoto per nessuna musica, oppure metti ID del Creator Store)
Sounds.Music = {
	Default = "",
	Battle = "",
	Boss = "",
}

return Sounds
