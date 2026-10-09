--[[
	Controlli di coerenza dei dati di gioco (eseguiti da tools/test_data.py).
	Verifica che storia, missioni, PNG, negozi, ricette, sieri e giganti si riferiscano
	solo a cose che esistono davvero, e che curve di livello e statistiche siano sensate.
]]

local Shared = SHARED
local Config = require(Shared.Config)
local Util = require(Shared.Lib.Util)
local Items = require(Shared.Data.Items)
local Serums = require(Shared.Data.Serums)
local Bloodlines = require(Shared.Data.Bloodlines)
local Titans = require(Shared.Data.Titans)
local Enemies = require(Shared.Data.Enemies)
local Zones = require(Shared.Data.Zones)
local NPCs = require(Shared.Data.NPCs)
local Quests = require(Shared.Data.Quests)
local Leveling = require(Shared.Data.Leveling)
local StatsCalc = require(Shared.Data.StatsCalc)
local Shops = require(Shared.Data.Shops)
local Story = require(Shared.Data.Story)
local Skills = require(Shared.Data.Skills)
local Poses = require(Shared.Anim.Poses)
local W = require(Shared.Data.WorldLayout)
local Raids = require(Shared.Data.Raids)
local Monetization = require(Shared.Data.Monetization)
local ODMPhysics = require(Shared.Modules.ODMPhysicsModule)
local Rewards = require(Shared.Data.Rewards)
local Achievements = require(Shared.Data.Achievements)
local Treasures = require(Shared.Data.Treasures)
local AbuseEvents = require(Shared.Data.AbuseEvents)

local errors: { string } = {}
local checks = 0

local function check(condition: any, message: string, ...: any)
	checks += 1
	if not condition then
		local args = table.pack(...)
		for i = 1, args.n do
			args[i] = tostring(args[i])
		end
		table.insert(errors, message:format(table.unpack(args, 1, args.n)))
	end
end

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- OGGETTI ------------------------------------------------------------------------------------
for id, def in Items.List do
	check(def.Id == id, "Items.%s: Id diverso dalla chiave", id)
	check(type(def.Name) == "string" and def.Name ~= "", "Items.%s: nome mancante", id)
	check(Items.Categories[def.Category] ~= nil, "Items.%s: categoria '%s' inesistente", id, def.Category)
	check(Items.Rarities[def.Rarity] ~= nil, "Items.%s: rarità '%s' inesistente", id, def.Rarity)
	check(type(def.Description) == "string" and def.Description ~= "", "Items.%s: descrizione mancante", id)
	if Items.IsEquipment(id) then
		check(isNumber(def.LevelReq), "Items.%s: LevelReq mancante", id)
	end
	if def.Price ~= nil then
		check(isNumber(def.Price) and def.Price > 0, "Items.%s: prezzo non valido", id)
	end
	local category = def.Category
	if category == "Lame" then
		check(isNumber(def.Damage) and isNumber(def.Durability), "Items.%s: lame senza Damage/Durability", id)
	elseif category == "DMT" then
		check(isNumber(def.Range) and isNumber(def.Gas) and isNumber(def.Reel), "Items.%s: DMT senza Range/Gas/Reel", id)
	elseif category == "Distanza" then
		check(isNumber(def.Damage) and type(def.Kind) == "string", "Items.%s: arma a distanza senza Damage/Kind", id)
	end
end
for slot, id in Items.Starter do
	check(Items.Get(id) ~= nil and Items.SlotOf(id) == slot, "Items.Starter.%s: '%s' non valido", slot, id)
end

-- SIERI --------------------------------------------------------------------------------------
for _, id in Serums.Order do
	check(Serums.List[id] ~= nil, "Serums.Order: '%s' inesistente", id)
end
local previousLevel = 0
for id, serum in Serums.List do
	check(table.find(Serums.Order, id) ~= nil, "Serums.%s: manca in Serums.Order", id)
	check(serum.Id == id, "Serums.%s: Id diverso dalla chiave", id)
	check(Items.Rarities[serum.Rarity] ~= nil, "Serums.%s: rarità '%s' inesistente", id, serum.Rarity)
	for _, key in { "LevelReq", "Height", "Health", "Damage", "Speed", "Energy", "Price", "DealerChance", "WorldWeight", "Fragments", "CraftGold" } do
		check(isNumber(serum[key]), "Serums.%s: campo %s non numerico", id, key)
	end
	check(serum.DealerChance >= 0 and serum.DealerChance <= 1, "Serums.%s: DealerChance fuori da 0..1", id)
	for _, key in Skills.Order do
		local skill = serum.Skills[key]
		check(skill ~= nil, "Serums.%s: manca l'abilità %s", id, key)
		if skill then
			check(type(skill.Name) == "string" and type(skill.Kind) == "string", "Serums.%s.%s: Name/Kind mancanti", id, key)
			check(isNumber(skill.Cooldown) and isNumber(skill.Energy) and isNumber(skill.Mastery), "Serums.%s.%s: Cooldown/Energy/Mastery non numerici", id, key)
			check(type(skill.Description) == "string", "Serums.%s.%s: descrizione mancante", id, key)
		end
	end
end
for i, id in Serums.Order do
	local serum = Serums.List[id]
	if serum then
		check(serum.LevelReq >= previousLevel, "Serums.Order: %s ha un livello minore del precedente", id)
		previousLevel = serum.LevelReq
		check(serum.LevelReq <= Config.MaxLevel, "Serums.%s: livello oltre il massimo", id)
		if i > 1 then
			local prev = Serums.List[Serums.Order[i - 1]]
			if prev then
				check(serum.Fragments >= prev.Fragments, "Serums.%s: servono meno frammenti del siero precedente", id)
			end
		end
	end
end

-- STIRPI -------------------------------------------------------------------------------------
local totalWeight = 0
for _, id in Bloodlines.Order do
	local b = Bloodlines.List[id]
	check(b ~= nil and isNumber(b.Weight) and type(b.Name) == "string", "Bloodlines.%s non valida", id)
	if b then
		totalWeight += b.Weight
	end
end
check(totalWeight > 0, "Bloodlines: peso totale nullo")
local rng = Random.new(7)
for _ = 1, 200 do
	local id = Bloodlines.Roll(rng)
	check(Bloodlines.List[id] ~= nil, "Bloodlines.Roll ha restituito '%s'", id)
end

-- GIGANTI E NEMICI ---------------------------------------------------------------------------
for id, class in Titans.Classes do
	check(isNumber(class.Height) or id == "Sagoma", "Titans.Classes.%s: Height mancante", id)
