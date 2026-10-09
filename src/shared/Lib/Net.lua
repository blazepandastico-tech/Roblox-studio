--[[
	Net
	Crea (sul server) e recupera (sul client) tutti i RemoteEvent / RemoteFunction.
	Usare sempre i nomi elencati qui sotto: così client e server restano allineati.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Eventi affidabili (client <-> server)
Net.EventNames = {
	-- client -> server
	"ClientReady",
	"Attack",
	"Skill",
	"SkillHit",
	"Ranged",
	"Dodge",
	"ReloadBlades",
	"Equip",
	"Unequip",
	"AllocateStat",
	"UseItem",
	"DialogueChoice",
	"ShopBuy",
	"Craft",
	"InjectSerum",
	"Transform",
	"TitanSkill",
	"Awaken",
	"EscapeMash",
	"Travel",
	"CutsceneDone",
	"AbandonQuest",
	"SaveSettings",
	"PremiumBuy",
	"FastTravel",
	"ClaimReward",
	"SpinWheel",
	"CommunityAction",
	"AdminAction",
	"Horse",
	"PvPToggle",
	"TutorialProgress",
	"TutorialDone",
	"TutorialReplay",
	-- server -> client
	"Tutorial",
	"PvPState",
	"RaidState",
	"WheelResult",
	"Leaderboards",
	"Achievement",
	"DataSync",
	"Notify",
	"Announce",
	"Effect",
	"DamageNumber",
	"Dialogue",
	"ShopOpen",
	"Cutscene",
	"BossBar",
	"Grab",
	"Knockback",
	"LevelUp",
	"HitConfirm",
	"TitanForm",
	"Refilled",
	"ODMCorrect",
	-- in entrambe le direzioni
	"ODM",
}

-- Eventi "inaffidabili": arrivano più velocemente ma possono perdersi
-- (perfetti per animazioni ed effetti cosmetici).
Net.UnreliableNames = {
	"AnimRelay",
	"EffectFast",
}

Net.FunctionNames = {
	"RedeemCode",
}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		local created: Folder = if existing and existing:IsA("Folder") then existing else Instance.new("Folder")
		created.Name = "Remotes"
		for _, name in Net.EventNames do
			if not created:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = created
			end
		end
		for _, name in Net.UnreliableNames do
			if not created:FindFirstChild(name) then
				local remote = Instance.new("UnreliableRemoteEvent")
				remote.Name = name
				remote.Parent = created
			end
		end
		for _, name in Net.FunctionNames do
			if not created:FindFirstChild(name) then
				local remote = Instance.new("RemoteFunction")
				remote.Name = name
				remote.Parent = created
			end
		end
		created.Parent = ReplicatedStorage
		folder = created
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return folder :: Folder
end

function Net.Init()
	getFolder()
end

function Net.Event(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Net.Unreliable(name: string): UnreliableRemoteEvent
	return getFolder():WaitForChild(name) :: UnreliableRemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Net
