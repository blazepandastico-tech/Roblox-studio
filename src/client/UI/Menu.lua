--[[
	Menu (tasto M)
	Schede: Equipaggiamento • Statistiche • Sieri • Storia • Traguardi • Classifiche • Codici • Impostazioni
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Lib.Net)
local Util = require(Shared.Lib.Util)
local Items = require(Shared.Data.Items)
local Serums = require(Shared.Data.Serums)
local StatsCalc = require(Shared.Data.StatsCalc)
local Story = require(Shared.Data.Story)
local Zones = require(Shared.Data.Zones)
local Bloodlines = require(Shared.Data.Bloodlines)
local Skills = require(Shared.Data.Skills)
local Achievements = require(Shared.Data.Achievements)

local Theme = require(script.Parent.Theme)
local New = Theme.New
local Colors = Theme.Colors

local Menu = {}
local C

local panel: Frame
local content: Frame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Equipaggiamento"
local selectedCategory = "Lame"
local selectedItem: string? = nil

local TABS = {
	{ Id = "Equipaggiamento", Icon = "🎒", Label = "Equip." },
	{ Id = "Statistiche", Icon = "📊", Label = "Statist." },
	{ Id = "Sieri", Icon = "💉" },
	{ Id = "Storia", Icon = "📜" },
	{ Id = "Traguardi", Icon = "🏅" },
	{ Id = "Classifiche", Icon = "🏆" },
	{ Id = "Codici", Icon = "🎁" },
	{ Id = "Impostazioni", Icon = "⚙️", Label = "Opzioni" },
}

-- classifiche ricevute dal server (aggiornate ogni 2 minuti)
local leaderboards: { [string]: { { UserId: number, Name: string, Value: number } } } = {}
local boardTab = "Livello"
local BOARDS = {
	{ Id = "Livello", Title = "⭐ Livello" },
	{ Id = "Giganti", Title = "⚔️ Giganti uccisi" },
	{ Id = "Raid", Title = "🔱 Raid vinti" },
}

local function clear()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
end

local function scroll(parent: Instance, props): ScrollingFrame
	local frame = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Colors.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	})
	for k, v in props do
		(frame :: any)[k] = v
	end
	return frame
end

local function profile()
	return C.ClientData.Profile
end

local function stats()
	return C.ClientData.Stats
end

local function itemStatsText(def): string
	local lines = {}
	if def.Damage then
		table.insert(lines, ("Danno %s"):format(Util.FormatNumber(def.Damage)))
	end
	if def.Durability then
		table.insert(lines, ("Durata %d • Ricambi %d"):format(def.Durability, def.Spares or 0))
	end
	if def.Range and def.Gas then
		table.insert(lines, ("Portata %d • Gas %d • Verricello x%.2f"):format(def.Range, def.Gas, def.Reel))
	end
	if def.Ammo then
		table.insert(lines, ("Munizioni %d • Ricarica %.1fs"):format(def.Ammo, def.Cooldown or 1))
	end
	if def.Radius then
		table.insert(lines, ("Raggio esplosione %d"):format(def.Radius))
	end
	local bonusNames = {
		HealthBonus = "Salute",
		Defense = "Difesa",
		GasEfficiency = "Efficienza gas",
		GoldBonus = "Oro",
		XPBonus = "Esperienza",
		AllDamage = "Tutti i danni",
		BladeDamage = "Danno lame",
		RangedDamage = "Danno a distanza",
		CritChance = "Critico",
		TitanPower = "Potere del gigante",
		TitanEnergy = "Energia del gigante",
		FragmentChance = "Frammenti di siero",
		ExplosiveResist = "Resistenza esplosioni",
	}
	for key, name in bonusNames do
		if type(def[key]) == "number" then
			table.insert(lines, ("+%d%% %s"):format(math.floor(def[key] * 100 + 0.5), name))
		end
	end
	return table.concat(lines, "\n")
end
Menu.ItemStatsText = itemStatsText

-- SCHEDA EQUIPAGGIAMENTO --------------------------------------------------------------------------