end
local titanClips = Poses.Titan.Clips
for attack in Titans.Attacks do
	local clipName = Poses.TitanAttackClip[attack]
	check(clipName ~= nil, "Titans.Attacks.%s: nessuna animazione in Poses.TitanAttackClip", attack)
	if clipName then
		check(titanClips[clipName] ~= nil, "Poses.TitanAttackClip.%s -> clip '%s' inesistente", attack, clipName)
	end
end
for _, attack in Titans.DefaultAttacks do
	check(Titans.Attacks[attack] ~= nil, "Titans.DefaultAttacks: '%s' non definito in Titans.Attacks", attack)
end
for id, boss in Titans.Bosses do
	check(boss.Id == id, "Titans.Bosses.%s: Id diverso dalla chiave", id)
	check(Zones.Get(boss.Zone) ~= nil, "Titans.Bosses.%s: zona '%s' inesistente", id, boss.Zone)
	check(isNumber(boss.Level) and isNumber(boss.Height) and isNumber(boss.HPMult), "Titans.Bosses.%s: Level/Height/HPMult mancanti", id)
	for _, attack in boss.Attacks or {} do
		check(Titans.Attacks[attack] ~= nil, "Titans.Bosses.%s: attacco '%s' non definito", id, attack)
	end
	if boss.Drops then
		for _, drop in boss.Drops do
			local dropId = drop.Id or drop.Item or drop[1]
			check(Items.Get(dropId) ~= nil or Serums.Get(dropId) ~= nil, "Titans.Bosses.%s: drop '%s' inesistente", id, dropId)
		end
	end
	if boss.Serum then
		check(Serums.Get(boss.Serum) ~= nil, "Titans.Bosses.%s: siero '%s' inesistente", id, boss.Serum)
	end
end
for id, enemy in Enemies.Types do
	check(enemy.Id == id, "Enemies.Types.%s: Id diverso dalla chiave", id)
end
for id, boss in Enemies.Bosses do
	check(Enemies.Types[boss.Type] ~= nil, "Enemies.Bosses.%s: tipo '%s' inesistente", id, boss.Type)
	check(Zones.Get(boss.Zone) ~= nil, "Enemies.Bosses.%s: zona '%s' inesistente", id, boss.Zone)
end

-- ZONE ---------------------------------------------------------------------------------------
local seenZones = {}
for _, zone in Zones.List do
	check(not seenZones[zone.Id], "Zones: zona duplicata %s", zone.Id)
	seenZones[zone.Id] = true
	check(Zones.Ambience[zone.Ambience] ~= nil, "Zones.%s: ambientazione '%s' inesistente", zone.Id, zone.Ambience)
	check(Zones.SeasonNames[zone.Season] ~= nil, "Zones.%s: stagione %s non valida", zone.Id, zone.Season)
	check(typeof(zone.Center) == "Vector3" and isNumber(zone.Radius), "Zones.%s: Center/Radius non validi", zone.Id)
	check(type(zone.Level) == "table" and zone.Level[1] <= zone.Level[2], "Zones.%s: intervallo di livelli non valido", zone.Id)
	for _, spawn in zone.Titans or {} do
		check(Titans.Classes[spawn.Class] ~= nil, "Zones.%s: classe di gigante '%s' inesistente", zone.Id, spawn.Class)
		check(isNumber(spawn.Level) and isNumber(spawn.Count), "Zones.%s: spawn senza Level/Count", zone.Id)
	end
	for _, spawn in zone.Enemies or {} do
		local typeId = spawn.Type or spawn.Enemy
		check(Enemies.Types[typeId] ~= nil, "Zones.%s: nemico '%s' inesistente", zone.Id, typeId)
	end
	if zone.Spawn then
		local point = Zones.SpawnPoint(zone)
		check(typeof(point) == "Vector3", "Zones.%s: SpawnPoint non valido", zone.Id)
	end
end
check(Zones.Get("CampoAddestramento") ~= nil, "Zones: manca la zona iniziale CampoAddestramento")
for _, zone in Zones.List do
	local found = Zones.Find(zone.Center)
	check(found ~= nil, "Zones.Find non trova nessuna zona al centro di %s", zone.Id)
end

