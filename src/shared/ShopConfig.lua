-- Configurazione dello shop: modifica QUI tab, oggetti, prezzi e colori.
local Config = {}

-- true = gli acquisti sono SIMULATI (nessun Robux speso) cosi puoi provare tutto.
-- Quando metti ProductId veri, quelli useranno MarketplaceService.
Config.TestMode = true

-- Incolla qui l'asset id dell'icona del cestino (es. "rbxassetid://123456789").
-- Se vuoto viene usata un'emoji al suo posto.
Config.ShopIconImage = ""

-- Secondi del timer del regalo nel menu (2:46 = 166)
Config.GiftSeconds = 166

-- Tab in alto (la prima e quella che si apre per default)
Config.Tabs = {
	{ Id = "Luck", Icon = "❄️", Color = Color3.fromRGB(41, 128, 255) },
	{ Id = "Power", Icon = "💪", Color = Color3.fromRGB(255, 196, 30) },
	{ Id = "Trophies", Icon = "🏆", Color = Color3.fromRGB(255, 170, 30) },
	{ Id = "Pets", Icon = "🔴", Color = Color3.fromRGB(40, 200, 90) },
}

local GREEN = Color3.fromRGB(58, 214, 40)
local PURPLE = Color3.fromRGB(150, 50, 230)
local YELLOW = Color3.fromRGB(255, 196, 20)
local BLUE = Color3.fromRGB(140, 200, 245)
local RED = Color3.fromRGB(255, 70, 70)
local ORANGE = Color3.fromRGB(255, 140, 30)
local PINK = Color3.fromRGB(255, 100, 190)
local TEAL = Color3.fromRGB(30, 190, 200)

-- Ogni tab ha 5 oggetti: i primi 3 stanno nella riga sopra, gli altri 2 (larghi) sotto.
-- Reward = { Attribute = "Nome", Add = numero } viene sommato come attributo del Player.
-- ProductId = 0 -> acquisto finto (TestMode). Metti l'ID del Developer Product per quello vero.
Config.Items = {
	-- LUCK
	{ Id = "Lucky", Tab = "Luck", Name = "Lucky", Desc = "Permanently gain better luck!", Price = 199, Color = GREEN, ProductId = 0, Reward = { Attribute = "Luck", Add = 1 } },
	{ Id = "UltraLucky", Tab = "Luck", Name = "ULTRA Lucky", Desc = "Permanently gain outrageous luck!", Price = 199, Color = PURPLE, Tag = "HOT!", ProductId = 0, Reward = { Attribute = "Luck", Add = 5 } },
	{ Id = "SuperLucky", Tab = "Luck", Name = "Super Lucky", Desc = "Permanently gain even better luck!", Price = 199, Color = YELLOW, ProductId = 0, Reward = { Attribute = "Luck", Add = 3 } },
	{ Id = "DoubleCash", Tab = "Luck", Name = "2x Cash", Desc = "Double all your coins, forever!", Icon = "💰", Price = 199, Color = BLUE, ProductId = 0, Reward = { Attribute = "CashMultiplier", Add = 1 } },
	{ Id = "VIP", Tab = "Luck", Name = "VIP", Desc = "Golden name, chat tag & perks!", Icon = "👑", Price = 199, Color = BLUE, Tag = "BEST", ProductId = 0, Reward = { Attribute = "VIP", Add = 1 } },

	-- POWER
	{ Id = "Strong", Tab = "Power", Name = "Strong", Desc = "Permanently gain more power!", Price = 99, Color = RED, ProductId = 0, Reward = { Attribute = "Power", Add = 1 } },
	{ Id = "MegaStrong", Tab = "Power", Name = "MEGA Strong", Desc = "Permanently gain huge power!", Price = 249, Color = ORANGE, Tag = "-20%", ProductId = 0, Reward = { Attribute = "Power", Add = 5 } },
	{ Id = "Speed", Tab = "Power", Name = "Speed Boost", Desc = "Run faster, forever!", Price = 149, Color = TEAL, ProductId = 0, Reward = { Attribute = "Speed", Add = 1 } },
	{ Id = "AutoTrain", Tab = "Power", Name = "Auto Train", Desc = "Train even while you rest!", Icon = "⚙️", Price = 399, Color = BLUE, ProductId = 0, Reward = { Attribute = "AutoTrain", Add = 1 } },
	{ Id = "GiantFists", Tab = "Power", Name = "Giant Fists", Desc = "Hit twice as hard!", Icon = "🥊", Price = 299, Color = BLUE, ProductId = 0, Reward = { Attribute = "Fists", Add = 1 } },

	-- TROPHIES
	{ Id = "Bronze", Tab = "Trophies", Name = "Bronze Cup", Desc = "A shiny start for champions!", Price = 49, Color = ORANGE, ProductId = 0, Reward = { Attribute = "Trophies", Add = 1 } },
	{ Id = "Silver", Tab = "Trophies", Name = "Silver Cup", Desc = "Show off your skills!", Price = 99, Color = Color3.fromRGB(170, 190, 215), ProductId = 0, Reward = { Attribute = "Trophies", Add = 2 } },
	{ Id = "Gold", Tab = "Trophies", Name = "Gold Cup", Desc = "Only for true legends!", Price = 199, Color = YELLOW, Tag = "NEW", ProductId = 0, Reward = { Attribute = "Trophies", Add = 5 } },
	{ Id = "Crown", Tab = "Trophies", Name = "Royal Crown", Desc = "Wear it with pride!", Icon = "👑", Price = 499, Color = BLUE, ProductId = 0, Reward = { Attribute = "Trophies", Add = 10 } },
	{ Id = "Medal", Tab = "Trophies", Name = "Hero Medal", Desc = "The ultimate flex!", Icon = "🎖️", Price = 349, Color = BLUE, ProductId = 0, Reward = { Attribute = "Trophies", Add = 7 } },

	-- PETS
	{ Id = "EggCommon", Tab = "Pets", Name = "Cute Egg", Desc = "Hatch a friendly pet!", Price = 79, Color = GREEN, ProductId = 0, Reward = { Attribute = "Eggs", Add = 1 } },
	{ Id = "EggEpic", Tab = "Pets", Name = "Epic Egg", Desc = "Higher chance for epic pets!", Price = 199, Color = PURPLE, ProductId = 0, Reward = { Attribute = "Eggs", Add = 3 } },
	{ Id = "EggLegend", Tab = "Pets", Name = "Legend Egg", Desc = "Legendary pets inside!", Price = 399, Color = PINK, Tag = "HOT!", ProductId = 0, Reward = { Attribute = "Eggs", Add = 5 } },
	{ Id = "PetSlot", Tab = "Pets", Name = "+1 Pet Slot", Desc = "Carry one more friend!", Icon = "🐾", Price = 149, Color = BLUE, ProductId = 0, Reward = { Attribute = "PetSlots", Add = 1 } },
	{ Id = "PetLuck", Tab = "Pets", Name = "Pet Luck", Desc = "Better hatch odds, forever!", Icon = "🍀", Price = 299, Color = BLUE, ProductId = 0, Reward = { Attribute = "PetLuck", Add = 1 } },
}

return Config