local function showEquipment()
	clear()
	local p = profile()
	if not p then
		return
	end
	-- slot equipaggiati
	local slots = Theme.Panel({ Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.34, -8, 1, 0), Parent = content })
	Theme.Padding(slots, 10)
	Theme.Label("Equipaggiato", { Size = UDim2.new(1, 0, 0, 24), Font = Theme.Fonts.Header, TextSize = 18, TextColor3 = Colors.Gold, Parent = slots })
	local list = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30), Parent = slots })
	New("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })
	for i, slot in Items.Slots do
		local id = p.Equipped[slot]
		local def = Items.Get(id)
		local row = Theme.Panel({ Size = UDim2.new(1, 0, 0, 58), LayoutOrder = i, Parent = list })
		Theme.Padding(row, 6)
		local bar = New("Frame", { BackgroundColor3 = if def then Items.RarityColor(def.Rarity) else Colors.PanelLight, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0), Parent = row })
		Theme.Corner(bar, 2)
		Theme.Label(Items.SlotNames[slot], { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -10, 0, 16), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = row })
		Theme.Label(if def then def.Name else "— vuoto —", { Position = UDim2.fromOffset(10, 18), Size = UDim2.new(1, -10, 0, 30), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = if def then Items.RarityColor(def.Rarity) else Colors.TextDim, Parent = row })
	end
	local s = stats()
	if s then
		Theme.Label(("⚔️ Danno lame: %s\n🎯 Danno a distanza: %s\n❤️ Salute: %s  🛡️ Difesa: %d%%\n💥 Critico: %d%%  ⚙️ Portata rampini: %d"):format(Util.Abbreviate(s.BladeDamage), Util.Abbreviate(s.RangedDamage), Util.Abbreviate(s.MaxHealth), math.floor(s.Defense * 100), math.floor(s.CritChance * 100), s.ODMRange), {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 96),
			Font = Theme.Fonts.UI,
			TextSize = 13,
			Parent = slots,
		})
	end

	-- inventario
	local right = New("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.34, 8, 0, 0), Size = UDim2.new(0.66, -8, 1, 0), Parent = content })
	local cats = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = right })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = cats })
	for i, catId in Items.CategoryOrder do
		local cat = Items.Categories[catId]
		local b = Theme.Button(cat.Icon, { Size = UDim2.fromOffset(46, 34), TextSize = 18, LayoutOrder = i, Parent = cats }, function()
			selectedCategory = catId
			selectedItem = nil
			showEquipment()
		end)
		if catId == selectedCategory then
			b.BackgroundColor3 = Colors.Green
		end
	end
	Theme.Label(Items.Categories[selectedCategory].Name, { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 22), Font = Theme.Fonts.Header, TextSize = 16, TextColor3 = Colors.Gold, Parent = right })
	local grid = scroll(right, { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0.62, -62) })
	New("UIGridLayout", { CellSize = UDim2.fromOffset(150, 70), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local owned = Items.Sorted(function(def)
		return def.Category == selectedCategory and (p.Inventory[def.Id] or 0) > 0
	end)
	for i, def in owned do
		local equipped = false
		for _, slot in Items.Slots do
			if p.Equipped[slot] == def.Id then
				equipped = true
			end
		end
		local card = Theme.Button("", { Size = UDim2.fromOffset(150, 70), LayoutOrder = i, Parent = grid }, function()
			selectedItem = def.Id
			showEquipment()
		end)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Items.RarityColor(def.Rarity)
		end
		Theme.Label(def.Name, { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 34), Font = Theme.Fonts.Bold, TextSize = 13, TextColor3 = Items.RarityColor(def.Rarity), Parent = card })
		local count = p.Inventory[def.Id] or 0
		Theme.Label((if equipped then "✔ Equipaggiato" else Items.Rarities[def.Rarity].Label) .. (if count > 1 then ("  x%d"):format(count) else ""), { Position = UDim2.fromOffset(6, 46), Size = UDim2.new(1, -12, 0, 18), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = if equipped then Colors.GreenBright else Colors.TextDim, Parent = card })
	end
	if #owned == 0 then
		Theme.Label("Non possiedi oggetti di questa categoria. Visita le armerie, sconfiggi i boss o usa il Laboratorio!", { Size = UDim2.new(1, 0, 0, 60), TextColor3 = Colors.TextDim, Parent = grid })
	end

	-- dettagli dell'oggetto selezionato
	local details = Theme.Panel({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0.38, -6), Parent = right })
	Theme.Padding(details, 10)
	local def = Items.Get(selectedItem)
	if def then
		Theme.Label(def.Name, { Size = UDim2.new(0.6, 0, 0, 24), Font = Theme.Fonts.Header, TextSize = 18, TextColor3 = Items.RarityColor(def.Rarity), Parent = details })
		Theme.Label(("%s • Livello %d"):format(Items.Rarities[def.Rarity].Label, def.LevelReq or 1), { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(0.6, 0, 0, 18), Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.TextDim, Parent = details })
		Theme.Label(def.Description or "", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(0.6, 0, 1, -44), Font = Theme.Fonts.Body, TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
		Theme.Label(itemStatsText(def), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.38, 0, 1, -44), Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.GreenBright, TextYAlignment = Enum.TextYAlignment.Top, Parent = details })
		if Items.IsEquipment(def.Id) then
			Theme.Button("Equipaggia", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(140, 36), BackgroundColor3 = Colors.Green, Parent = details }, function()
				Net.Event("Equip"):FireServer(def.Id)
			end)
		elseif def.Category == "Consumabile" then
			Theme.Button("Usa", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(140, 36), BackgroundColor3 = Colors.Green, Parent = details }, function()
				Net.Event("UseItem"):FireServer(def.Id)
			end)
		end
	else
		Theme.Label("Seleziona un oggetto per vederne i dettagli.", { Size = UDim2.fromScale(1, 1), TextColor3 = Colors.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Parent = details })
	end
