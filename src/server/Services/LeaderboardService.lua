--[[
	LeaderboardService - classifiche globali (tutti i server)
	Usa le OrderedDataStore: ogni 2 minuti salva i valori dei giocatori presenti e scarica i primi 50.
	Le classifiche compaiono su tre tabelloni al Campo di Addestramento e nel Menu → Classifiche.
	In Studio senza accesso alle API mostra solo i giocatori del server.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Zones = require(Shared.Data.Zones)

local LeaderboardService = {}
local S

local REFRESH = 120
local TOP = 50

LeaderboardService.Boards = {
	{ Id = "Livello", Title = "⭐ LIVELLO", Store = "Classifica_Livello_v1", Value = function(p) return p.Level end },
	{ Id = "Giganti", Title = "⚔️ GIGANTI UCCISI", Store = "Classifica_Giganti_v1", Value = function(p) return p.Kills.Titans end },
	{ Id = "Raid", Title = "🔱 RAID VINTI", Store = "Classifica_Raid_v1", Value = function(p) return p.RaidsWon or 0 end },
}

local stores: { [string]: OrderedDataStore } = {}
local latest: { [string]: { { UserId: number, Name: string, Value: number } } } = {}
local names: { [number]: string } = {}
local signs: { [string]: { Rows: { TextLabel } } } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and name then name else ("Giocatore " .. userId)
	return names[userId]
end

local function localBoard(board)
	local rows = {}
	for _, player in Players:GetPlayers() do
		local profile = S.DataService.Get(player)
		if profile then
			table.insert(rows, { UserId = player.UserId, Name = player.DisplayName, Value = math.floor(board.Value(profile)) })
		end
	end
	table.sort(rows, function(a, b)
		return a.Value > b.Value
	end)
	return rows
end

local function pushScores()
	for _, board in LeaderboardService.Boards do
		local store = stores[board.Id]
		if store then
			for _, player in Players:GetPlayers() do
				local profile = S.DataService.Get(player)
				if profile and S.DataService.IsSaving(player) then
					local value = math.floor(board.Value(profile))
					pcall(function()
						store:SetAsync(tostring(player.UserId), value)
					end)
				end
			end
		end
	end
end

local function pullScores()
	for _, board in LeaderboardService.Boards do
		local store = stores[board.Id]
		local rows = nil
		if store then
			local ok, pages = pcall(function()
				return store:GetSortedAsync(false, TOP)
			end)
			if ok and pages then
				rows = {}
				for _, entry in pages:GetCurrentPage() do
					local userId = tonumber(entry.key)
					if userId and entry.value > 0 then
						table.insert(rows, { UserId = userId, Name = nameOf(userId), Value = entry.value })
					end
				end
			end
		end
		latest[board.Id] = rows or localBoard(board)
	end
end

-- TABELLONI NEL MONDO ------------------------------------------------------------------------

local function buildSign(board, cf: CFrame)
	local folder = workspace:FindFirstChild("Classifiche") or Instance.new("Folder")
	folder.Name = "Classifiche"
	folder.Parent = workspace
	local model = Instance.new("Model")
	model.Name = "Classifica " .. board.Id
	model.Parent = folder
	local function block(name: string, size: Vector3, offset: CFrame, material: Enum.Material, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf * offset
		p.Material = material
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local panel = block("Pannello", Vector3.new(14, 19, 1), CFrame.new(0, 13, 0), Enum.Material.WoodPlanks, Color3.fromRGB(70, 50, 34))
	block("Cornice", Vector3.new(15.4, 20.4, 0.8), CFrame.new(0, 13, 0.3), Enum.Material.Wood, Color3.fromRGB(46, 32, 22))
	for _, x in { -6.5, 6.5 } do
		block("Palo", Vector3.new(1.2, 24, 1.2), CFrame.new(x, 12, 0.6), Enum.Material.Wood, Color3.fromRGB(46, 32, 22))
	end
	block("Tettoia", Vector3.new(16.5, 0.8, 3), CFrame.new(0, 23.6, -0.6), Enum.Material.Slate, Color3.fromRGB(70, 66, 62))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = panel
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 90)
	title.Font = Enum.Font.GrenzeGotisch
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 220, 130)
	title.Text = board.Title
	title.Parent = gui
	local rows = {}
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = if i % 2 == 0 then 1 else 0.85
		row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		row.Position = UDim2.new(0, 16, 0, 96 + (i - 1) * 64)
		row.Size = UDim2.new(1, -32, 0, 60)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1 then Color3.fromRGB(255, 215, 90) elseif i == 2 then Color3.fromRGB(220, 220, 230) elseif i == 3 then Color3.fromRGB(215, 150, 90) else Color3.fromRGB(240, 230, 210)
		row.Text = ""
		row.Parent = gui
		table.insert(rows, row)
	end
	signs[board.Id] = { Rows = rows }
end

local function updateSigns()
	for _, board in LeaderboardService.Boards do
		local sign = signs[board.Id]
		local rows = latest[board.Id] or {}
		if sign then
			for i, label in sign.Rows do
				local entry = rows[i]
				label.Text = if entry then ("  %d.  %s  —  %s"):format(i, entry.Name, Util.FormatNumber(entry.Value)) else ""
			end
		end
	end
end

local function broadcast(player: Player?)
	local data = {}
	for _, board in LeaderboardService.Boards do
		data[board.Id] = latest[board.Id] or {}
	end
	if player then
		Net.Event("Leaderboards"):FireClient(player, data)
	else
		Net.Event("Leaderboards"):FireAllClients(data)
	end
end

function LeaderboardService.Init(services)
	S = services
	for _, board in LeaderboardService.Boards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(board.Store)
		end)
		if ok then
			stores[board.Id] = store
		end
	end
end

function LeaderboardService.Start()
	S.WorldBuilder.WaitReady()
	local camp = Zones.Get("CampoAddestramento")
	if camp then
		local c = camp.Center
		for i, board in LeaderboardService.Boards do
			local pos = Vector3.new(c.X - 64, c.Y, c.Z - 34 + (i - 1) * 20)
			pcall(buildSign, board, CFrame.lookAt(pos, Vector3.new(c.X, c.Y, pos.Z)))
		end
	end
	S.DataService.Loaded:Connect(function(player)
		task.delay(3, function()
			if player.Parent then
				broadcast(player)
			end
		end)
	end)
	while true do
		pushScores()
		pullScores()
		updateSigns()
		broadcast(nil)
		task.wait(REFRESH)
	end
end

return LeaderboardService
