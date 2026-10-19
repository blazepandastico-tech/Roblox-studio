--[[
	RaidService - raid a ondate nell'Isola dell'Arena
	  1) Un giocatore sceglie un raid da un Maestro dei Raid e paga (oro o Sigillo del Raid)
	  2) Per Raids.LobbyTime secondi gli altri possono unirsi parlando con un Maestro
	  3) Tutti vengono portati nell'Arena: ondate di giganti e infine un boss
	  4) Vittoria: oro, esperienza, gemme, Frammenti di Siero e bottino a chi è ancora in piedi
	Un solo raid alla volta per server (c'è una sola Arena).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Raids = require(Shared.Data.Raids)
local Titans = require(Shared.Data.Titans)
local Items = require(Shared.Data.Items)
local Leveling = require(Shared.Data.Leveling)
local Zones = require(Shared.Data.Zones)
local W = require(Shared.Data.WorldLayout)

local RaidService = {}
local S
local rng = Random.new()

local ARENA_ZONE = "ArenaRaid"
local FIGHT_RADIUS = 220

type Active = {
	Def: any,
	Phase: string, -- "Lobby" | "Running" | "Ending"
	Participants: { [Player]: boolean },
	PhaseEnds: number,
	EndsAt: number,
	Wave: number,
	Alive: { any },
	Token: number,
}

local active: Active? = nil
local token = 0

local function arenaCenter(): Vector3
	return W.IslandCenter("Arena") + Vector3.new(0, W.GroundY, 0)
end

local function participantsList(): { Player }
	local list = {}
	if active then
		for player in active.Participants do
			table.insert(list, player)
		end
	end
	return list
end

local function sendState(extra: { [string]: any }?)
	local a = active
	if not a then
		return
	end
	local state = {
		Active = true,
		Name = a.Def.Name,
		Icon = a.Def.Icon,
		Phase = a.Phase,
		Wave = a.Wave,
		Waves = #a.Def.Waves + 1,
		Remaining = #a.Alive,
		PhaseEnds = a.PhaseEnds,
		EndsAt = a.EndsAt,
		Now = os.time(),
		Players = #participantsList(),
	}
	if extra then
		for k, v in extra do
			state[k] = v
		end
	end
	for _, player in participantsList() do
		Net.Event("RaidState"):FireClient(player, state)
	end
end

local function clearState(player: Player, result: string?)
	Net.Event("RaidState"):FireClient(player, { Active = false, Result = result })
end

function RaidService.IsParticipant(player: Player): boolean
	return active ~= nil and active.Participants[player] == true
end

function RaidService.Active()
	return active
end

local function sendHome(player: Player)
	local profile = S.DataService.Get(player)
	local zone = Zones.Get(profile and profile.SpawnZone) or Zones.Get("CampoAddestramento")
	if zone and player.Parent then
		S.EventService.EffectTo(player, "Fade", { Time = 0.6 })
		task.wait(0.35)
		S.PlayerService.Teleport(player, Zones.SpawnPoint(zone))
	end
end

local function removeParticipant(player: Player, reason: string?)
	local a = active
	if not a or not a.Participants[player] then
		return
	end
	a.Participants[player] = nil
	if player.Parent then
		clearState(player, reason)
		if reason then
			S.EventService.Notify(player, reason, "Info", 4)
		end
	end
end

-- FINE DEL RAID ------------------------------------------------------------------------------

local function finish(victory: boolean, message: string?)
	local a = active
	if not a or a.Phase == "Ending" then
		return
	end
	a.Phase = "Ending"
	for _, t in a.Alive do
		S.TitanService.Despawn(t)
	end
	table.clear(a.Alive)
	local def = a.Def
	local list = participantsList()
	if victory then
		local rewards = def.Rewards
		for _, player in list do
			local profile = S.DataService.Get(player)
			if profile then
				local items = {}
				local fragments = rng:NextInteger(rewards.Fragments[1], rewards.Fragments[2])
				if fragments > 0 then
					items.FrammentoSiero = fragments
				end
				local luck = 1 + (S.PlayerService.Stats(player).DropLuck or 0)
				for _, drop in rewards.Drops or {} do
					if Items.Get(drop.Id) and rng:NextNumber() < drop.Chance * luck then
						items[drop.Id] = (items[drop.Id] or 0) + rng:NextInteger(drop.Min or 1, drop.Max or 1)
					end
				end
				S.PlayerService.GiveRewards(player, {
					XP = Leveling.QuestXP(def.Level) * rewards.XP,
					Gold = rewards.Gold,
					Items = items,
				}, "Raid completato")
				if S.MonetizationService then
					S.MonetizationService.AddGems(player, rewards.Gems, "raid")
				end
				profile.RaidsWon = (profile.RaidsWon or 0) + 1
				S.DataService.MarkDirty(player)
				S.EventService.AnnounceTo(player, "RAID COMPLETATO!", def.Name, "Vittoria")
			end
		end
		S.EventService.NotifyAll(("⚔️ La squadra di %d giocatori ha completato il raid \"%s\"!"):format(#list, def.Name), "Raro", 6)
	else
		for _, player in list do
			S.EventService.AnnounceTo(player, "RAID FALLITO", message or "I giganti hanno avuto la meglio...", "Errore")
		end
	end
	sendState({ Phase = "Ending", Result = if victory then "Vittoria" else "Sconfitta" })
	local myToken = a.Token
	task.delay(Raids.ReturnDelay, function()
		if not active or active.Token ~= myToken then
			return
		end
		local remaining = participantsList()
		active = nil
		for _, player in remaining do
			clearState(player, nil)
			task.spawn(sendHome, player)
		end
	end)
end

-- ONDATE ---------------------------------------------------------------------------------------

local function randomArenaPoint(): Vector3
	local a = rng:NextNumber(0, math.pi * 2)
	local r = math.sqrt(rng:NextNumber()) * (FIGHT_RADIUS - 30)
	return arenaCenter() + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

local function spawnWave(index: number)
	local a = active
	if not a then
		return
	end
	local def = a.Def
	a.Wave = index
	table.clear(a.Alive)
	local wave = def.Waves[index]
	if wave then
		for _ = 1, wave.Count do
			local t = S.TitanService.Spawn({
				Class = wave.Class,
				Level = def.Level + (index - 1) * math.max(5, math.floor(def.Level * 0.03)),
				Zone = ARENA_ZONE,
				Position = randomArenaPoint(),
				Abnormal = rng:NextNumber() < (wave.Abnormal or 0),
				Raid = true,
			})
			if t then
				table.insert(a.Alive, t)
			end
		end
		for _, player in participantsList() do
			S.EventService.AnnounceTo(player, ("Ondata %d / %d"):format(index, #def.Waves + 1), ("%d giganti in arrivo!"):format(#a.Alive), "Boss")
		end
	else
		local bossDef = Titans.Bosses[def.Boss.Id]
		local t = bossDef and S.TitanService.Spawn({
			Boss = def.Boss.Id,
			Level = def.Boss.Level,
			Zone = ARENA_ZONE,
			Position = arenaCenter() + Vector3.new(0, 0, -60),
			HPMult = def.Boss.HPMult,
			Raid = true,
		})
		if t then
			table.insert(a.Alive, t)
		end
		for _, player in participantsList() do
			S.EventService.AnnounceTo(player, "ONDATA FINALE", (bossDef and bossDef.Name or "Il boss") .. " è entrato nell'arena!", "Boss")
		end
	end
	sendState()
end

local function startFight()
	local a = active
	if not a then
		return
	end
	local list = participantsList()
	if #list == 0 then
		active = nil
		return
	end
	a.Phase = "Running"
	a.EndsAt = os.time() + a.Def.TimeLimit
	local platform = arenaCenter() + Vector3.new(0, 0, 200)
	for i, player in list do
		local offset = Vector3.new(((i - 1) % 6 - 2.5) * 6, 2, math.floor((i - 1) / 6) * 6)
		task.spawn(function()
			S.EventService.EffectTo(player, "Fade", { Time = 0.7 })
			task.wait(0.4)
			S.PlayerService.Teleport(player, platform + offset)
			S.PlayerService.RefillWeapons(player)
			S.ODMService.Refill(player)
			S.PlayerService.Heal(player, 1)
			Net.Event("Refilled"):FireClient(player, "Tutto")
		end)
	end
	task.wait(3)
	if active == a then
		spawnWave(1)
	end
end

-- Controllo continuo: partecipanti fuori dall'arena, ondate finite, tempo scaduto
local function tick()
	local a = active
	if not a then
		return
	end
	local now = os.time()
	if a.Phase == "Lobby" then
		for player in a.Participants do
			if not player.Parent then
				a.Participants[player] = nil
			end
		end
		if now >= a.PhaseEnds then
			task.spawn(startFight)
		end
		return
	end
	if a.Phase ~= "Running" then
		return
	end
	local center = arenaCenter()
	for _, player in participantsList() do
		local state = S.PlayerService.GetState(player)
		local root = Util.GetRoot(player.Character)
		if not player.Parent then
			a.Participants[player] = nil
		elseif state.Dead then
			removeParticipant(player, "Sei caduto in battaglia: per te il raid è finito.")
		elseif root and Util.FlatDistance(root.Position, center) > W.Islands.Arena.Water then
			removeParticipant(player, "Hai lasciato l'Arena: per te il raid è finito.")
		end
	end
	if next(a.Participants) == nil then
		finish(false, "Tutta la squadra è caduta.")
		return
	end
	if now >= a.EndsAt then
		finish(false, "Il tempo è scaduto.")
		return
	end
	-- giganti ancora vivi
	for i = #a.Alive, 1, -1 do
		local t = a.Alive[i]
		if t.State == "Dead" or not t.Model.Parent then
			table.remove(a.Alive, i)
		end
	end
	if #a.Alive == 0 and a.Wave > 0 and a.PhaseEnds <= now then
		if a.Wave > #a.Def.Waves then
			finish(true)
		else
			-- breve pausa, poi la prossima ondata
			a.PhaseEnds = now + Raids.Intermission
			sendState({ Phase = "Intermission" })
			local wave = a.Wave
			task.delay(Raids.Intermission, function()
				if active == a and a.Phase == "Running" and a.Wave == wave then
					spawnWave(wave + 1)
				end
			end)
		end
	end
end

-- DIALOGHI E SCELTE ---------------------------------------------------------------------------------

local function costText(def): string
	return ("%s oro o 1 Sigillo"):format(Util.Abbreviate(def.Cost))
end

function RaidService.DialogueFor(player: Player, npc)
	local profile = S.DataService.Get(player)
	local level = profile and profile.Level or 1
	local lines = { npc.Greeting and npc.Greeting[1] or "..." }
	local choices = {}
	local a = active
	if npc.Role == "RaidArena" then
		if a and a.Phase ~= "Lobby" and a.Participants[player] then
			table.insert(lines, ("Raid in corso: %s, ondata %d."):format(a.Def.Name, a.Wave))
		else
			table.insert(lines, "Al momento l'arena è vuota. Parla con un Maestro dei Raid per avviarne uno.")
		end
		table.insert(choices, { Id = "raid:leave", Text = "🏳️ Torna alla base" })
		table.insert(choices, { Id = "close", Text = "Resto qui" })
		return lines, choices
	end
	if a then
		if a.Phase == "Lobby" then
			local left = math.max(0, a.PhaseEnds - os.time())
			table.insert(lines, ("Il raid \"%s\" parte tra %d secondi (%d giocatori). Serve il livello %d."):format(a.Def.Name, left, #participantsList(), a.Def.LevelReq))
			if a.Participants[player] then
				table.insert(choices, { Id = "raid:leave", Text = "🏳️ Esci dalla squadra" })
			else
				table.insert(choices, { Id = "raid:join", Text = "⚔️ Unisciti al raid (gratis)", Disabled = level < a.Def.LevelReq })
			end
		else
			table.insert(lines, ("Il raid \"%s\" è già in corso (ondata %d). Aspetta che finisca."):format(a.Def.Name, a.Wave))
		end
		table.insert(choices, { Id = "close", Text = "Arrivederci" })
		return lines, choices
	end
	table.insert(lines, "Scegli un raid: tu paghi l'ingresso, gli altri si uniscono gratis entro 30 secondi.")
	for _, def in Raids.List do
		local locked = level < def.LevelReq
		table.insert(choices, {
			Id = "raid:start:" .. def.Id,
			Text = ("%s %s  [Lv.%d]  • %s"):format(if locked then "🔒" else def.Icon, def.Name, def.LevelReq, costText(def)),
			Disabled = locked,
		})
	end
	table.insert(choices, { Id = "close", Text = "Non ora" })
	return lines, choices
end

local function startLobby(player: Player, raidId: string)
	local def = Raids.Get(raidId)
	local profile = S.DataService.Get(player)
	if not def or not profile then
		return
	end
	if active then
		S.EventService.Notify(player, "C'è già un raid in corso su questo server.", "Errore", 3)
		return
	end
	if profile.Level < def.LevelReq then
		S.EventService.Notify(player, ("Serve il livello %d."):format(def.LevelReq), "Errore", 3)
		return
	end
	local paid = false
	if S.InventoryService.Has(player, "SigilloRaid", 1) then
		S.InventoryService.Take(player, "SigilloRaid", 1)
		paid = true
		S.EventService.Notify(player, "Hai consegnato un Sigillo del Raid.", "Info", 3)
	elseif S.PlayerService.SpendGold(player, def.Cost) then
		paid = true
	end
	if not paid then
		S.EventService.Notify(player, ("Servono %s oro (o un Sigillo del Raid, nel negozio delle gemme)."):format(Util.FormatNumber(def.Cost)), "Errore", 4)
		return
	end
	token += 1
	active = {
		Def = def,
		Phase = "Lobby",
		Participants = { [player] = true },
		PhaseEnds = os.time() + Raids.LobbyTime,
		EndsAt = 0,
		Wave = 0,
		Alive = {},
		Token = token,
	}
	S.EventService.Announce(("Raid: %s %s"):format(def.Icon, def.Name), ("%s ha avviato un raid! Parla con un Maestro dei Raid entro %d secondi per unirti (Lv. %d)."):format(player.DisplayName, Raids.LobbyTime, def.LevelReq), "Boss")
	sendState()
end

function RaidService.HandleChoice(player: Player, choiceId: string)
	if choiceId:sub(1, 11) == "raid:start:" then
		startLobby(player, choiceId:sub(12))
	elseif choiceId == "raid:join" then
		local a = active
		local profile = S.DataService.Get(player)
		if not a or a.Phase ~= "Lobby" or not profile then
			S.EventService.Notify(player, "Non c'è nessun raid a cui unirsi.", "Info", 3)
			return
		end
		if profile.Level < a.Def.LevelReq then
			S.EventService.Notify(player, ("Serve il livello %d."):format(a.Def.LevelReq), "Errore", 3)
			return
		end
		a.Participants[player] = true
		S.EventService.Notify(player, "Ti sei unito alla squadra del raid!", "Successo", 3)
		sendState()
	elseif choiceId == "raid:leave" then
		if active and active.Participants[player] then
			removeParticipant(player, "Hai lasciato il raid.")
			sendState()
		end
		local root = Util.GetRoot(player.Character)
		if root and Util.FlatDistance(root.Position, W.IslandCenter("Arena")) < W.Islands.Arena.Water then
			task.spawn(sendHome, player)
		end
	end
end

function RaidService.Init(services)
	S = services
end

function RaidService.Start()
	Players.PlayerRemoving:Connect(function(player)
		if active then
			active.Participants[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(tick)
			if not ok then
				warn("[RaidService] " .. tostring(err))
			end
			task.wait(1)
		end
	end)
end

return RaidService
