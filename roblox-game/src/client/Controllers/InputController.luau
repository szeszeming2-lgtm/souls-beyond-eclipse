--!strict
-- One input system for keyboard + mouse, gamepad and touch. Everything else in the game listens
-- for ACTIONS ("light_attack"), never keys. Bindings come from shared-data/input_actions.json,
-- with Roblox's reserved keys (Esc, the gamepad Menu button) removed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local InputMap = require(Shared.Rules.InputMap)
local Signal = require(Shared.Util.Signal)
local SettingsController = require(script.Parent.SettingsController)
local Theme = require(script.Parent.Parent.UI.Theme)

local PLATFORM = "roblox"
local STICK_DEADZONE = 0.18

local InputController = {}
InputController.pressed = Signal.new() -- (actionId)
InputController.released = Signal.new() -- (actionId, heldSeconds)
InputController.deviceChanged = Signal.new() -- (device)
InputController.wheel = Signal.new() -- (delta)

local map: InputMap.Map
local context = "gameplay"
local device = "keyboard_mouse"
local downSince: { [string]: number } = {}
local heldKeys: { [string]: { number } } = {} -- composite keys currently held -> direction
local leftStick = Vector2.zero
local rightStick = Vector2.zero
local touchMove = Vector2.zero

local function rebuild()
	local presets = {}
	if SettingsController.get("right_click") == "guard" then
		table.insert(presets, "right_click_guard")
	end
	map = InputMap.build(Data.inputActions, PLATFORM, presets)
end

local function deviceOf(inputType: Enum.UserInputType): string?
	if inputType == Enum.UserInputType.Touch then
		return "touch"
	elseif
		inputType == Enum.UserInputType.Keyboard
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseButton3
		or inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.MouseWheel
	then
		return "keyboard_mouse"
	elseif string.match(inputType.Name, "^Gamepad") then
		return "gamepad"
	end
	return nil
end

local function nameOf(input: InputObject): string?
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.Keyboard then
		return input.KeyCode.Name
	elseif
		inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseButton3
	then
		return inputType.Name
	elseif deviceOf(inputType) == "gamepad" then
		return input.KeyCode.Name
	end
	return nil
end

local function setDevice(newDevice: string)
	if newDevice ~= device then
		device = newDevice
		InputController.deviceChanged:Fire(device)
	end
end

local function begin(actionId: string)
	if downSince[actionId] == nil then
		downSince[actionId] = os.clock()
		InputController.pressed:Fire(actionId)
	end
end

local function finish(actionId: string)
	local since = downSince[actionId]
	if since then
		downSince[actionId] = nil
		InputController.released:Fire(actionId, os.clock() - since)
	end
end

local function onBegan(input: InputObject, gameProcessed: boolean)
	local dev = deviceOf(input.UserInputType)
	if dev == nil or dev == "touch" then
		return -- touch is handled by the on-screen controls
	end
	setDevice(dev)
	if gameProcessed or UserInputService:GetFocusedTextBox() then
		return -- typing in chat, or clicking a UI button
	end
	local name = nameOf(input)
	if name == nil then
		return
	end
	local axisAction, x, y = InputMap.directionFor(map, context, dev, name)
	if axisAction == "move" then
		heldKeys[name] = { x, y }
		return
	end
	local actionId = InputMap.actionFor(map, context, dev, name)
	if actionId then
		begin(actionId)
	end
end

local function onEnded(input: InputObject, _gameProcessed: boolean)
	local dev = deviceOf(input.UserInputType)
	local name = nameOf(input)
	if dev == nil or dev == "touch" or name == nil then
		return
	end
	heldKeys[name] = nil
	local actionId = InputMap.actionFor(map, context, dev, name)
	if actionId then
		finish(actionId)
	end
end

local function onChanged(input: InputObject, _gameProcessed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		InputController.wheel:Fire(input.Position.Z)
		return
	end
	if deviceOf(input.UserInputType) ~= "gamepad" then
		return
	end
	local v = Vector2.new(input.Position.X, input.Position.Y)
	if v.Magnitude < STICK_DEADZONE then
		v = Vector2.zero
	else
		setDevice("gamepad")
	end
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		leftStick = v
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		rightStick = v
	end
end

-- ------------------------------------------------------------------ public API
function InputController.device(): string
	return device
end

function InputController.context(): string
	return context
end

-- "gameplay" or "menu". Switching releases everything held, so nothing gets stuck down.
function InputController.setContext(newContext: string)
	if newContext == context then
		return
	end
	for actionId in table.clone(downSince) do
		finish(actionId)
	end
	heldKeys = {}
	touchMove = Vector2.zero
	context = newContext
end

function InputController.isDown(actionId: string): boolean
	return downSince[actionId] ~= nil
end

-- Movement as a 2D vector (x = right, y = forward), length 0..1.
function InputController.moveVector(): Vector2
	if context ~= "gameplay" then
		return Vector2.zero
	end
	if touchMove.Magnitude > 0 then
		return touchMove
	end
	if leftStick.Magnitude > 0 then
		return leftStick
	end
	local x, y = 0, 0
	for _, dir in heldKeys do
		x += dir[1]
		y += dir[2]
	end
	local v = Vector2.new(x, y)
	return if v.Magnitude > 1 then v.Unit else v
end

function InputController.cameraStick(): Vector2
	return if context == "gameplay" then rightStick else Vector2.zero
end

-- Used by the on-screen touch controls.
function InputController.touchPress(actionId: string)
	setDevice("touch")
	begin(actionId)
end

function InputController.touchRelease(actionId: string)
	finish(actionId)
end

function InputController.setTouchMove(v: Vector2)
	setDevice("touch")
	touchMove = if v.Magnitude > 1 then v.Unit else v
end

-- On-screen hint for an action on the current device, e.g. "Q", "RB", "LMB".
function InputController.hint(actionId: string): string
	local names = InputMap.hintsFor(map, actionId, device)
	return if #names > 0 then Theme.inputName(names[1]) else ""
end

function InputController.start()
	rebuild()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		device = "touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		device = "gamepad"
	end
	SettingsController.changed:Connect(function(id: string)
		if id == "right_click" then
			rebuild()
		end
	end)
	UserInputService.InputBegan:Connect(onBegan)
	UserInputService.InputEnded:Connect(onEnded)
	UserInputService.InputChanged:Connect(onChanged)
	UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		local dev = deviceOf(inputType)
		if dev and inputType ~= Enum.UserInputType.MouseMovement then
			setDevice(dev)
		end
	end)
end

return InputController
