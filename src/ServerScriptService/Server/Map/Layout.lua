-- Misure condivise da tutti i moduli della mappa (derivate da Config.Field).
-- Sistema di coordinate: asse X = lunghezza del campo (Rossi difendono -X, Blu +X), asse Z = larghezza, Y verso l'alto.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local F = Config.Field

local Layout = {}

Layout.HL = F.Length / 2 -- mezza lunghezza: la linea di porta sta a x = +-HL
Layout.HW = F.Width / 2 -- mezza larghezza: le linee laterali stanno a z = +-HW
Layout.GD = F.GoalDepth
Layout.GW = F.GoalWidth
Layout.GH = F.GoalHeight
Layout.WALL_H = F.WallHeight
Layout.XB = Layout.HL + Layout.GD + 2 -- faccia interna delle pareti di testa
Layout.ZB = Layout.HW -- faccia interna delle pareti laterali

Layout.PITCH_Y = 0.15 -- quota della superficie di gioco (la palla appoggia qui)
Layout.GROUND_Y = -2 -- quota del terreno della valle
Layout.PLAZA_X = 192 -- semi-estensione della piazza dello stadio
Layout.PLAZA_Z = 156

-- tribune lungo i lati lunghi
Layout.STAND = {
	Z0 = 76, -- distanza dall'asse del campo del primo gradone
	Rows = 6,
	Depth = 5.5,
	Rise = 2.3,
	HalfLen = 112,
}
Layout.STAND_BACK = Layout.STAND.Z0 + Layout.STAND.Rows * Layout.STAND.Depth -- 109

-- torri faro (fuori dalla piazza dei gradoni, agli angoli)
Layout.TOWER_X = 140
Layout.TOWER_Z = 98

-- lobby: belvedere sulla parete sud del canyon, guarda il campo (verso +Z)
Layout.LOBBY = Config.Lobby.Center

return Layout