end

-- SCHEDA STATISTICHE -----------------------------------------------------------------------------

local function showStats()
	clear()
	local p = profile()
	local s = stats()
	if not p then
		return
	end
	local bloodline = Bloodlines.Get(p.Bloodline)
	local header = Theme.Panel({ Size = UDim2.new(1, 0, 0, 74), Parent = content })
	Theme.Padding(header, 10)
	Theme.Label(("Punti da assegnare: %d"):format(p.StatPoints), { Size = UDim2.new(0.5, 0, 0, 26), Font = Theme.Fonts.Header, TextSize = 20, TextColor3 = if p.StatPoints > 0 then Colors.GreenBright else Colors.Text, Parent = header })
	Theme.Label(("Stirpe: %s — %s"):format(bloodline.Name, bloodline.Description), { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 34), Font = Theme.Fonts.Body, TextSize = 13, TextColor3 = bloodline.Color, Parent = header })
	local list = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(0.62, 0, 1, -84), Parent = content })
	New("UIListLayout", { Padding = UDim.new(0, 8), Parent = list })
	for i, statName in StatsCalc.StatNames do
		local info = StatsCalc.StatInfo[statName]
		local row = Theme.Panel({ Size = UDim2.new(1, 0, 0, 62), LayoutOrder = i, Parent = list })
		Theme.Padding(row, 8)
		Theme.Label(("%s %s"):format(info.Icon, info.Name), { Size = UDim2.new(0.5, 0, 0, 22), Font = Theme.Fonts.Bold, TextSize = 16, Parent = row })
		Theme.Label(info.Description, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(0.55, 0, 0, 22), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = row })
		Theme.Label(Util.FormatNumber(p.Stats[statName] or 0) .. " / " .. Config.StatCap, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4 * 54, 0, 8), Size = UDim2.fromOffset(110, 26), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Number, TextSize = 20, TextColor3 = Colors.GoldBright, Parent = row })
		for j, amount in { 1, 10, 100, "max" } do
			Theme.Button(if amount == "max" then "MAX" else "+" .. amount, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -(4 - j) * 54, 0.5, 0),
				Size = UDim2.fromOffset(50, 34),
				TextSize = 13,
				Parent = row,
			}, function()
				Net.Event("AllocateStat"):FireServer(statName, amount)
			end)
		end
	end
	if s then
		local summary = Theme.Panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 84), Size = UDim2.new(0.36, 0, 1, -84), Parent = content })
		Theme.Padding(summary, 10)
		Theme.Label("Riepilogo", { Size = UDim2.new(1, 0, 0, 24), Font = Theme.Fonts.Header, TextSize = 18, TextColor3 = Colors.Gold, Parent = summary })
		local lines = {
			("❤️ Salute massima: %s"):format(Util.FormatNumber(s.MaxHealth)),
			("🛡️ Difesa: %d%%"):format(math.floor(s.Defense * 100)),
			("⚔️ Danno lame: %s"):format(Util.FormatNumber(s.BladeDamage)),
			("⭐ Maestria lame: %d / %d"):format(math.floor(s.BladeMastery or 0), Config.Serums.MaxMastery),
			("🎯 Danno a distanza: %s"):format(Util.FormatNumber(s.RangedDamage)),
			("💥 Critico: %d%%"):format(math.floor(s.CritChance * 100)),
			("⚙️ Portata rampini: %d"):format(s.ODMRange),
			("💨 Gas: %d  (efficienza x%.2f)"):format(s.ODMGas, s.GasEfficiency),
			("🚀 Potenza verricello: x%.2f"):format(s.ODMReel),
			("💉 Potere del gigante: x%.2f"):format(s.TitanPower),
			("📈 Bonus esperienza: +%d%%"):format(math.floor(s.XPBonus * 100)),
			("💰 Bonus oro: +%d%%"):format(math.floor(s.GoldBonus * 100)),
		}
		Theme.Label(table.concat(lines, "\n"), { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30), Font = Theme.Fonts.UI, TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top, Parent = summary })
	end
