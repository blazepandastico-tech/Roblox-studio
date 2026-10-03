--[[
	Serums - I Sieri Perduti
	Copie artificiali dei poteri degli Otto Giganti Mutaforma, create dal Dott. Vael.
	ATTENZIONE: per ora i sieri NON si possono ottenere (arrivano con il prossimo aggiornamento).
	Per sbloccarli basta mettere Config.Serums.Available = true.
	Quando saranno attivi si otterranno così (tutti difficilissimi):
	  1) Casse "Siero Perduto" che appaiono a caso nel mondo
	  2) Drop dei boss mutaforma (circa 0,5% - 1,2%)
	  3) Il Mercante Velato ad Aurion (merce che ruota ogni 4 ore, prezzi altissimi)
	  4) Sintesi al Laboratorio con centinaia di Frammenti di Siero
	Un giocatore può avere UN solo potere attivo: iniettarne un altro sostituisce il precedente.
]]

local Serums = {}

-- Ordine di rarità (dal più comune al più raro)
Serums.Order = {
	"SieroZanna",
	"SieroDestriero",
	"SieroFuria",
	"SieroBastione",
	"SieroCacciatrice",
	"SieroFauno",
	"SieroForgia",
	"SieroVulcano",
}

Serums.List = {
	SieroZanna = {
		Id = "SieroZanna",
		Name = "Siero del Gigante Zanna",
		TitanName = "Gigante Zanna",
		Rarity = "Epico",
		LevelReq = 300,
		Look = "Zanna",
		Height = 18,
		Health = 1.6,
		Damage = 110,
		Speed = 54,
		Energy = 75,
		SkinColor = Color3.fromRGB(214, 160, 128),
		HairColor = Color3.fromRGB(30, 26, 24),
		Price = 3000000,
		DealerChance = 0.25,
		WorldWeight = 120,
		Fragments = 250,
		CraftGold = 1500000,
		Passive = "Agilità felina: il più veloce dei Nove.",
		Description = "Piccolo, rapidissimo, con fauci capaci di spezzare il cristallo.",
		Skills = {
			Z = { Name = "Morso Frantumante", Kind = "Bite", Mastery = 0, Cooldown = 7, Energy = 4, Damage = 3.2, Radius = 0.6, ArmorBreak = true, Description = "Spezza anche la corazza indurita." },
			X = { Name = "Balzo Felino", Kind = "Leap", Mastery = 50, Cooldown = 10, Energy = 5, Damage = 2.2, Range = 130, Radius = 1.2, Description = "Salta sul bersaglio da grande distanza." },
			C = { Name = "Artigli Induriti", Kind = "Kick", Mastery = 120, Cooldown = 12, Energy = 6, Damage = 2.6, Radius = 1.1, Description = "Una raffica di artigli tutto intorno." },
			V = { Name = "Frenesia della Zanna", Kind = "Frenzy", Mastery = 250, Cooldown = 50, Energy = 14, Duration = 12, Amount = 0.8, Description = "+80% danni e velocità per 12 secondi." },
		},
	},

	SieroDestriero = {
		Id = "SieroDestriero",
		Name = "Siero del Gigante Destriero",
		TitanName = "Gigante Destriero",
		Rarity = "Epico",
		LevelReq = 300,
		Look = "Destriero",
		Height = 16,
		Health = 1.8,
		Damage = 90,
		Speed = 46,
		Energy = 140,
		SkinColor = Color3.fromRGB(205, 150, 120),
		HairColor = Color3.fromRGB(40, 34, 30),
		Price = 3000000,
		DealerChance = 0.25,
		WorldWeight = 120,
		Fragments = 250,
		CraftGold = 1500000,
		Passive = "Resistenza: la trasformazione dura il doppio.",
		Description = "Il gigante instancabile, capace di restare trasformato per giorni.",
		Skills = {
			Z = { Name = "Cannone a Spalla", Kind = "Cannon", Mastery = 0, Cooldown = 5, Energy = 3, Damage = 2.0, Radius = 0.9, Range = 300, Description = "Spara una granata dal cannone montato sulla schiena." },
			X = { Name = "Corsa Instancabile", Kind = "SpeedBoost", Mastery = 40, Cooldown = 16, Energy = 5, Duration = 8, Amount = 0.7, Description = "+70% velocità per 8 secondi." },
			C = { Name = "Corazza Panzer", Kind = "Harden", Mastery = 120, Cooldown = 20, Energy = 6, Duration = 7, Amount = 0.55, Description = "Riduce i danni subiti del 55%." },
			V = { Name = "Bombardamento", Kind = "RockBarrage", Mastery = 250, Cooldown = 45, Energy = 14, Damage = 2.2, Count = 8, Radius = 1.0, Range = 300, Description = "Una pioggia di granate sull'area mirata." },
		},
	},

	SieroFuria = {
		Id = "SieroFuria",
		Name = "Siero del Gigante della Furia",
		TitanName = "Gigante della Furia",
		Rarity = "Leggendario",
		LevelReq = 350,
		Look = "Furia",
		Height = 48,
		Health = 2.6,
		Damage = 170,
		Speed = 34,
		Energy = 90,
		SkinColor = Color3.fromRGB(196, 140, 110),
		HairColor = Color3.fromRGB(30, 24, 20),
		Price = 8000000,
		DealerChance = 0.12,
		WorldWeight = 60,
		Fragments = 500,
		CraftGold = 4000000,
		Passive = "Volontà indomabile: più sei ferito, più colpisci forte.",
		Description = "Il gigante che ha sempre combattuto per la libertà.",
		Skills = {
			Z = { Name = "Pugno Indurito", Kind = "Punch", Mastery = 0, Cooldown = 4, Energy = 3, Damage = 2.5, Radius = 0.45, Description = "Un pugno ricoperto di cristallo." },
			X = { Name = "Calcio Rotante", Kind = "Kick", Mastery = 60, Cooldown = 9, Energy = 5, Damage = 2.4, Radius = 0.8, Description = "Un calcio circolare che spazza via i giganti." },
			C = { Name = "Ruggito della Furia", Kind = "Roar", Mastery = 150, Cooldown = 20, Energy = 7, Damage = 1.2, Radius = 2.4, Duration = 3, Description = "Stordisce tutti i nemici vicini." },
			V = { Name = "Visione del Futuro", Kind = "FutureSight", Mastery = 300, Cooldown = 60, Energy = 15, Duration = 6, Amount = 0.8, Description = "6 secondi di invulnerabilità e +80% danni." },
		},
	},

	SieroBastione = {
		Id = "SieroBastione",
		Name = "Siero del Gigante Bastione",
		TitanName = "Gigante Bastione",
		Rarity = "Leggendario",
		LevelReq = 350,
		Look = "Bastione",
		Height = 48,
		Health = 4.0,
		Damage = 150,
		Speed = 28,
		Energy = 100,
		SkinColor = Color3.fromRGB(205, 160, 130),
		HairColor = Color3.fromRGB(230, 205, 140),
		Price = 8000000,
		DealerChance = 0.12,
		WorldWeight = 60,
		Fragments = 500,
		CraftGold = 4000000,
		Passive = "Corazza: subisci il 25% di danni in meno.",
		Description = "Placche di cristallo indurito coprono tutto il corpo.",
		Skills = {
			Z = { Name = "Pugno di Cristallo", Kind = "Punch", Mastery = 0, Cooldown = 4, Energy = 3, Damage = 2.3, Radius = 0.45, Description = "Un pugno corazzato." },
			X = { Name = "Carica Corazzata", Kind = "Charge", Mastery = 60, Cooldown = 10, Energy = 5, Damage = 2.4, Range = 160, Radius = 0.5, Description = "Ti lanci in avanti come un ariete." },
			C = { Name = "Corazza Totale", Kind = "Harden", Mastery = 150, Cooldown = 25, Energy = 7, Duration = 8, Amount = 0.7, Description = "Riduce i danni subiti del 70% per 8 secondi." },
			V = { Name = "Sfondamento", Kind = "Charge", Mastery = 300, Cooldown = 50, Energy = 14, Damage = 5, Range = 260, Radius = 0.9, Explode = true, Description = "Una carica devastante che termina con un'esplosione." },
		},
	},

	SieroCacciatrice = {
		Id = "SieroCacciatrice",
		Name = "Siero del Gigante Cacciatrice",
		TitanName = "Gigante Cacciatrice",
		Rarity = "Leggendario",
		LevelReq = 350,
		Look = "Cacciatrice",
		Height = 45,
		Health = 2.4,
		Damage = 160,
		Speed = 40,
		Energy = 95,
		SkinColor = Color3.fromRGB(232, 190, 165),
		HairColor = Color3.fromRGB(235, 205, 120),
		Price = 8000000,
		DealerChance = 0.12,
		WorldWeight = 60,
		Fragments = 500,
		CraftGold = 4000000,
		Passive = "Indurimento mirato: i colpi critici fanno più danni.",
		Description = "Agile e letale, capace di indurire qualsiasi parte del corpo.",
		Skills = {
			Z = { Name = "Calcio Indurito", Kind = "Kick", Mastery = 0, Cooldown = 4, Energy = 3, Damage = 2.4, Radius = 0.6, Description = "Un calcio rapido con il tallone di cristallo." },
			X = { Name = "Richiamo dei Giganti", Kind = "Summon", Mastery = 80, Cooldown = 30, Energy = 8, Count = 3, Duration = 18, Description = "Un urlo che richiama 3 giganti puri al tuo fianco." },
			C = { Name = "Cristallo Protettivo", Kind = "Crystal", Mastery = 150, Cooldown = 40, Energy = 6, Duration = 4, Amount = 0.3, Description = "Diventi invulnerabile e recuperi il 30% di salute." },
			V = { Name = "Furia della Cacciatrice", Kind = "Flurry", Mastery = 300, Cooldown = 45, Energy = 14, Damage = 1.4, Count = 6, Radius = 0.9, Description = "Una raffica di 6 colpi in pochi istanti." },
		},
	},

	SieroFauno = {
		Id = "SieroFauno",
		Name = "Siero del Gigante Fauno",
		TitanName = "Gigante Fauno",
		Rarity = "Leggendario",
		LevelReq = 500,
		Look = "Fauno",
		Height = 55,
		Health = 2.8,
		Damage = 150,
		Speed = 30,
		Energy = 100,
		SkinColor = Color3.fromRGB(120, 90, 60),
		HairColor = Color3.fromRGB(95, 70, 45),
		Price = 12000000,
		DealerChance = 0.08,
		WorldWeight = 50,
		Fragments = 650,
		CraftGold = 6000000,
		Passive = "Braccio da lanciatore: gli attacchi a distanza hanno +30% portata.",
		Description = "Un gigante coperto di pelo che lancia massi come proiettili d'artiglieria.",
		Skills = {
			Z = { Name = "Lancio di Massi", Kind = "RockThrow", Mastery = 0, Cooldown = 4, Energy = 3, Damage = 2.2, Radius = 0.7, Range = 400, Description = "Lancia un masso sul punto mirato." },
			X = { Name = "Pioggia di Pietre", Kind = "RockBarrage", Mastery = 80, Cooldown = 14, Energy = 6, Damage = 1.5, Count = 10, Radius = 0.7, Range = 420, Description = "Frantuma una roccia e la scaglia come una mitraglia." },
			C = { Name = "Urlo della Fauno", Kind = "Summon", Mastery = 180, Cooldown = 35, Energy = 9, Count = 4, Duration = 20, Description = "Richiama 4 giganti puri che combattono per te." },
			V = { Name = "Lancio Perfetto", Kind = "RockThrow", Mastery = 350, Cooldown = 55, Energy = 14, Damage = 6, Radius = 1.8, Range = 450, Big = true, Description = "Un unico, enorme masso con un'esplosione devastante." },
		},
	},

	SieroForgia = {
		Id = "SieroForgia",
		Name = "Siero del Gigante della Forgia",
		TitanName = "Gigante della Forgia",
		Rarity = "Mitico",
		LevelReq = 700,
		Look = "Forgia",
		Height = 48,
		Health = 3.0,
		Damage = 200,
		Speed = 34,
		Energy = 110,
		SkinColor = Color3.fromRGB(235, 215, 200),
		HairColor = Color3.fromRGB(240, 235, 225),
		Price = 18000000,
		DealerChance = 0.05,
		WorldWeight = 40,
		Fragments = 800,
		CraftGold = 9000000,
		Passive = "Armi di cristallo: crea armi indurite dal nulla.",
		Description = "Il gigante che forgia armi di cristallo dalla propria carne.",
		Skills = {
			Z = { Name = "Martello Indurito", Kind = "Punch", Mastery = 0, Cooldown = 5, Energy = 3, Damage = 3.0, Radius = 0.7, Description = "Un colpo di martello di cristallo." },
			X = { Name = "Lance di Cristallo", Kind = "Spikes", Mastery = 100, Cooldown = 12, Energy = 6, Damage = 2.6, Range = 140, Radius = 0.35, Description = "Una fila di punte di cristallo esplode dal terreno." },
			C = { Name = "Balestra di Cristallo", Kind = "Cannon", Mastery = 200, Cooldown = 16, Energy = 6, Damage = 4.0, Radius = 0.5, Range = 400, Description = "Un dardo gigante che trapassa i bersagli." },
			V = { Name = "Arena di Spine", Kind = "SpikeArena", Mastery = 400, Cooldown = 50, Energy = 14, Damage = 5.5, Radius = 2.2, Description = "Un anello di punte tutto intorno a te." },
		},
	},

	SieroVulcano = {
		Id = "SieroVulcano",
		Name = "Siero del Gigante Vulcano",
		TitanName = "Gigante Vulcano",
		Rarity = "Mitico",
		LevelReq = 900,
		Look = "Vulcano",
		Height = 190,
		Health = 6.0,
		Damage = 320,
		Speed = 22,
		Energy = 80,
		SkinColor = Color3.fromRGB(176, 66, 52),
		HairColor = Color3.fromRGB(120, 40, 30),
		Price = 30000000,
		DealerChance = 0.03,
		WorldWeight = 30,
		Fragments = 1000,
		CraftGold = 15000000,
		Passive = "Vapore: chi ti colpisce da vicino si scotta.",
		Description = "Sessanta metri di muscoli e vapore. Il gigante che ha sfondato le Mura.",
		Skills = {
			Z = { Name = "Calpestio Vulcano", Kind = "Stomp", Mastery = 0, Cooldown = 6, Energy = 3, Damage = 2.4, Radius = 0.5, Description = "Un piede grande come una casa." },
			X = { Name = "Vapore Ardente", Kind = "Steam", Mastery = 120, Cooldown = 20, Energy = 7, Damage = 0.6, Radius = 0.7, Duration = 6, Description = "Emetti vapore bollente per 6 secondi." },
			C = { Name = "Pugno dal Cielo", Kind = "Punch", Mastery = 250, Cooldown = 14, Energy = 6, Damage = 3.6, Radius = 0.45, Description = "Un pugno che cade come un meteorite." },
			V = { Name = "Esplosione Vulcano", Kind = "Explosion", Mastery = 450, Cooldown = 90, Energy = 20, Damage = 9, Radius = 1.6, Description = "La trasformazione stessa diventa un'arma: un'esplosione titanica." },
		},
	},

}

-- Nota: Radius è un multiplo dell'altezza del gigante (scala con la forma),
-- Range è in studs assoluti.

-- Attacco base (clic sinistro) in forma di gigante
Serums.BasicAttack = { Name = "Pugno", Kind = "Punch", Cooldown = 0.75, Damage = 1.0, Radius = 0.4 }

function Serums.Get(id: string?)
	if not id then
		return nil
	end
	return Serums.List[id]
end

-- Tabella per l'estrazione casuale delle casse nel mondo
function Serums.WorldTable()
	local list = {}
	for _, id in Serums.Order do
		local def = Serums.List[id]
		table.insert(list, { Id = id, Weight = def.WorldWeight })
	end
	return list
end

return Serums
