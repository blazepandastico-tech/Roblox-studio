--[[
	Tema - quale "vestito" ha il gioco: Normale oppure Halloween
	Il file SieriPerduti_Halloween.rbxlx (halloween.project.json) mette l'attributo
	Tema = "Halloween" su ReplicatedStorage: con quello il mondo, i giganti, l'equipaggiamento,
	il cielo e i menu prendono l'aspetto di Halloween e nel Pannello Admin compaiono gli eventi
	dell'Admin Abuse di Halloween. Il gioco (mappa, collisioni, statistiche) resta lo stesso.

	Per provare Halloween anche nel file normale: in Studio seleziona ReplicatedStorage,
	Proprietà → Attributi → aggiungi "Tema" (testo) con il valore Halloween.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tema = {}

Tema.Attribute = "Tema"

function Tema.Get(): string
	local value = ReplicatedStorage:GetAttribute(Tema.Attribute)
	return if value == "Halloween" then "Halloween" else "Normale"
end

function Tema.IsHalloween(): boolean
	return ReplicatedStorage:GetAttribute(Tema.Attribute) == "Halloween"
end

-- Etichette (CollectionService) delle decorazioni di Halloween
Tema.Tags = {
	Carved = "ZuccaAccesa", -- intaglio delle zucche con la candela: di notte si illumina (HalloweenController)
}

-- Colori di Halloween usati in tutto il gioco
Tema.Colors = {
	Pumpkin = Color3.fromRGB(236, 118, 28), -- arancione zucca
	PumpkinDark = Color3.fromRGB(176, 72, 18),
	Candle = Color3.fromRGB(255, 196, 92), -- fiamma della candela
	Witch = Color3.fromRGB(104, 48, 150), -- viola strega
	WitchDark = Color3.fromRGB(46, 22, 66),
	Slime = Color3.fromRGB(118, 214, 64), -- verde pozione
	Ghost = Color3.fromRGB(214, 236, 255), -- bianco fantasma
	GhostGlow = Color3.fromRGB(130, 220, 255),
	Bone = Color3.fromRGB(226, 218, 196),
	Night = Color3.fromRGB(20, 14, 30),
	Blood = Color3.fromRGB(150, 20, 30),
	Stem = Color3.fromRGB(70, 96, 40), -- gambo della zucca
}

-- numero fisso tra 0 e 1 da una posizione (stesso posto = stesso numero, su server e client)
function Tema.Hash(p: Vector3, salt: number?): number
	local v = math.sin(p.X * 12.9898 + p.Y * 78.233 + p.Z * 37.719 + (salt or 0) * 19.19) * 43758.5453
	return v - math.floor(v)
end

return Tema