end

-- SCHEDA SIERI --------------------------------------------------------------------------------------

local confirmSerum: string? = nil

-- Anteprima degli Otto Giganti finché i sieri non sono disponibili
local function showSerumsComingSoon(p)
	local left = Theme.Panel({ Size = UDim2.new(0.42, -6, 1, 0), Parent = content })
	Theme.Padding(left, 14)
	Theme.Label("Gli Otto Giganti", { Size = UDim2.new(1, 0, 0, 36), Font = Theme.Fonts.Title, TextSize = 34, TextColor3 = Colors.GoldBright, Parent = left })
	Theme.Label("🔒 PROSSIMO AGGIORNAMENTO", { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 22), Font = Theme.Fonts.Bold, TextSize = 16, TextColor3 = Colors.RedBright, Parent = left })
	Theme.Label(Config.Serums.ComingSoonText .. "\n\nGli otto Sieri Perduti ti permetteranno di trasformarti in un gigante mutaforma, con quattro abilità ciascuno e una maestria da far crescere.\n\nPreparati già da ora: i 💠 Frammenti di Siero che trovi uccidendo giganti (soprattutto anomali, boss e raid) restano nel tuo inventario e serviranno per sintetizzare i sieri al Laboratorio.", {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 1, -110),
		Font = Theme.Fonts.Body,
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = left,
	})
	Theme.Label(("💠 Frammenti raccolti: %s"):format(Util.FormatNumber(p.Inventory.FrammentoSiero or 0)), { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 26), Font = Theme.Fonts.Bold, TextSize = 16, TextColor3 = Colors.Gold, Parent = left })

	local right = Theme.Panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.58, -6, 1, 0), Parent = content })
	Theme.Padding(right, 10)
	local list = scroll(right, { Size = UDim2.fromScale(1, 1) })
	New("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 118), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	for i, id in Serums.Order do
		local serum = Serums.List[id]
		local color = Items.RarityColor(serum.Rarity)
		local card = Theme.Panel({ LayoutOrder = i, BackgroundColor3 = Colors.Background, Parent = list })
		Theme.Padding(card, 8)
		Theme.Label("🔒 " .. serum.TitanName, { Size = UDim2.new(1, 0, 0, 22), Font = Theme.Fonts.Header, TextSize = 16, TextColor3 = color, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = card })
		Theme.Label(("%s • %d m • Lv. %d"):format(Items.Rarities[serum.Rarity] and Items.Rarities[serum.Rarity].Label or serum.Rarity, serum.Height, serum.LevelReq), { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 16), Font = Theme.Fonts.UI, TextSize = 11, TextColor3 = Colors.TextDim, Parent = card })
		local names = {}
		for _, key in { "Z", "X", "C", "V" } do
			table.insert(names, ("[%s] %s"):format(key, serum.Skills[key].Name))
		end
		Theme.Label(table.concat(names, "\n"), { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), Font = Theme.Fonts.UI, TextSize = 11, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	end
end

local function showSerums()
	clear()
	local p = profile()
	if not p then
		return
	end
	if not Config.Serums.Available then
		showSerumsComingSoon(p)
		return
	end
	local active = Serums.Get(p.Serum)
	local left = Theme.Panel({ Size = UDim2.new(0.5, -6, 1, 0), Parent = content })
	Theme.Padding(left, 12)
	if active then
		local mastery = p.SerumMastery[active.Id] or 0
		Theme.Label("Potere attivo", { Size = UDim2.new(1, 0, 0, 20), Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.TextDim, Parent = left })
		Theme.Label(active.TitanName, { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 34), Font = Theme.Fonts.Title, TextSize = 32, TextColor3 = Items.RarityColor(active.Rarity), Parent = left })
		Theme.Label(("%s • Altezza %dm • Maestria %d/%d"):format(Items.Rarities[active.Rarity].Label, math.floor(active.Height / 3.2), mastery, Config.Serums.MaxMastery), { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 18), Font = Theme.Fonts.UI, TextSize = 13, Parent = left })
		Theme.Label("Passiva: " .. active.Passive, { Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 36), Font = Theme.Fonts.Body, TextSize = 13, TextColor3 = Colors.GreenBright, Parent = left })
		local list = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 1, -150), Parent = left })
		New("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })
		for i, key in Skills.Order do
			local skill = active.Skills[key]
			if skill then
				local unlocked = mastery >= skill.Mastery
				local row = Theme.Panel({ Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i, Parent = list })
				Theme.Padding(row, 6)
				Theme.Label(("[%s] %s%s"):format(key, skill.Name, if unlocked then "" else ("  🔒 maestria %d"):format(skill.Mastery)), { Size = UDim2.new(1, 0, 0, 18), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = if unlocked then Colors.Text else Colors.TextDim, Parent = row })
				Theme.Label(skill.Description .. (" (ricarica %ds, energia %d)"):format(skill.Cooldown, skill.Energy or 0), { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 26), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = row })
			end
		end
		Theme.Label("Premi T per trasformarti. L'energia cala nel tempo e con le abilità.", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 24), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.Gold, Parent = left })
	else
		Theme.Label("Nessun siero iniettato", { Size = UDim2.new(1, 0, 0, 30), Font = Theme.Fonts.Title, TextSize = 28, TextColor3 = Colors.TextDim, Parent = left })
		Theme.Label("I Sieri Perduti sono rarissimi. Puoi ottenerli:\n\n• 💼 Casse 'Siero Perduto' che appaiono a caso nel mondo (circa una ogni 2 ore)\n• 👑 Drop rarissimi dai boss mutaforma (0,5% - 1,2%)\n• 🧥 Il Mercante Velato a Aurion (merce che cambia ogni 4 ore)\n• 🧪 Il Laboratorio della Dott.ssa Morrow, con centinaia di Frammenti di Siero\n\nI frammenti si trovano uccidendo giganti (soprattutto anomali e boss).", {
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 1, -40),
			Font = Theme.Fonts.Body,
			TextSize = 14,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = left,
		})
	end

	local right = Theme.Panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), Parent = content })
	Theme.Padding(right, 12)
	Theme.Label(("Valigetta dei sieri  •  Frammenti: %d"):format(p.Inventory.FrammentoSiero or 0), { Size = UDim2.new(1, 0, 0, 24), Font = Theme.Fonts.Header, TextSize = 17, TextColor3 = Colors.Gold, Parent = right })
	local list = scroll(right, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30) })
	New("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })
	local any = false
	for i, id in Serums.Order do
		local count = p.StoredSerums[id] or 0
		if count > 0 then
			any = true
			local serum = Serums.List[id]
			local row = Theme.Panel({ Size = UDim2.new(1, -8, 0, 70), LayoutOrder = i, Parent = list })
			Theme.Padding(row, 8)
			Theme.Label(("%s  x%d"):format(serum.Name, count), { Size = UDim2.new(1, -130, 0, 20), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Items.RarityColor(serum.Rarity), Parent = row })
			Theme.Label(("Livello richiesto: %d • %s"):format(serum.LevelReq, serum.Description), { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -130, 0, 34), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = row })
			local confirming = confirmSerum == id
			Theme.Button(if confirming then "Conferma!" else "💉 Inietta", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(120, 40), BackgroundColor3 = if confirming then Colors.Red else Colors.Green, Parent = row }, function()
				if confirmSerum == id then
					confirmSerum = nil
					Net.Event("InjectSerum"):FireServer(id)
					C.UIController.Close("Menu")
				else
					confirmSerum = id
					C.Notifications.Toast(if active then "Attenzione: il potere attuale verrà perso! Premi di nuovo per confermare." else "Premi di nuovo per confermare l'iniezione.", "Info", 3)
					showSerums()
				end
			end)
		end
	end
	if not any then
		Theme.Label("La valigetta è vuota. Continua a cacciare...", { Size = UDim2.new(1, 0, 0, 40), TextColor3 = Colors.TextDim, Parent = list })
	end
