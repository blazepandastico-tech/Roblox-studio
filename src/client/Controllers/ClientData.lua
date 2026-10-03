--[[
	ClientData
	Copia locale dei progressi del giocatore (inviata dal server con "DataSync").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Lib.Signal)
local Net = require(Shared.Lib.Net)

local ClientData = {}
ClientData.Profile = nil :: any
ClientData.Stats = nil :: any
ClientData.Changed = Signal.new()
ClientData.Ready = false

function ClientData.WaitReady()
	while not ClientData.Ready do
		task.wait(0.1)
	end
	return ClientData.Profile
end

function ClientData.Setting(name: string, default: any): any
	local profile = ClientData.Profile
	if profile and profile.Settings and profile.Settings[name] ~= nil then
		return profile.Settings[name]
	end
	return default
end

function ClientData.SetSetting(name: string, value: any)
	local profile = ClientData.Profile
	if profile and profile.Settings then
		profile.Settings[name] = value
	end
	Net.Event("SaveSettings"):FireServer({ [name] = value })
	ClientData.Changed:Fire(ClientData.Profile, ClientData.Stats)
end

function ClientData.Init(_C) end

function ClientData.Start()
	Net.Event("DataSync").OnClientEvent:Connect(function(profile, extra)
		ClientData.Profile = profile
		ClientData.Stats = extra and extra.Stats or ClientData.Stats
		ClientData.Ready = true
		ClientData.Changed:Fire(profile, ClientData.Stats)
	end)
end

return ClientData