-- PNG ----------------------------------------------------------------------------------------
for _, npc in NPCs.List do
	check(Zones.Get(npc.Zone) ~= nil, "NPCs.%s: zona '%s' inesistente", npc.Id, npc.Zone)
	check(typeof(npc.Offset) == "Vector3", "NPCs.%s: Offset mancante", npc.Id)
	if npc.Character then
		check(NPCs.Characters[npc.Character] ~= nil, "NPCs.%s: personaggio '%s' inesistente", npc.Id, npc.Character)
	end
	local name = NPCs.DisplayName(npc)
	check(type(name) == "string" and name ~= "", "NPCs.%s: nome vuoto", npc.Id)
	if npc.Role == "Shop" then
		check(Shops.List[npc.Shop] ~= nil, "NPCs.%s: negozio '%s' inesistente", npc.Id, npc.Shop)
	elseif npc.Role == "Quest" then
		check(type(npc.Quests) == "table" and #npc.Quests > 0, "NPCs.%s: nessuna missione", npc.Id)
		for _, questId in npc.Quests or {} do
			check(Quests.Get(questId) ~= nil, "NPCs.%s: missione '%s' inesistente", npc.Id, questId)
		end
	elseif npc.Role == "Ship" or npc.Role == "Lift" then
		local dest = Zones.Get(npc.Destination)
		check(dest ~= nil, "NPCs.%s: destinazione '%s' inesistente", npc.Id, npc.Destination)
	end
	if npc.Greeting then
		check(type(npc.Greeting) == "table" and #npc.Greeting > 0, "NPCs.%s: Greeting vuoto", npc.Id)
	end
end
-- ogni missione deve essere offerta da almeno un PNG
local offered = {}
for _, npc in NPCs.List do
	for _, questId in npc.Quests or {} do
		offered[questId] = true
	end
end

-- MISSIONI -----------------------------------------------------------------------------------
for id, quest in Quests.List do
	check(offered[id] == true, "Quests.%s: nessun PNG offre questa missione", id)
	check(isNumber(quest.Level) and isNumber(quest.LevelReq) and isNumber(quest.Count) and quest.Count > 0, "Quests.%s: Level/LevelReq/Count non validi", id)
	check(quest.LevelReq <= quest.Level, "Quests.%s: LevelReq maggiore del livello della missione", id)
	local t = quest.Target
	if t.Kind == "Titan" then
		check(Titans.Classes[t.Class] ~= nil, "Quests.%s: classe '%s' inesistente", id, t.Class)
		local zone = Zones.Get(t.Zone)
		check(zone ~= nil, "Quests.%s: zona '%s' inesistente", id, t.Zone)
		if zone then
			local spawns = false
			for _, spawn in zone.Titans or {} do
				if spawn.Class == t.Class then
					spawns = true
				end
			end
			check(spawns, "Quests.%s: nella zona %s non nascono giganti %s", id, t.Zone, t.Class)
		end
	elseif t.Kind == "Boss" then
		local boss = Titans.Bosses[t.Boss]
		check(boss ~= nil, "Quests.%s: boss '%s' inesistente", id, t.Boss)
		if boss and boss.Raid then
			local inRaid = false
			for _, raid in Raids.List do
				if raid.Boss and raid.Boss.Id == t.Boss then
					inRaid = true
				end
			end
			check(inRaid, "Quests.%s: il boss '%s' è solo da raid ma nessun raid lo contiene", id, t.Boss)
		elseif boss then
			check(Zones.Get(boss.Zone) ~= nil, "Quests.%s: il boss '%s' non ha una zona dove comparire", id, t.Boss)
		end
	elseif t.Kind == "Enemy" then
		check(Enemies.Types[t.Type] ~= nil, "Quests.%s: nemico '%s' inesistente", id, t.Type)
		local zone = Zones.Get(t.Zone)
		check(zone ~= nil, "Quests.%s: zona '%s' inesistente", id, t.Zone)
		if zone then
			local spawns = false
			for _, spawn in zone.Enemies or {} do
				if (spawn.Type or spawn.Enemy) == t.Type then
					spawns = true
				end
			end
			check(spawns, "Quests.%s: nella zona %s non nascono nemici '%s'", id, t.Zone, t.Type)
		end
	elseif t.Kind == "HumanBoss" then
		check(Enemies.Bosses[t.Boss] ~= nil, "Quests.%s: boss umano '%s' inesistente", id, t.Boss)
		local spawnsSomewhere = false
		for _, zone in Zones.List do
			for _, bossId in zone.HumanBosses or {} do
				if bossId == t.Boss then
					spawnsSomewhere = true
				end
			end
		end
		check(spawnsSomewhere, "Quests.%s: il boss umano '%s' non compare in nessuna zona", id, t.Boss)
	else
		check(false, "Quests.%s: tipo di obiettivo '%s' sconosciuto", id, t.Kind)
	end
	local xp, gold = Quests.Rewards(quest, Leveling)
	check(xp > 0 and gold > 0, "Quests.%s: ricompense nulle", id)
end

-- NEGOZI E RICETTE ---------------------------------------------------------------------------
for shopId, shop in Shops.List do
	check(type(shop.Name) == "string", "Shops.%s: nome mancante", shopId)
	for _, itemId in shop.Items do
		local def = Items.Get(itemId)
		check(def ~= nil, "Shops.%s: oggetto '%s' inesistente", shopId, itemId)
		if def then
			check(isNumber(def.Price) and def.Price > 0, "Shops.%s: '%s' non ha un prezzo", shopId, itemId)
		end
	end
end
local recipeIds = {}
for _, recipe in Shops.Recipes do
	check(not recipeIds[recipe.Id], "Shops.Recipes: ricetta duplicata %s", recipe.Id)
	recipeIds[recipe.Id] = true
	if recipe.Serum then
		check(Serums.Get(recipe.Result) ~= nil, "Ricetta %s: siero '%s' inesistente", recipe.Id, recipe.Result)
	else
		check(Items.Get(recipe.Result) ~= nil, "Ricetta %s: oggetto '%s' inesistente", recipe.Id, recipe.Result)
	end
	check(isNumber(recipe.Gold) and isNumber(recipe.LevelReq), "Ricetta %s: Gold/LevelReq non validi", recipe.Id)
	for materialId, count in recipe.Materials do
		local def = Items.Get(materialId)
		check(def ~= nil, "Ricetta %s: materiale '%s' inesistente", recipe.Id, materialId)
		check(isNumber(count) and count > 0, "Ricetta %s: quantità non valida per %s", recipe.Id, materialId)
	end
end
local npcShops = {}
for _, npc in NPCs.List do
	if npc.Shop then
		npcShops[npc.Shop] = true
	end
end
for shopId in Shops.List do
	check(npcShops[shopId] == true, "Shops.%s: nessun PNG gestisce questo negozio", shopId)
end

-- STORIA -------------------------------------------------------------------------------------
local STEP_TYPES = { Talk = true, Reach = true, Kill = true, Boss = true, Cutscene = true, Level = true, Enemy = true, HumanBoss = true, Collect = true }
local function checkLines(where: string, lines)
	for i, line in lines do
		check(type(line.Text) == "string" and line.Text ~= "", "%s: battuta %d vuota", where, i)
		check(NPCs.Characters[line.Speaker] ~= nil or NPCs.Get(line.Speaker) ~= nil, "%s: chi parla '%s' non esiste", where, line.Speaker)
	end
end
local storyNpcs = {}
local cutscenes = {}
local lastLevel = 0
for ci, chapter in Story.Chapters do
	local where = ("Story[%d] %s"):format(ci, tostring(chapter.Id))
	check(type(chapter.Id) == "string" and type(chapter.Title) == "string", "%s: Id/Title mancanti", where)
	check(Zones.SeasonNames[chapter.Season] ~= nil, "%s: stagione non valida", where)
	check(isNumber(chapter.Level) and chapter.Level >= lastLevel, "%s: livello del capitolo non crescente", where)
	lastLevel = chapter.Level or lastLevel
	check(type(chapter.Steps) == "table" and #chapter.Steps > 0, "%s: nessun passo", where)
	for si, step in chapter.Steps do
		local w = ("%s passo %d (%s)"):format(where, si, tostring(step.Type))
		check(STEP_TYPES[step.Type], "%s: tipo sconosciuto", w)
		check(type(step.Objective) == "string" and step.Objective ~= "", "%s: obiettivo mancante", w)
		if step.Type == "Talk" then
			check(NPCs.Get(step.Npc) ~= nil, "%s: PNG '%s' inesistente", w, step.Npc)
			check(type(step.Dialogue) == "table" and #step.Dialogue > 0, "%s: dialogo vuoto", w)
			checkLines(w, step.Dialogue or {})
			storyNpcs[step.Npc] = true
		elseif step.Type == "Reach" then
			check(Zones.Get(step.Zone) ~= nil or typeof(step.Position) == "Vector3", "%s: né zona né posizione valide", w)
			if step.Zone then
				check(Zones.Get(step.Zone) ~= nil, "%s: zona '%s' inesistente", w, step.Zone)
			end
		elseif step.Type == "Kill" then
			check(Titans.Classes[step.Class] ~= nil, "%s: classe '%s' inesistente", w, step.Class)
			local zone = Zones.Get(step.Zone)
			check(zone ~= nil, "%s: zona '%s' inesistente", w, step.Zone)
			if zone and step.Class ~= "Sagoma" then
				local spawns = false
				for _, spawn in zone.Titans or {} do
					if spawn.Class == step.Class then
						spawns = true
					end
				end
				check(spawns, "%s: nella zona %s non nascono giganti %s", w, step.Zone, step.Class)
			end
			check(isNumber(step.Count) and step.Count > 0, "%s: Count non valido", w)
		elseif step.Type == "Boss" then
			local boss = Titans.Bosses[step.Boss]
			check(boss ~= nil, "%s: boss '%s' inesistente", w, step.Boss)
			if boss and boss.Raid then
				-- un boss da raid deve esistere in almeno un raid
				local inRaid = false
				for _, raid in Raids.List or Raids do
					if type(raid) == "table" and raid.Boss and raid.Boss.Id == step.Boss then
						inRaid = true
					end
				end
				check(inRaid, "%s: il boss '%s' è solo da raid ma nessun raid lo contiene", w, step.Boss)
			elseif boss then
				check(Zones.Get(boss.Zone) ~= nil, "%s: il boss '%s' non ha una zona dove comparire", w, step.Boss)
			end
		elseif step.Type == "HumanBoss" then
			check(Enemies.Bosses[step.Boss] ~= nil, "%s: boss umano '%s' inesistente", w, step.Boss)
			local spawnsSomewhere = false
			for _, zone in Zones.List do
				for _, id in zone.HumanBosses or {} do
					if id == step.Boss then
						spawnsSomewhere = true
					end
				end
			end
			check(spawnsSomewhere, "%s: il boss umano '%s' non compare in nessuna zona", w, step.Boss)
		elseif step.Type == "Enemy" then
			check(Enemies.Types[step.Enemy] ~= nil, "%s: nemico '%s' inesistente", w, step.Enemy)
			local zone = Zones.Get(step.Zone)
			check(zone ~= nil, "%s: zona '%s' inesistente", w, step.Zone)
			if zone then
				local spawns = false
				for _, spawn in zone.Enemies or {} do
					if (spawn.Type or spawn.Enemy) == step.Enemy then
						spawns = true
					end
				end
				check(spawns, "%s: nella zona %s non nascono nemici '%s'", w, step.Zone, step.Enemy)
			end
		elseif step.Type == "Level" then
			check(isNumber(step.Level) and step.Level <= Config.MaxLevel, "%s: livello non valido", w)
		elseif step.Type == "Cutscene" then
			check(type(step.Cutscene) == "string", "%s: filmato mancante", w)
			cutscenes[step.Cutscene] = true
		elseif step.Type == "Collect" then
			check(Zones.Get(step.Zone) ~= nil, "%s: zona '%s' inesistente", w, step.Zone)
			check(isNumber(step.Count), "%s: Count mancante", w)
		end
		if step.After then
			checkLines(w .. " (After)", step.After)
		end
		if step.Reward and step.Reward.Items then
			for itemId in step.Reward.Items do
				check(Items.Get(itemId) ~= nil, "%s: ricompensa '%s' inesistente", w, itemId)
			end
		end
	end
end
-- i PNG della storia devono esistere nel mondo con il ruolo Story (o almeno esistere)
for npcId in storyNpcs do
	check(NPCs.Get(npcId) ~= nil, "Storia: PNG '%s' non presente nel mondo", npcId)
end
local seasons = {}
for _, chapter in Story.Chapters do
	seasons[chapter.Season] = true
end
for season = 1, 4 do
	check(seasons[season] == true, "Storia: nessun capitolo nella stagione %d", season)
end

-- ABILITÀ DELLE LAME E ANIMAZIONI -------------------------------------------------------------
for _, key in Skills.Order do
	local skill = Skills.Blade[key]
	check(skill ~= nil, "Skills.Blade: manca %s", key)
	if skill then
		check(Poses.Human.Clips[skill.Anim] ~= nil, "Skills.Blade.%s: animazione '%s' inesistente", key, skill.Anim)
		check(isNumber(skill.Cooldown) and isNumber(skill.Damage) and isNumber(skill.Mastery), "Skills.Blade.%s: valori non numerici", key)
	end
end

-- LOCOMOZIONE DA BATTAGLIA ---------------------------------------------------------------------
for _, case in { { 0, 0, true }, { 8, 0, true }, { 24, 0, true }, { 24, 1, false }, { 3, 0.5, false } } do
	local ok, pose = pcall(Poses.Human.BattleLoco, 1.3, { Flat = case[1], Air = case[2], Blades = case[3], Phase = 2.1 })
	check(ok and type(pose) == "table" and pose.Root ~= nil and pose.RightHip ~= nil and pose.LeftShoulder ~= nil, "BattleLoco non valida (velocità %s): %s", case[1], if ok then "" else pose)
end

-- LIVELLI E STATISTICHE ----------------------------------------------------------------------
local totalXP = 0
local prev = 0
for level = 1, Config.MaxLevel - 1 do
	local need = Leveling.XPToNext(level)
	check(need > prev, "Leveling.XPToNext non crescente al livello %d", level)
	prev = need
	totalXP += need
end
local profile = { Level = 1, XP = 0, StatPoints = 0 }
local gained = Leveling.AddXP(profile, totalXP + 10)
check(profile.Level == Config.MaxLevel and gained == Config.MaxLevel - 1, "Leveling.AddXP: livello finale %d (atteso %d)", profile.Level, Config.MaxLevel)
check(profile.StatPoints == (Config.MaxLevel - 1) * Config.StatPointsPerLevel, "Leveling.AddXP: punti statistica errati")

local function fakeProfile(level: number, equipped, bloodline: string)
	return {
		Level = level,
		Stats = { Forza = level, Vitalita = level, Agilita = level, Mira = level, Gigante = level },
		Equipped = equipped,
		Bloodline = bloodline,
		WeaponMastery = {},
		SerumMastery = {},
		Inventory = {},
		Buffs = {},
		Serum = "",
	}
end
local starter = { Blade = Items.Starter.Blade, Gear = Items.Starter.Gear, Armor = Items.Starter.Armor, Ranged = "", Accessory = "" }
local best = { Blade = "LameAurora", Gear = "DMTValkar", Armor = "ArmaturaCristallo", Ranged = "CannoneAntigigante", Accessory = "MedagliaComandante" }
for slot, id in best do
	check(Items.Get(id) ~= nil and Items.SlotOf(id) == slot, "Test statistiche: '%s' non è un oggetto %s", id, slot)
end
for _, case in { { 1, starter, "Isolano" }, { 500, starter, "Valkar" }, { Config.MaxLevel, best, "StirpeReale" } } do
	local stats = StatsCalc.Compute(fakeProfile(case[1], case[2], case[3]))
	check(type(stats) == "table", "StatsCalc.Compute non restituisce una tabella")
	for key, value in stats do
		if type(value) == "number" then
			check(isNumber(value), "StatsCalc: %s = %s al livello %d", key, value, case[1])
		end
	end
	check(isNumber(stats.MaxHealth) and stats.MaxHealth > 0, "StatsCalc: MaxHealth non valido al livello %d", case[1])
end

-- ISOLE --------------------------------------------------------------------------------------
for _, id in W.IslandOrder do
	local island = W.Islands[id]
	check(island ~= nil and island.Id == id, "W.Islands.%s non valida", id)
	if island then
		local hub = Zones.Get(island.Hub)
		check(hub ~= nil, "Isola %s: zona principale '%s' inesistente", id, island.Hub)
		if hub then
			check(hub.Island == id, "Isola %s: la zona principale %s sta su un'altra isola (%s)", id, island.Hub, hub.Island)
			check(island.Raid or (hub.Safe and hub.Spawn), "Isola %s: la zona principale deve essere sicura e di rinascita", id)
		end
	end
end
for _, a in W.IslandOrder do
	for _, b in W.IslandOrder do
		if a < b then
			local ia, ib = W.Islands[a], W.Islands[b]
			check(Util.FlatDistance(ia.Center, ib.Center) > ia.Water + ib.Water - 100, "Isole %s e %s troppo vicine", a, b)
		end
	end
end
for _, zone in Zones.List do
	if zone.Islet then
		-- gli isolotti del mare aperto: la zona coincide con l'isolotto
		local islet = W.IsletAt(zone.Center)
		check(islet ~= nil and islet.Id == zone.Id, "Zones.%s: non coincide con nessun isolotto", zone.Id)
		check(zone.Island == nil, "Zones.%s: un isolotto non può stare dentro un'isola grande", zone.Id)
	else
		check(zone.Island ~= nil, "Zones.%s: non sta su nessuna isola", zone.Id)
	end
	local island = zone.Island and W.Islands[zone.Island]
	if island and not zone.Underground then
		check(Util.FlatDistance(zone.Center, island.Center) + zone.Radius <= island.Land + 10, "Zones.%s: esce dalla terraferma di %s", zone.Id, zone.Island)
	end
end
for i, a in Zones.List do
	for j, b in Zones.List do
		if i < j and (a.Underground == true) == (b.Underground == true) then
			local d = Util.FlatDistance(a.Center, b.Center)
			local nested = d + math.min(a.Radius, b.Radius) <= math.max(a.Radius, b.Radius)
			check(nested or d >= a.Radius + b.Radius - 5, "Zone %s e %s si sovrappongono", a.Id, b.Id)
		end
	end
end
for id, wall in W.Walls do
	check(W.Islands[wall.Island] ~= nil, "Mura %s: isola inesistente", id)
end
for id, d in W.Districts do
	check(W.Walls[d.Wall] ~= nil, "Distretto %s: mura inesistenti", id)
end
-- livelli delle isole coerenti con la storia
for _, chapter in Story.Chapters do
	for _, step in chapter.Steps do
		local zone = step.Zone and Zones.Get(step.Zone)
		if zone and zone.Island and W.Islands[zone.Island] then
			check(W.Islands[zone.Island].LevelReq <= math.max(chapter.Level, 1), "Storia %s: la zona %s è su un'isola che richiede Lv.%d", chapter.Id, step.Zone, W.Islands[zone.Island].LevelReq)
		end
	end
end
for _, npc in NPCs.List do
	if npc.Role == "Ferry" then
		local zone = Zones.Get(npc.Zone)
		check(zone ~= nil and zone.Safe, "Traghetto %s fuori da una zona sicura", npc.Id)
	end
end

-- RAID ---------------------------------------------------------------------------------------
check(Zones.Get("ArenaRaid") ~= nil, "Manca la zona ArenaRaid")
for _, raid in Raids.List do
	check(Titans.Bosses[raid.Boss.Id] ~= nil, "Raid %s: boss '%s' inesistente", raid.Id, raid.Boss.Id)
	check(#raid.Waves > 0, "Raid %s: nessuna ondata", raid.Id)
	for _, wave in raid.Waves do
		check(Titans.Classes[wave.Class] ~= nil and not Titans.Classes[wave.Class].Dummy, "Raid %s: classe '%s' non valida", raid.Id, wave.Class)
	end
	for _, drop in raid.Rewards.Drops or {} do
		check(Items.Get(drop.Id) ~= nil, "Raid %s: bottino '%s' inesistente", raid.Id, drop.Id)
	end
	check(raid.Level >= raid.LevelReq, "Raid %s: livello minore del requisito", raid.Id)
end

-- PREMI (calendario, regali a tempo, ruota) ------------------------------------------------------
local function checkBundle(where: string, bundle)
	local any = false
	for _, key in { "Gold", "GoldQuests", "Gems", "Spins" } do
		if bundle[key] ~= nil then
			check(isNumber(bundle[key]) and bundle[key] > 0, "%s: %s non valido", where, key)
			any = true
		end
	end
	for id, count in bundle.Items or {} do
		check(Items.Get(id) ~= nil, "%s: oggetto inesistente %s", where, id)
		check(isNumber(count) and count > 0, "%s: quantità non valida per %s", where, id)
		any = true
	end
	check(any, "%s: premio vuoto", where)
end
check(#Rewards.Daily == 7, "Il calendario deve avere 7 giorni")
for i, day in Rewards.Daily do
	check(day.Day == i, "Calendario: giorno %d fuori ordine", i)
	checkBundle("Calendario giorno " .. i, day)
end
local lastMinutes = 0
for i, gift in Rewards.Playtime do
	check(gift.Minutes > lastMinutes, "Regalo a tempo %d: minuti non crescenti", i)
	lastMinutes = gift.Minutes
	checkBundle("Regalo a tempo " .. i, gift)
end
check(math.abs(Rewards.WheelTotal() - 100) < 0.001, "Ruota: le probabilità devono sommare 100 (ora %s)", Rewards.WheelTotal())
local wheelIds = {}
for _, prize in Rewards.Wheel do
	check(not wheelIds[prize.Id], "Ruota: premio duplicato %s", prize.Id)
	wheelIds[prize.Id] = true
	check(prize.Weight > 0, "Ruota: peso non valido per %s", prize.Id)
	checkBundle("Ruota " .. prize.Id, prize)
	if prize.UniqueItem then
		check(Items.Get(prize.UniqueItem) ~= nil and isNumber(prize.FallbackGems), "Ruota %s: premio unico non valido", prize.Id)
	end
end

-- TRAGUARDI ----------------------------------------------------------------------------------------
local validStats = { Level = true, Titans = true, Napes = true, Bosses = true, Enemies = true, RaidsWon = true, Chapter = true, PlayHours = true, Streak = true, Friends = true, Treasures = true, PvPKills = true, Bounty = true }
local achievementIds = {}
for _, a in Achievements.List do
	check(not achievementIds[a.Id], "Traguardo duplicato %s", a.Id)
	achievementIds[a.Id] = true
	check(validStats[a.Stat], "Traguardo %s: statistica sconosciuta %s", a.Id, a.Stat)
	check(isNumber(a.Goal) and a.Goal > 0 and isNumber(a.Gems) and isNumber(a.BadgeId), "Traguardo %s: valori non validi", a.Id)
	if a.Stat == "Chapter" then
		check(a.Goal <= #Story.Chapters, "Traguardo %s: capitolo oltre la fine della storia", a.Id)
	end
	if a.Stat == "Level" then
		check(a.Goal <= Config.MaxLevel, "Traguardo %s: livello oltre il massimo", a.Id)
	end
	if a.Stat == "Treasures" then
		check(a.Goal <= #Treasures.List, "Traguardo %s: più forzieri di quelli che esistono", a.Id)
	end
end
check(Achievements.Get("TesoroTutti") ~= nil and Achievements.Get("TesoroTutti").Goal == #Treasures.List, "Traguardo TesoroTutti: deve chiedere tutti i %d forzieri", #Treasures.List)

-- MONDO APERTO -------------------------------------------------------------------------------------
local SB = W.SeaBounds
local function inSea(pos: Vector3, margin: number): boolean
	return pos.X > SB.MinX + margin and pos.X < SB.MaxX - margin and pos.Z > SB.MinZ + margin and pos.Z < SB.MaxZ - margin
end
for i, islet in W.Islets do
	check(Zones.Get(islet.Id) ~= nil, "Isolotto %s: manca la sua zona", islet.Id)
	check(inSea(islet.Center, 300), "Isolotto %s: troppo vicino al bordo del mare", islet.Id)
	for _, isl in W.Islands do
		check(Util.FlatDistance(islet.Center, isl.Center) > isl.Beach + islet.Radius + 60, "Isolotto %s: troppo vicino all'isola %s", islet.Id, isl.Id)
	end
	for j, other in W.Islets do
		if i < j then
			check(Util.FlatDistance(islet.Center, other.Center) > islet.Radius + other.Radius + 200, "Isolotti %s e %s troppo vicini", islet.Id, other.Id)
		end
	end
	check(not W.IsOpenSea(islet.Center), "Isolotto %s: risulta in mare aperto", islet.Id)
end
check(W.IsOpenSea(Vector3.new(800, 4, -1700)), "Il mare tra Vermiglia ed Edenia dovrebbe essere mare aperto")
local duel = Zones.Get("ArenaDuelli")
check(duel ~= nil and duel.PvP == true and not duel.Safe, "Arena dei Duelli: zona PvP mancante")
for _, t in W.Taverns do
	local zone = Zones.Get(t.Zone)
	check(zone ~= nil, "Taverna %s: zona %s inesistente", t.Id, t.Zone)
	if zone then
		local center = zone.Center + t.Offset
		local island = zone.Island and W.Islands[zone.Island]
		check(island ~= nil and Util.FlatDistance(center, island.Center) + 20 < island.Land, "Taverna %s: non sta sulla terraferma", t.Id)
		for _, wall in W.Walls do
			local r = Util.FlatDistance(center, W.WallCenter(wall.Id))
			check(math.abs(r - wall.Radius) > 20 + wall.Thickness, "Taverna %s: finisce dentro le mura %s", t.Id, wall.Id)
		end
		local hasOste = false
		for _, npc in NPCs.List do
			local nz = Zones.Get(npc.Zone)
			if nz and not nz.Underground then
				local d = Util.FlatDistance(nz.Center + npc.Offset, center)
				if npc.Tavern == t.Id then
					hasOste = true
					check(d < 14 and npc.Role == "Tavern", "Taverna %s: l'oste %s non è dentro la taverna", t.Id, npc.Id)
				else
					check(d > 22, "Taverna %s: il PNG %s finirebbe dentro l'edificio", t.Id, npc.Id)
				end
			end
		end
		check(hasOste, "Taverna %s: manca l'oste", t.Id)
	end
end
local validModes = { Top = true, Ground = true, Under = true, Inside = true }
for _, t in Treasures.List do
	check(Treasures.TierInfo[t.Tier] ~= nil, "Forziere %s: rarità %s sconosciuta", t.Id, tostring(t.Tier))
	check(validModes[t.Mode] == true, "Forziere %s: modo %s sconosciuto", t.Id, tostring(t.Mode))
	check(type(t.Hint) == "string" and #t.Hint > 10, "Forziere %s: manca la voce dell'oste", t.Id)
	check(inSea(t.Pos, 200), "Forziere %s: fuori dal mondo", t.Id)
	if t.Mode == "Under" then
		local zone = Zones.Find(t.Pos)
		check(zone ~= nil and zone.Underground == true, "Forziere %s: non è in una grotta", t.Id)
	elseif t.Mode == "Ground" then
		-- deve stare sulla terra (isola o isolotto), non in acqua
		local onLand = W.IsletAt(t.Pos) ~= nil
		for _, isl in W.Islands do
			if Util.FlatDistance(t.Pos, isl.Center) < isl.Beach - 5 then
				onLand = true
			end
		end
		check(onLand, "Forziere %s: finirebbe in mare", t.Id)
	end
end
check(Enemies.Types.Contrabbandiere ~= nil, "Manca il nemico Contrabbandiere")
for _, key in { "Boat", "Sea", "Horse", "PvP", "Treasures" } do
	check(type((Config :: any)[key]) == "table", "Config.%s mancante", key)
end

-- NEGOZIO PREMIUM ------------------------------------------------------------------------------
local seen = {}
for _, p in Monetization.Products do
	check(not seen[p.Id], "Prodotto duplicato %s", p.Id)
	seen[p.Id] = true
	check(p.Kind == "Gems" or p.Kind == "Gold" or p.Kind == "Spins" or p.Kind == "Starter", "Prodotto %s: tipo non valido", p.Id)
	if p.Kind == "Starter" then
		check(type(p.Bundle) == "table" and isNumber(p.Robux), "Prodotto %s: pacchetto non valido", p.Id)
		for id in (p.Bundle and p.Bundle.Items or {}) do
			check(Items.Get(id) ~= nil, "Prodotto %s: oggetto inesistente %s", p.Id, id)
		end
	else
		check(isNumber(p.Amount) and p.Amount > 0 and isNumber(p.Robux), "Prodotto %s: valori non validi", p.Id)
	end
end
for _, pass in Monetization.GamePasses do
	check(type(pass.Bonuses) == "table", "Pass %s senza Bonuses", pass.Id)
	if pass.GiftItem then
		check(Items.Get(pass.GiftItem) ~= nil, "Pass %s: regalo '%s' inesistente", pass.Id, pass.GiftItem)
	end
end
for _, entry in Monetization.GemShop do
	check(entry.Item == nil or Items.Get(entry.Item) ~= nil, "Negozio gemme %s: oggetto '%s' inesistente", entry.Id, entry.Item)
	check(entry.Item ~= nil or entry.Action ~= nil, "Negozio gemme %s: né oggetto né azione", entry.Id)
end
check(#Serums.Order == 8, "I sieri devono essere esattamente 8 (ora %d)", #Serums.Order)
check(Config.Serums.Available == false, "I sieri devono restare bloccati fino al prossimo aggiornamento")

-- FISICA DEI RAMPINI ------------------------------------------------------------------------
do
	local function stepWith(overrides)
		local input = {
			Position = Vector3.new(0, 50, 0),
			Velocity = Vector3.new(0, 0, 0),
			Hooks = {},
			Move = Vector3.zero,
			Boost = false,
			BoostDirection = Vector3.new(0, 0, -1),
			Gas = 100,
			GasEfficiency = 1,
			SpeedMult = 1,
			Momentum = 0,
			Clearance = nil,
			Range = 115,
			dt = 1 / 60,
		}
		for k, v in overrides do
			input[k] = v
		end
		return ODMPhysics.Step(input), input
	end

	-- il verricello tira verso l'aggancio e consuma gas
	local out = stepWith({ Hooks = { { Target = Vector3.new(0, 50, -80), RopeLength = 80, Held = true } } })
	check(out.Velocity.Z < 0, "ODM: il verricello non tira verso l'aggancio (vz=%s)", out.Velocity.Z)
	check(out.GasUsed > 0, "ODM: il verricello non consuma gas")
	-- senza gas niente trazione
	local dry = stepWith({ Gas = 0, Hooks = { { Target = Vector3.new(0, 50, -80), RopeLength = 80, Held = true } } })
	check(dry.GasUsed == 0 and dry.Velocity.Z == 0, "ODM: senza gas il verricello tira ancora")
	-- vicinanza: un aggancio vicino tira più di uno lontano
	check(ODMPhysics.ProximityFactor(20, 115) > ODMPhysics.ProximityFactor(110, 115), "ODM: la vicinanza non aumenta la trazione")
	-- angolo: tirare in avanti rende più che tirare all'indietro
	local v = Vector3.new(0, 0, -100)
	check(ODMPhysics.AngleFactor(v, Vector3.new(0, 0, -1)) > ODMPhysics.AngleFactor(v, Vector3.new(0, 0, 1)), "ODM: l'angolo non influisce sulla trazione")
	check(ODMPhysics.AngleFactor(Vector3.zero, Vector3.new(0, 0, 1)) == 1, "ODM: da fermi l'angolo deve essere neutro")
	-- il cavo teso impedisce di allontanarsi (pendolo)
	local rope = { Target = Vector3.new(0, 100, 0), RopeLength = 50, Held = false }
	local swing = stepWith({ Velocity = Vector3.new(0, -60, 0), Hooks = { rope } })
	check(swing.Velocity.Y > -5, "ODM: il cavo teso non trattiene (vy=%s)", swing.Velocity.Y)
	-- slancio cinetico: cresce rasente agli ostacoli, cala lontano
	local m = 0
	for _ = 1, 60 do
		m = ODMPhysics.UpdateMomentum(m, 150, 3, 1 / 60)
	end
	check(m > 0.4, "ODM: lo slancio non cresce vicino agli ostacoli (%s)", m)
	check(ODMPhysics.UpdateMomentum(m, 150, nil, 1) < m, "ODM: lo slancio non cala lontano dagli ostacoli")
	check(ODMPhysics.UpdateMomentum(0, 20, 2, 1) == 0, "ODM: lo slancio cresce anche da fermi")
	check(ODMPhysics.MaxSpeed(1, 1) > ODMPhysics.MaxSpeed(1, 0), "ODM: lo slancio non alza la velocità massima")
	-- limite di velocità rispettato
	local fast = stepWith({ Velocity = Vector3.new(0, 0, -1000), Momentum = 1 })
	check(fast.Velocity.Magnitude <= ODMPhysics.MaxSpeed(1, 1) + 1e-6, "ODM: superato il limite di velocità")
	-- coerenza con la convalida del server
	check(ODMPhysics.ValidateAnchor(Vector3.zero, Vector3.new(0, 0, 110), 115, 0), "ODM: aggancio valido rifiutato")
	check(not ODMPhysics.ValidateAnchor(Vector3.zero, Vector3.new(0, 0, 400), 115, 0), "ODM: aggancio a 400 studs accettato")
	local maxStep = ODMPhysics.MaxDisplacement(1, 0.25)
	check(maxStep >= ODMPhysics.MaxSpeed(1, 1) * 0.25, "ODM: la convalida punirebbe un volo legittimo")
	check(maxStep >= Config.ODM.Validation.MinSpeedCap * 0.25, "ODM: la convalida punirebbe la Danza delle Lame")
	check(ODMPhysics.HookCost(2) < ODMPhysics.HookCost(1), "ODM: l'efficienza del gas non riduce i consumi")
	check(ODMPhysics.GasDrain(1, true, 1, 1) > ODMPhysics.GasDrain(1, false, 1, 1), "ODM: lo scatto non consuma gas")
	check(Config.Combat.SpearFuse > 0.6 and Config.Combat.SpearFuse < 5, "Miccia delle Lance Dirompenti fuori misura")
end

-- EVENTI A TEMPO DELL'ADMIN ABUSE ------------------------------------------------------------------
do
	check(#AbuseEvents.List >= 5, "servono almeno 5 eventi a tempo")
	local skyKeys = { "Color", "Decay", "Tint", "CloudColor" }
	local skyNumbers = { "Density", "Haze", "Glare", "Exposure", "Saturation", "Contrast", "Bright", "Cover", "Rain" }
	for _, def in AbuseEvents.List do
		local where = "Evento " .. tostring(def.Id)
		check(AbuseEvents.Get(def.Id) == def, "%s: non trovato per Id", where)
		check(type(def.Icon) == "string" and type(def.Name) == "string" and type(def.Text) == "string" and type(def.Short) == "string" and type(def.Episode) == "string", "%s: testi mancanti", where)
		check(typeof(def.Color) == "Color3", "%s: colore mancante", where)
		check(type(def.Bonus) == "table", "%s: bonus mancanti", where)
		for key, value in def.Bonus do
			check(type(value) == "number" and value >= 0 and value <= 3, "%s: bonus %s fuori misura", where, key)
		end
		check(def.Boss == nil or Titans.Bosses[def.Boss] ~= nil, "%s: boss inesistente %s", where, def.Boss)
		check(type(def.Sky) == "table", "%s: cielo mancante", where)
		if def.Sky then
			for _, key in skyKeys do
				check(typeof(def.Sky[key]) == "Color3", "%s: colore del cielo %s mancante", where, key)
			end
			for _, key in skyNumbers do
				check(type(def.Sky[key]) == "number", "%s: valore del cielo %s mancante", where, key)
			end
		end
		check(type(def.Ambient) == "string", "%s: particelle mancanti", where)
	end
	for _, minutes in AbuseEvents.Durations do
		check(AbuseEvents.ClampMinutes(minutes) == minutes, "durata %d minuti fuori dai limiti", minutes)
	end
	check(AbuseEvents.FormatTime(3725) == "1:02:05" and AbuseEvents.FormatTime(65) == "1:05", "FormatTime degli eventi sbagliato")
end

-- ADDESTRAMENTO DI BASE ------------------------------------------------------------------------------
do
	local Tutorial = require(Shared.Data.Tutorial)
	local W = require(Shared.Data.WorldLayout)
	local GOALS = { Look = true, Walk = true, Jump = true, Action = true, Hook = true, Boost = true, Rings = true, NapeKill = true, Refill = true, Panel = true }
	local ACTIONS = { Dodge = true, Attack = true, SkillZ = true, Reload = true }
	local PANELS = { Menu = true, Mappa = true }
	local ids = {}
	local lastSection = 0
	for i, step in Tutorial.Steps do
		local where = ("Tutorial.Steps[%d] %s"):format(i, tostring(step.Id))
		check(step.Id and not ids[step.Id], "%s: Id mancante o doppio", where)
		ids[step.Id] = true
		check(Tutorial.Sections[step.Section] ~= nil, "%s: sezione %s inesistente", where, tostring(step.Section))
		check(step.Section >= lastSection, "%s: le sezioni devono andare in ordine", where)
		lastSection = step.Section
		check(type(step.Title) == "string" and #step.Title > 0 and type(step.Text) == "string" and #step.Text > 20, "%s: titolo o testo mancante", where)
		check(step.Keys and step.Keys.PC and #step.Keys.PC > 0, "%s: mancano i tasti del PC", where)
		check(step.Keys and type(step.Keys.Touch) == "string", "%s: manca la spiegazione per il telefono", where)
		check(GOALS[step.Goal.Kind], "%s: obiettivo %s sconosciuto", where, tostring(step.Goal.Kind))
		if step.Goal.Kind == "Action" then
			check(ACTIONS[step.Goal.Action], "%s: azione %s non controllata dal tutorial", where, tostring(step.Goal.Action))
		elseif step.Goal.Kind == "Panel" then
			check(PANELS[step.Goal.Panel], "%s: pannello %s sconosciuto", where, tostring(step.Goal.Panel))
		elseif step.Goal.Kind == "Look" or step.Goal.Kind == "Walk" or step.Goal.Kind == "Boost" then
			check(type(step.Goal.Amount) == "number" and step.Goal.Amount > 0, "%s: manca Amount", where)
		end
	end
	-- gli anelli d'oro attorno alla torre, raggiungibili con i rampini (non troppo alti né lontani)
	local tower = W.Landmarks.TorreAddestramento
	for i, ring in Tutorial.Rings do
		local flat = Vector3.new(ring.X - tower.X, 0, ring.Z - tower.Z).Magnitude
		check(flat < 60 and ring.Y > W.GroundY + 10 and ring.Y < tower.Y + 10, "Tutorial.Rings[%d]: troppo lontano dalla torre o ad altezza sbagliata", i)
	end
	for id, count in Tutorial.Reward.Items or {} do
		check(Items.Get(id) ~= nil and count > 0, "Tutorial.Reward: oggetto %s inesistente", id)
	end
	for _, entry in Tutorial.Islands do
		check(W.Islands[entry.Island] ~= nil, "Tutorial.Islands: isola %s inesistente", tostring(entry.Island))
		check(#Tutorial.IslandZones(entry.Island, 4) > 0 or entry.Island == "Arena", "Tutorial.Islands: l'isola %s non ha zone", tostring(entry.Island))
	end
	local story = Story.Chapters[Tutorial.StoryChapter]
	local gate = story and story.Steps[Tutorial.StoryStep]
	check(gate ~= nil and gate.Type == "Talk" and gate.Npc == "Brehm", "Tutorial.StoryStep deve essere il passo \"Presentati all'Istruttore Brehm\"")
	check(story ~= nil and story.Steps[1].Type == "Cutscene", "il tutorial deve venire dopo il prologo")
end

-- RISULTATO ----------------------------------------------------------------------------------
local cutsceneList = {}
for id in cutscenes do
	table.insert(cutsceneList, id)
end
table.sort(cutsceneList)
print("CUTSCENES:" .. table.concat(cutsceneList, ","))
if #errors > 0 then
	table.sort(errors)
	for _, e in errors do
		print("ERRORE: " .. e)
	end
	print(("%d controlli, %d errori"):format(checks, #errors))
	error("controlli dei dati falliti", 0)
end
print(("Dati OK: %d controlli superati"):format(checks))
local _ = Util