end

-- SCHEDA STORIA ---------------------------------------------------------------------------------------

local function showStory()
	clear()
	local p = profile()
	if not p then
		return
	end
	local list = scroll(content, { Size = UDim2.fromScale(1, 1) })
	New("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })
	local lastSeason = 0
	for i, chapter in Story.Chapters do
		if chapter.Season ~= lastSeason then
			lastSeason = chapter.Season
			Theme.Label(Zones.SeasonNames[chapter.Season], { Size = UDim2.new(1, -8, 0, 30), Font = Theme.Fonts.Title, TextSize = 24, TextColor3 = Colors.GoldBright, LayoutOrder = i * 10, Parent = list })
		end
		local done = p.Story.Done or i < p.Story.Chapter
		local current = not p.Story.Done and i == p.Story.Chapter
		local row = Theme.Panel({ Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i * 10 + 1, Parent = list })
		Theme.Padding(row, 8)
		New("UIListLayout", { Padding = UDim.new(0, 2), Parent = row })
		local status = if done then "✔ " elseif current then "▶ " else "🔒 "
		Theme.Label(status .. chapter.Title .. ("  (Lv. %d+)"):format(chapter.Level), { Size = UDim2.new(1, 0, 0, 20), Font = Theme.Fonts.Bold, TextSize = 15, TextColor3 = if current then Colors.GoldBright elseif done then Colors.GreenBright else Colors.TextDim, Parent = row })
		if done or current then
			Theme.Label(chapter.Summary, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Theme.Fonts.Body, TextSize = 13, Parent = row })
		end
		if current then
			local step = chapter.Steps[p.Story.Step]
			if step then
				Theme.Label(("Obiettivo (%d/%d): %s"):format(p.Story.Step, #chapter.Steps, step.Objective), { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.XP, Parent = row })
			end
		end
	end
end

-- SCHEDA TRAGUARDI ------------------------------------------------------------------------------------

local function showAchievements()
	clear()
	local p = profile()
	if not p then
		return
	end
	local done = 0
	for _, a in Achievements.List do
		if p.Achievements and p.Achievements[a.Id] then
			done += 1
		end
	end
	Theme.Label(("Traguardi completati: %d / %d  •  ogni traguardo regala gemme 💎"):format(done, #Achievements.List), { Size = UDim2.new(1, 0, 0, 26), Font = Theme.Fonts.Header, TextSize = 17, TextColor3 = Colors.GoldBright, Parent = content })
	local list = scroll(content, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32) })
	New("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0, 74), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local extra = { Friends = C.ClientData.Profile and (game:GetService("Players").LocalPlayer:GetAttribute("FriendsHere") or 0) or 0 }
	for i, a in Achievements.List do
		local unlocked = p.Achievements and p.Achievements[a.Id] ~= nil
		local value = math.min(Achievements.Value(p, a.Stat, extra), a.Goal)
		local card = Theme.Panel({ LayoutOrder = if unlocked then 1000 + i else i, BackgroundColor3 = if unlocked then Color3.fromRGB(30, 46, 32) else Colors.Background, Parent = list })
		Theme.Padding(card, 8)
		Theme.Label(if unlocked then "✔" else a.Icon, { Size = UDim2.fromOffset(50, 56), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 34, TextColor3 = Colors.GreenBright, Parent = card })
		Theme.Label(a.Name, { Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -130, 0, 20), Font = Theme.Fonts.Bold, TextSize = 15, TextColor3 = if unlocked then Colors.GreenBright else Colors.Text, Parent = card })
		Theme.Label(a.Description, { Position = UDim2.fromOffset(56, 20), Size = UDim2.new(1, -130, 0, 18), Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = card })
		Theme.Label(("+%d 💎"):format(a.Gems), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(70, 20), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Color3.fromRGB(140, 220, 255), Parent = card })
		local _, setBar = Theme.Bar({ Position = UDim2.fromOffset(56, 44), Size = UDim2.new(1, -130, 0, 10), Parent = card }, if unlocked then Colors.GreenBright else Colors.Gold)
		setBar(if unlocked then 1 else value / a.Goal, true)
		Theme.Label(if unlocked then "Completato" else ("%s / %s"):format(Util.FormatNumber(value), Util.FormatNumber(a.Goal)), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 40), Size = UDim2.fromOffset(70, 18), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.UI, TextSize = 12, TextColor3 = Colors.TextDim, Parent = card })
	end
