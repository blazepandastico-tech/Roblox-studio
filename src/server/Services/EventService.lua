--[[
	EventService
	Annunci globali, notifiche ai giocatori, effetti visivi da mostrare ai client
	ed eventi del mondo (Invasioni periodiche dei giganti).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Zones = require(Shared.Data.Zones)

local EventService = {}
local S

EventService.InvasionZone = nil :: string?
EventService.InvasionUntil = 0

function EventService.Announce(title: string, subtitle: string?, kind: string?)
	Net.Event("Announce"):FireAllClients({ Title = title, Subtitle = subtitle or "", Kind = kind or "Info" })
end

function EventService.AnnounceTo(player: Player, title: string, subtitle: string?, kind: string?)
	Net.Event("Announce"):FireClient(player, { Title = title, Subtitle = subtitle or "", Kind = kind or "Info" })
end

-- kind: "Info" | "Successo" | "Errore" | "Ricompensa" | "Raro" | "Storia"
function EventService.Notify(player: Player, text: string, kind: string?, duration: number?)
	Net.Event("Notify"):FireClient(player, text, kind or "Info", duration or 4)
end

function EventService.NotifyAll(text: string, kind: string?, duration: number?)
	Net.Event("Notify"):FireAllClients(text, kind or "Info", duration or 4)
end

-- Effetto visivo: se c'è una posizione viene inviato solo ai giocatori vicini
function EventService.Effect(name: string, params: { [string]: any }, position: Vector3?, radius: number?)
	local remote = Net.Event("Effect")
	if not position then
		remote:FireAllClients(name, params)
		return
	end
	local maxDist = radius or 900
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude <= maxDist then
			remote:FireClient(player, name, params)
		end
	end
end

-- Effetto visibile solo a un giocatore (dissolvenze, viaggi...)
function EventService.EffectTo(player: Player, name: string, params: { [string]: any })
	Net.Event("Effect"):FireClient(player, name, params)
end

-- Versione veloce (inaffidabile) per effetti frequenti
function EventService.EffectFast(name: string, params: { [string]: any }, position: Vector3?, radius: number?)
	local remote = Net.Unreliable("EffectFast")
	local maxDist = radius or 700
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not position or (root and (root.Position - position).Magnitude <= maxDist) then
			remote:FireClient(player, name, params)
		end
	end
end

function EventService.IsInvasion(zoneId: string?): boolean
	return zoneId ~= nil and EventService.InvasionZone == zoneId and os.clock() < EventService.InvasionUntil
end

local function runInvasions()
	while true do
		task.wait(Config.Events.InvasionInterval)
		-- scegli una zona di caccia dove c'è almeno un giocatore
		local candidates = {}
		for _, player in Players:GetPlayers() do
			local zone = Zones.Get(player:GetAttribute("Zone"))
			if zone and zone.Titans and not zone.Safe and not table.find(candidates, zone.Id) then
				table.insert(candidates, zone.Id)
			end
		end
		if #candidates > 0 and S.TitanService then
			local zoneId = candidates[math.random(1, #candidates)]
			local zone = Zones.Get(zoneId)
			EventService.InvasionZone = zoneId
			EventService.InvasionUntil = os.clock() + Config.Events.InvasionDuration
			EventService.Announce("INVASIONE!", ("Un'orda di giganti attacca: %s. Ricompense doppie per 5 minuti!"):format(zone.Name), "Pericolo")
			S.TitanService.StartInvasion(zoneId, Config.Events.InvasionDuration)
		end
	end
end

function EventService.Init(services)
	S = services
end

function EventService.Start()
	task.spawn(runInvasions)
end

return EventService
