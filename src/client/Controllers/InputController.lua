--[[
	InputController
	Traduce tasti, mouse e pulsanti touch in "azioni" di gioco.

	Comandi (PC):
	  Q / E          rampino sinistro / destro (tieni premuto)
	  Spazio         salto / getto di gas in volo
	  Shift          attiva/disattiva lo shift lock
	  Ctrl sinistro  schivata
	  Clic sinistro  fendente (combo da 4 colpi)
	  Clic destro    arma a distanza (Lancia Dirompente, pistole...)
	  Z X C V        abilità delle lame (o del gigante)
	  R              sostituisci le lame
	  T              trasformazione in gigante
	  G              Risveglio Valkar
	  M              menu
	  N              negozio premium (gemme, monete, pass)
	  Bloc Maiusc    cammina / corri
	  Alt sinistro   sblocca il cursore
]]

local UserInputService = game:GetService("UserInputService")

local InputController = {}
local C

local handlers: { [string]: { (boolean) -> () } } = {}
local held: { [string]: boolean } = {}

local KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Q] = "HookLeft",
	[Enum.KeyCode.E] = "HookRight",
	[Enum.KeyCode.Space] = "Boost",
	[Enum.KeyCode.LeftShift] = "ShiftLock",
	[Enum.KeyCode.RightShift] = "ShiftLock",
	[Enum.KeyCode.LeftControl] = "Dodge",
	[Enum.KeyCode.R] = "Reload",
	[Enum.KeyCode.Z] = "SkillZ",
	[Enum.KeyCode.X] = "SkillX",
	[Enum.KeyCode.C] = "SkillC",
	[Enum.KeyCode.V] = "SkillV",
	[Enum.KeyCode.T] = "Transform",
	[Enum.KeyCode.G] = "Awaken",
	[Enum.KeyCode.M] = "Menu",
	[Enum.KeyCode.N] = "Premium",
	[Enum.KeyCode.P] = "Admin",
	[Enum.KeyCode.CapsLock] = "WalkToggle",
	[Enum.KeyCode.LeftAlt] = "ToggleCursor",
	[Enum.KeyCode.ButtonR2] = "Attack",
	[Enum.KeyCode.ButtonL2] = "Ranged",
	[Enum.KeyCode.ButtonL1] = "HookLeft",
	[Enum.KeyCode.ButtonR1] = "HookRight",
	[Enum.KeyCode.ButtonA] = "Boost",
	[Enum.KeyCode.ButtonB] = "Dodge",
	[Enum.KeyCode.ButtonX] = "SkillZ",
	[Enum.KeyCode.ButtonY] = "SkillX",
}

local MOUSE: { [Enum.UserInputType]: string } = {
	[Enum.UserInputType.MouseButton1] = "Attack",
	[Enum.UserInputType.MouseButton2] = "Ranged",
}

-- Azioni che funzionano anche con un menu aperto
local ALWAYS = {
	Menu = true,
	Premium = true,
	Admin = true,
	ToggleCursor = true,
}

function InputController.On(action: string, fn: (boolean) -> ())
	handlers[action] = handlers[action] or {}
	table.insert(handlers[action], fn)
end

function InputController.IsHeld(action: string): boolean
	return held[action] == true
end

function InputController.Trigger(action: string, began: boolean)
	if began and not ALWAYS[action] and C.UIController and C.UIController.CursorActive() and not action:find("Mash") then
		return
	end
	if C.CameraController and C.CameraController.IsCinematic() and not ALWAYS[action] then
		return
	end
	held[action] = began
	local list = handlers[action]
	if list then
		for _, fn in list do
			task.spawn(fn, began)
		end
	end
end

local function actionFor(input: InputObject): string?
	if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.Gamepad1 then
		return KEYS[input.KeyCode]
	end
	return MOUSE[input.UserInputType]
end

function InputController.Init(c)
	C = c
end

function InputController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		local action = actionFor(input)
		if not action then
			return
		end
		if processed and not ALWAYS[action] then
			-- con il mouse bloccato al centro i clic non toccano l'interfaccia
			local mouseLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
			if not (mouseLocked and MOUSE[input.UserInputType]) then
				return
			end
		end
		InputController.Trigger(action, true)
	end)
	UserInputService.InputEnded:Connect(function(input)
		local action = actionFor(input)
		if action and held[action] then
			held[action] = false
			local list = handlers[action]
			if list then
				for _, fn in list do
					task.spawn(fn, false)
				end
			end
		end
	end)
	InputController.On("ToggleCursor", function(began)
		if began then
			C.UIController.RequestCursor("alt", not C.UIController.CursorActive())
		end
	end)
end

return InputController