end

-- SCHEDA CLASSIFICHE -----------------------------------------------------------------------------------

local function showLeaderboards()
	clear()
	local localPlayer = game:GetService("Players").LocalPlayer
	local bar = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = content })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = bar })
	for i, board in BOARDS do
		Theme.Button(board.Title, { Size = UDim2.fromOffset(200, 36), TextSize = 15, LayoutOrder = i, BackgroundColor3 = if board.Id == boardTab then Colors.Green else Colors.PanelLight, Parent = bar }, function()
			boardTab = board.Id
			showLeaderboards()
		end)
	end
	Theme.Label("Classifica di TUTTI i server • si aggiorna ogni 2 minuti • i primi 3 compaiono anche sui tabelloni del Campo", { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 20), Font = Theme.Fonts.UI, TextSize = 13, TextColor3 = Colors.TextDim, Parent = content })
	local list = scroll(content, { Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 1, -68) })
	New("UIListLayout", { Padding = UDim.new(0, 3), Parent = list })
	local rows = leaderboards[boardTab] or {}
	if #rows == 0 then
		Theme.Label("Caricamento della classifica...", { Size = UDim2.new(1, 0, 0, 30), Font = Theme.Fonts.UI, TextSize = 15, Parent = list })
	end
	local medals = { "🥇", "🥈", "🥉" }
	for i, entry in rows do
		local mine = entry.UserId == localPlayer.UserId
		local row = Theme.Panel({ Size = UDim2.new(1, -10, 0, 34), LayoutOrder = i, BackgroundColor3 = if mine then Color3.fromRGB(60, 50, 24) else Colors.Background, Parent = list })
		Theme.Label(medals[i] or ("%d."):format(i), { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(50, 34), Font = Theme.Fonts.Bold, TextSize = if medals[i] then 22 else 16, Parent = row })
		Theme.Label(entry.Name .. (if mine then "  (tu)" else ""), { Position = UDim2.fromOffset(64, 0), Size = UDim2.new(1, -220, 1, 0), Font = Theme.Fonts.Bold, TextSize = 16, TextColor3 = if i <= 3 then Colors.GoldBright else Colors.Text, Parent = row })
		Theme.Label(Util.FormatNumber(entry.Value), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(150, 34), TextXAlignment = Enum.TextXAlignment.Right, Font = Theme.Fonts.Number, TextSize = 20, Parent = row })
	end
