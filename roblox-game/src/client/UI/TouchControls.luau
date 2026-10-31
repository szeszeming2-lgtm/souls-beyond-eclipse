--!strict
-- On-screen controls for phones and tablets: a virtual stick that appears where you touch,
-- camera swipes on the other side, and large buttons. Three layouts (standard, one-handed
-- left/right) and a size setting. Shown only while touch is the active input.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Theme = require(script.Parent.Theme)
local InputController = require(script.Parent.Parent.Controllers.InputController)
local SettingsController = require(script.Parent.Parent.Controllers.SettingsController)
local CameraController = require(script.Parent.Parent.Controllers.CameraController)

local player = Players.LocalPlayer
local STICK_RADIUS = 70

local TouchControls = {}

-- Button: action, label, size, and offset from the anchor corner (standard layout).
type Spec = { action: string, label: string, size: number, x: number, y: number }
local SPECS: { Spec } = {
	{ action = "light_attack", label = "Attack", size = 116, x = 150, y = 150 },
	{ action = "heavy_attack", label = "Heavy", size = 78, x = 280, y = 120 },
	{ action = "dodge_sprint", label = "Dodge", size = 78, x = 150, y = 280 },
	{ action = "guard", label = "Guard", size = 78, x = 270, y = 230 },
	{ action = "jump", label = "Jump", size = 70, x = 50, y = 270 },
	{ action = "ability_1", label = "", size = 70, x = 380, y = 170 },
	{ action = "lock_on", label = "Lock", size = 58, x = 50, y = 380 },
}

local gui: ScreenGui
local scale: UIScale
local buttons: { [string]: TextButton } = {}
local stickBase: Frame
local stickKnob: Frame
local stickTouch: InputObject? = nil
local stickOrigin = Vector2.zero
local cameraTouch: InputObject? = nil
local cameraLast = Vector2.zero
local buttonTouches: { [InputObject]: string } = {}

local function layout(): string
	return SettingsController.get("touch_layout") or "standard"
end

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

-- Which side the stick lives on: left normally, same side as the buttons when one-handed.
local function stickOnRight(): boolean
	return layout() == "one_handed_right"
end

local function placeButtons()
	local mode = layout()
	local onLeft = mode == "one_handed_left"
	local compact = mode ~= "standard"
	for _, spec in SPECS do
		local button = buttons[spec.action]
		local x = if compact then spec.x * 0.75 else spec.x
		local y = if compact then spec.y * 0.75 + 170 else spec.y
		button.Size = UDim2.fromOffset(spec.size, spec.size)
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = if onLeft then UDim2.new(0, x, 1, -y) else UDim2.new(1, -x, 1, -y)
	end
end

local function refreshVisibility()
	gui.Enabled = InputController.device() == "touch" and InputController.context() == "gameplay"
	local value = SettingsController.get("touch_ui_scale")
	scale.Scale = (if type(value) == "number" then value else 1) * Theme.screenScale()
end

local function inStickZone(position: Vector2): boolean
	local size = viewport()
	local x = position.X / size.X
	local y = position.Y / size.Y
	if layout() == "standard" then
		return x < 0.45 and y > 0.3
	end
	-- one-handed: the stick sits low on the same side as the buttons, under them
	if stickOnRight() then
		return x > 0.5 and y > 0.72
	end
	return x < 0.5 and y > 0.72
end

local function makeButton(spec: Spec): TextButton
	local label = spec.label
	if spec.action == "ability_1" then
		local ability = Data.abilities[Data.weapons["wpn_hearthwick"].special_ability_id]
		label = ability.name
	end
	local button = Theme.button({
		Name = spec.action,
		Text = label,
		TextSize = if spec.size > 100 then 22 else 15,
		BackgroundTransparency = 0.25,
		Parent = gui,
	})
	Theme.corner(button, 200)
	button.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			buttonTouches[input] = spec.action
			InputController.touchPress(spec.action)
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if buttonTouches[input] then
			buttonTouches[input] = nil
			InputController.touchRelease(spec.action)
		end
	end)
	return button
end

function TouchControls.start()
	gui = Theme.make("ScreenGui", {
		Name = "SBE_Touch",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	scale = Theme.make("UIScale", { Parent = gui })
	for _, spec in SPECS do
		buttons[spec.action] = makeButton(spec)
	end
	stickBase = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(STICK_RADIUS * 2, STICK_RADIUS * 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		Visible = false,
		Parent = gui,
	})
	Theme.corner(stickBase, 200)
	stickKnob = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.4,
		Parent = stickBase,
	})
	Theme.corner(stickKnob, 200)
	placeButtons()
	refreshVisibility()

	UserInputService.TouchStarted:Connect(function(touch: InputObject, processed: boolean)
		if processed or InputController.context() ~= "gameplay" then
			return
		end
		local position = Vector2.new(touch.Position.X, touch.Position.Y)
		if stickTouch == nil and inStickZone(position) then
			stickTouch = touch
			stickOrigin = position
			stickBase.Position = UDim2.fromOffset(position.X / scale.Scale, position.Y / scale.Scale)
			stickKnob.Position = UDim2.fromScale(0.5, 0.5)
			stickBase.Visible = true
			InputController.setTouchMove(Vector2.zero)
		elseif cameraTouch == nil then
			cameraTouch = touch
			cameraLast = position
		end
	end)
	UserInputService.TouchMoved:Connect(function(touch: InputObject)
		local position = Vector2.new(touch.Position.X, touch.Position.Y)
		if touch == stickTouch then
			local offset = position - stickOrigin
			local radius = STICK_RADIUS * scale.Scale
			if offset.Magnitude > radius then
				offset = offset.Unit * radius
			end
			stickKnob.Position = UDim2.new(0.5, offset.X / scale.Scale, 0.5, offset.Y / scale.Scale)
			InputController.setTouchMove(Vector2.new(offset.X / radius, -offset.Y / radius))
		elseif touch == cameraTouch then
			CameraController.addTouchDelta(position - cameraLast)
			cameraLast = position
		end
	end)
	UserInputService.TouchEnded:Connect(function(touch: InputObject)
		if touch == stickTouch then
			stickTouch = nil
			stickBase.Visible = false
			InputController.setTouchMove(Vector2.zero)
		elseif touch == cameraTouch then
			cameraTouch = nil
		end
		local action = buttonTouches[touch]
		if action then
			buttonTouches[touch] = nil
			InputController.touchRelease(action)
		end
	end)

	InputController.deviceChanged:Connect(refreshVisibility)
	SettingsController.changed:Connect(function(id: string)
		if id == "touch_layout" then
			placeButtons()
		end
		if id == "touch_layout" or id == "touch_ui_scale" then
			refreshVisibility()
		end
	end)
	-- Hide while a menu is open (the menu has its own buttons).
	task.spawn(function()
		local lastContext = InputController.context()
		while true do
			task.wait(0.2)
			local context = InputController.context()
			if context ~= lastContext then
				lastContext = context
				refreshVisibility()
			end
		end
	end)
end

return TouchControls
