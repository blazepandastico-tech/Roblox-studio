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

--[[
	MUSICA DINAMICA: cambia da sola (con dissolvenza) in base a dove sei e a cosa succede.
	Come aggiungere una traccia:
	  1. in Studio apri la Casella degli strumenti (Toolbox) → scheda Audio;
	  2. cerca per esempio "medieval town", "calm fantasy", "epic battle", "boss fight"
	     (le tracce caricate dall'account "Roblox" si possono usare gratis nei giochi);
	  3. tasto destro sulla traccia → "Copia ID risorsa" (Copy Asset ID);
	  4. incolla qui sotto così: "rbxassetid://1234567890".
	Una situazione lasciata "" usa la traccia Default; se anche Default è "", c'è silenzio.
]]
Sounds.Music = {
	Default = "", -- traccia di riserva per tutte le situazioni senza una traccia propria
	Calm = "", -- esplorazione di giorno (prati, foreste, mare)
	City = "", -- città e zone sicure
	Night = "", -- esplorazione di notte
	Battle = "", -- giganti vicini o che ti stanno inseguendo
	Boss = "", -- boss e raid
}

-- Suoni d'ambiente in sottofondo, insieme alla musica (stesse istruzioni; "" = spento)
Sounds.Ambient = {
	Rain = "", -- pioggia e temporale
	Wind = "", -- vento forte (temporale)
	Birds = "", -- uccellini di giorno all'aperto
	Night = "", -- grilli di notte all'aperto
}

return Sounds