end

-- SCHEDA CODICI ------------------------------------------------------------------------------------------

local function showCodes()
	clear()
	local box = Theme.Panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(460, 190), Parent = content })
	Theme.Padding(box, 14)
	Theme.Label("Riscatta un codice", { Size = UDim2.new(1, 0, 0, 28), Font = Theme.Fonts.Header, TextSize = 20, TextColor3 = Colors.Gold, Parent = box })
	local input = New("TextBox", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Colors.Background,
		TextColor3 = Colors.Text,
		PlaceholderText = "Scrivi qui il codice...",
		PlaceholderColor3 = Colors.TextDim,
		Font = Theme.Fonts.Bold,
		TextSize = 18,
		ClearTextOnFocus = false,
		Text = "",
		Parent = box,
	})
	Theme.Corner(input, 8)
	Theme.Stroke(input, Colors.Border, 1, 0.3)
	local result = Theme.Label("Suggerimento: prova SIERIPERDUTI", { Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 22), Font = Theme.Fonts.UI, TextSize = 14, TextColor3 = Colors.TextDim, Parent = box })
	Theme.Button("Riscatta", { Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Colors.Green, Parent = box }, function()
		local ok, okResult, message = pcall(function()
			return Net.Function("RedeemCode"):InvokeServer(input.Text)
		end)
		if ok then
			result.Text = message or ""
			result.TextColor3 = if okResult then Colors.GreenBright else Colors.RedBright
		else
			result.Text = "Errore di connessione, riprova."
			result.TextColor3 = Colors.RedBright
		end
	end)
end

-- SCHEDA IMPOSTAZIONI -------------------------------------------------------------------------------

