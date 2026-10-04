--[[
	Sieri Perduti: L'Arcipelago dei Giganti - avvio del client
	Carica i controller (rampini, combattimento, animazioni, telecamera...) e l'interfaccia.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Shared")
ReplicatedStorage:WaitForChild("Remotes")

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local ORDER = {
	{ Controllers, "ClientData" },
	{ UI, "UIController" },
	{ UI, "Notifications" },
	{ Controllers, "SoundController" },
	{ Controllers, "EffectsController" },
	{ Controllers, "CameraController" },
	{ Controllers, "InputController" },
	{ Controllers, "AnimationController" },
	{ Controllers, "TitanAnimator" },
	{ Controllers, "ODMController" },
	{ Controllers, "CombatController" },
	{ Controllers, "AmbienceController" },
	{ Controllers, "CutsceneController" },
	{ UI, "DamageNumbers" },
	{ UI, "HUD" },
	{ UI, "Menu" },
	{ UI, "Dialogue" },
	{ UI, "Shop" },
	{ UI, "Premium" },
	{ UI, "Raid" },
	{ UI, "RewardsPanel" },
	{ Controllers, "WaypointController" },
	{ UI, "Intro" },
}

local C = {}

for _, entry in ORDER do
	local folder, name = entry[1], entry[2]
	local module = folder:FindFirstChild(name)
	if module then
		local ok, result = pcall(require, module)
		if ok then
			C[name] = result
		else
			warn(("[Client] Errore nel caricare %s: %s"):format(name, tostring(result)))
		end
	else
		warn("[Client] Modulo mancante: " .. name)
	end
end

for _, entry in ORDER do
	local module = C[entry[2]]
	if module and module.Init then
		local ok, err = pcall(module.Init, C)
		if not ok then
			warn(("[Client] Errore in %s.Init: %s"):format(entry[2], tostring(err)))
		end
	end
end

for _, entry in ORDER do
	local module = C[entry[2]]
	if module and module.Start then
		task.spawn(function()
			local ok, err = xpcall(module.Start, debug.traceback)
			if not ok then
				warn(("[Client] Errore in %s.Start: %s"):format(entry[2], tostring(err)))
			end
		end)
	end
end