local function showSettings()
	clear()
	local list = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 1, 0), Parent = content })
	New("UIListLayout", { Padding = UDim.new(0, 8), Parent = list })
	local toggles = {
		{ Key = "Shake", Name = "Scossa della telecamera" },
		{ Key = "SpeedLines", Name = "Linee di velocità" },
		{ Key = "DamageNumbers", Name = "Numeri dei danni" },
		{ Key = "Scenery", Name = "Dettagli ambientali (natura e cittadini)" },
	}
	for i, t in toggles do
		local on = C.ClientData.Setting(t.Key, true)
		local row = Theme.Panel({ Size = UDim2.new(1, 0, 0, 50), LayoutOrder = i, Parent = list })
		Theme.Padding(row, 8)
		Theme.Label(t.Name, { Size = UDim2.new(0.7, 0, 1, 0), Font = Theme.Fonts.Bold, TextSize = 15, Parent = row })
		Theme.Button(if on then "ATTIVO" else "SPENTO", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(110, 34), BackgroundColor3 = if on then Colors.Green else Colors.Red, Parent = row }, function()
			C.ClientData.SetSetting(t.Key, not on)
			showSettings()
		end)
	end
	local sliders = { { Key = "Sfx", Name = "Volume effetti", Default = 0.8 }, { Key = "Music", Name = "Volume musica", Default = 0.5 } }
	for i, sl in sliders do
		local value = C.ClientData.Setting(sl.Key, sl.Default)
		local row = Theme.Panel({ Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 10 + i, Parent = list })
		Theme.Padding(row, 8)
		Theme.Label(("%s: %d%%"):format(sl.Name, math.floor(value * 100 + 0.5)), { Size = UDim2.new(0.6, 0, 1, 0), Font = Theme.Fonts.Bold, TextSize = 15, Parent = row })
		Theme.Button("−", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -60, 0.5, 0), Size = UDim2.fromOffset(50, 34), TextSize = 20, Parent = row }, function()
			C.ClientData.SetSetting(sl.Key, math.max(0, Util.Round(value - 0.1, 1)))
			showSettings()
		end)
		Theme.Button("+", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(50, 34), TextSize = 20, Parent = row }, function()
			C.ClientData.SetSetting(sl.Key, math.min(1, Util.Round(value + 0.1, 1)))
			showSettings()
		end)
	end
	local help = Theme.Panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.38, 0, 1, 0), Parent = content })
	Theme.Padding(help, 12)
	Theme.Label("Comandi", { Size = UDim2.new(1, 0, 0, 24), Font = Theme.Fonts.Header, TextSize = 18, TextColor3 = Colors.Gold, Parent = help })
	Theme.Label("Q / E — rampino sinistro / destro (tieni premuto)\nSpazio — salto / getto di gas\nWASD — muoviti e correggi il volo\nShift — attiva/disattiva lo shift lock\nCtrl — schivata\nBloc Maiusc — cammina / corri\nClic sinistro — fendente\nClic destro — arma a distanza\nZ X C V — abilità\nR — sostituisci le lame\nT — trasformazione in gigante\nG — Risveglio Valkar\nF — interagisci\nM — menu\nAlt — sblocca il cursore", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		Font = Theme.Fonts.UI,
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = help,
	})
end

local RENDER = {
	Equipaggiamento = showEquipment,
	Statistiche = showStats,
	Sieri = showSerums,
	Storia = showStory,
	Traguardi = showAchievements,
	Classifiche = showLeaderboards,
	Codici = showCodes,
	Impostazioni = showSettings,
}

local function render()
	for id, button in tabButtons do
		button.BackgroundColor3 = if id == currentTab then Colors.Green else Colors.PanelLight
	end
	local fn = RENDER[currentTab]
	if fn then
		local ok, err = pcall(fn)
		if not ok then
			warn("[Menu] " .. tostring(err))
		end
	end
end

function Menu.OpenTab(tab: string)
	currentTab = tab
	if not C.UIController.IsOpen("Menu") then
		C.UIController.Open("Menu")
	else
		render()
	end
end

function Menu.Init(c)
	C = c
end

function Menu.Start()
	panel = Theme.Panel({ Name = "Menu", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(980, 620), Parent = C.UIController.Layers.Panels })
	Theme.Padding(panel, 14)
	Theme.Label(Config.GameName, { Size = UDim2.new(1, -60, 0, 32), Font = Theme.Fonts.Title, TextSize = 30, TextColor3 = Colors.GoldBright, Parent = panel })
	Theme.Button("✕", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(36, 32), TextSize = 18, Parent = panel }, function()
		C.UIController.Close("Menu")
	end)
	local tabs = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 38), Parent = panel })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = tabs })
	for i, tab in TABS do
		tabButtons[tab.Id] = Theme.Button(tab.Icon .. " " .. (tab.Label or tab.Id), { Size = UDim2.new(1 / #TABS, -6, 1, 0), TextSize = 13, LayoutOrder = i, Parent = tabs }, function()
			currentTab = tab.Id
			render()
		end)
	end
	content = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 1, -88), Parent = panel })
	C.UIController.RegisterPanel("Menu", panel, render, function()
		confirmSerum = nil
	end)
	C.InputController.On("Menu", function(began)
		if began then
			C.UIController.Toggle("Menu")
		end
	end)
	C.ClientData.Changed:Connect(function()
		if C.UIController.IsOpen("Menu") then
			render()
		end
	end)
	Net.Event("Leaderboards").OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			leaderboards = data
			if C.UIController.IsOpen("Menu") and currentTab == "Classifiche" then
				render()
			end
		end
	end)
end

return Menu
