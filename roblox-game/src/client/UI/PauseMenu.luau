--!strict
-- Pause menu and Settings. The settings screens are built from shared-data/settings.json, so a
-- new setting only needs a data entry. Fully usable with a gamepad (D-pad/stick + A/B).
-- Roblox servers are shared, so the game cannot truly pause: while this menu is open, enemies
-- do not start new attacks on you and you cannot attack.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Net = require(Shared.Net)
local Theme = require(script.Parent.Theme)
local InputController = require(script.Parent.Parent.Controllers.InputController)
local SettingsController = require(script.Parent.Parent.Controllers.SettingsController)
local CameraController = require(script.Parent.Parent.Controllers.CameraController)
local Hud = require(script.Parent.Hud)

local player = Players.LocalPlayer

local PauseMenu = {}

local gui: ScreenGui
local content: Frame
local title: TextLabel
local view = "main"
local tabIndex = 1
local isOpen = false

local function clear()
	for _, child in content:GetChildren() do
		child:Destroy()
	end
end

local function focusButton(button: GuiObject?)
	if InputController.device() == "gamepad" then
		GuiService.SelectedObject = button
	end
end

local function column(): Frame
	local frame = Theme.make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	Theme.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	return frame
end

local function formatValue(def: any, value: any): string
	if def.kind == "toggle" then
		return if value then "On" else "Off"
	elseif def.kind == "slider" then
		if def.max <= 1 then
			return `{math.floor(value * 100 + 0.5)}%`
		end
		return string.format("%.2fx", value)
	end
	for _, option in def.options or {} do
		if option.value == value then
			return option.label
		end
	end
	return tostring(value)
end

local showMain: () -> ()
local showSettings: () -> ()
local showControls: () -> ()

local function settingRow(parent: Instance, def: any, order: number): GuiObject
	local row = Theme.make("Frame", {
		Size = UDim2.new(1, -12, 0, if def.help then 70 else 52),
		BackgroundColor3 = Theme.colors.panelLight,
		BackgroundTransparency = 0.4,
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.corner(row)
	Theme.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(0.55, 0, 0, 24),
		Text = def.label,
		Font = Theme.fontBold,
		TextSize = 18,
		Parent = row,
	})
	if def.help then
		Theme.label({
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(0.6, 0, 0, 34),
			Text = def.help,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = Theme.colors.dim,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = row,
		})
	end
	local valueLabel = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -60, 0, 8),
		Size = UDim2.fromOffset(150, 32),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 18,
		Parent = row,
	})
	local function refresh()
		valueLabel.Text = formatValue(def, SettingsController.get(def.id))
	end
	refresh()
	local function change(direction: number)
		local current = SettingsController.get(def.id)
		if def.kind == "toggle" then
			SettingsController.set(def.id, not current)
		elseif def.kind == "slider" then
			SettingsController.set(def.id, current + def.step * direction)
		else
			local options = def.options
			local index = 1
			for i, option in options do
				if option.value == current then
					index = i
				end
			end
			index = (index - 1 + direction) % #options + 1
			SettingsController.set(def.id, options[index].value)
		end
		refresh()
	end
	local minus = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -214, 0, 8),
		Size = UDim2.fromOffset(44, 34),
		Text = if def.kind == "slider" then "-" else "<",
		Parent = row,
	})
	local plus = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(44, 34),
		Text = if def.kind == "slider" then "+" else ">",
		Parent = row,
	})
	minus.Activated:Connect(function()
		change(-1)
	end)
	plus.Activated:Connect(function()
		change(1)
	end)
	return minus
end

showSettings = function()
	view = "settings"
	clear()
	local tabs = Data.settings.tabs
	tabIndex = math.clamp(tabIndex, 1, #tabs)
	local tab = tabs[tabIndex]
	title.Text = "Settings"
	local tabRow = Theme.make("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = content })
	Theme.make(
		"UIListLayout",
		{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = tabRow }
	)
	for i, t in tabs do
		local b = Theme.button({
			Size = UDim2.fromOffset(92, 36),
			Text = t.label,
			TextSize = 14,
			BackgroundColor3 = if i == tabIndex then Theme.colors.accent else Theme.colors.panelLight,
			Parent = tabRow,
		})
		b.Activated:Connect(function()
			tabIndex = i
			showSettings()
		end)
	end
	local listHolder = Theme.make("Frame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -110),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local list = Theme.make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = listHolder,
	})
	Theme.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local first: GuiObject? = nil
	local order = 0
	for _, def in SettingsController.defs do
		if def.tab == tab.id then
			order += 1
			local control = settingRow(list, def, order)
			first = first or control
		end
	end
	if order == 0 then
		Theme.label({
			Size = UDim2.new(1, 0, 0, 40),
			Text = "Nothing to change here on Roblox yet.",
			TextColor3 = Theme.colors.dim,
			Parent = list,
		})
	end
	local restore = Theme.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(220, 48),
		Text = "Restore defaults",
		Parent = content,
	})
	restore.Activated:Connect(function()
		SettingsController.restoreTab(tab.id)
		showSettings()
	end)
	local back = Theme.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(160, 48),
		Text = "Back",
		Parent = content,
	})
	back.Activated:Connect(function()
		showMain()
	end)
	focusButton(first or back)
end

showControls = function()
	view = "controls"
	clear()
	title.Text = "Controls"
	local list = column()
	local order = 0
	local devices: { [string]: string } = { keyboard_mouse = "Keyboard", gamepad = "Gamepad", touch = "Touch" }
	for _, action in Data.inputActions.actions do
		if action.context == "gameplay" then
			order += 1
			local text = action.label .. ":  "
			local parts = {}
			for device, label in devices do
				local bindings = action.bindings[device]
				local override = action.platform_overrides
					and action.platform_overrides.roblox
					and action.platform_overrides.roblox[device]
				local names = {}
				local inputs: { string } = override or bindings or {}
				for _, name in inputs do
					table.insert(names, Theme.inputName(name))
				end
				table.insert(parts, `{label} {table.concat(names, "/")}`)
			end
			table.sort(parts)
			Theme.label({
				Size = UDim2.new(1, -12, 0, 26),
				Text = text .. table.concat(parts, "   "),
				TextSize = 15,
				TextWrapped = true,
				LayoutOrder = order,
				Parent = list,
			})
		end
	end
	order += 1
	Theme.label({
		Size = UDim2.new(1, -12, 0, 44),
		Text = "Right-click can be switched between heavy attack and guard in Settings > Controls. Full key remapping comes in a later phase.",
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = Theme.colors.dim,
		LayoutOrder = order,
		Parent = list,
	})
	order += 1
	local back = Theme.button({ Size = UDim2.fromOffset(160, 48), Text = "Back", LayoutOrder = order, Parent = list })
	back.Activated:Connect(function()
		showMain()
	end)
	focusButton(back)
end

showMain = function()
	view = "main"
	clear()
	title.Text = "Paused"
	local list = column()
	local entries: { { label: string, run: () -> () } } = {
		{
			label = "Resume",
			run = function()
				PauseMenu.close()
			end,
		},
		{ label = "Settings", run = showSettings },
		{ label = "Controls", run = showControls },
	}
	local first: GuiObject? = nil
	for i, entry in entries do
		local button =
			Theme.button({ Size = UDim2.new(1, -12, 0, 56), Text = entry.label, LayoutOrder = i, Parent = list })
		button.Activated:Connect(function()
			entry.run()
		end)
		first = first or button
	end
	Theme.label({
		Size = UDim2.new(1, -12, 0, 60),
		Text = "The world keeps running while this menu is open, but enemies will not start new attacks on you.",
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = Theme.colors.dim,
		LayoutOrder = 10,
		Parent = list,
	})
	focusButton(first)
end

function PauseMenu.open()
	if isOpen then
		return
	end
	isOpen = true
	gui.Enabled = true
	InputController.setContext("menu")
	CameraController.setMenuOpen(true)
	Net.event("Action"):FireServer({ a = "menu_open" })
	showMain()
end

function PauseMenu.close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	GuiService.SelectedObject = nil
	InputController.setContext("gameplay")
	CameraController.setMenuOpen(false)
	Net.event("Action"):FireServer({ a = "menu_close" })
end

function PauseMenu.isOpen(): boolean
	return isOpen
end

function PauseMenu.start()
	-- Free the gamepad View/Select button for our pause menu (Roblox's own menu keeps Start).
	GuiService.AutoSelectGuiEnabled = false
	gui = Theme.make("ScreenGui", {
		Name = "SBE_Menu",
		Enabled = false,
		ResetOnSpawn = false,
		DisplayOrder = 20,
		IgnoreGuiInset = true,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Theme.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = gui,
	})
	local panel = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 600),
		BackgroundColor3 = Theme.colors.panel,
		Parent = gui,
	})
	Theme.corner(panel, 12)
	local scale = Theme.make("UIScale", { Scale = math.min(1, Theme.screenScale()), Parent = panel })
	title = Theme.label({
		Position = UDim2.fromOffset(24, 16),
		Size = UDim2.new(1, -48, 0, 40),
		Font = Theme.fontBold,
		TextSize = 30,
		Parent = panel,
	})
	content = Theme.make("Frame", {
		Position = UDim2.fromOffset(24, 70),
		Size = UDim2.new(1, -48, 1, -94),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	local function fitScale()
		local camera = workspace.CurrentCamera
		if camera then
			local fit = math.min(camera.ViewportSize.X / 680, camera.ViewportSize.Y / 640)
			scale.Scale = math.clamp(fit, 0.5, 1.4) * (SettingsController.get("text_scale") or 1) ^ 0.5
		end
	end
	fitScale()
	SettingsController.changed:Connect(fitScale)
	RunService.Heartbeat:Connect(function()
		if isOpen then
			fitScale()
		end
	end)

	InputController.pressed:Connect(function(actionId: string)
		local context = InputController.context()
		if context == "gameplay" and actionId == "pause" then
			PauseMenu.open()
		elseif context == "menu" and actionId == "menu_back" then
			if view == "main" then
				PauseMenu.close()
			else
				showMain()
			end
		elseif
			context == "menu"
			and view == "settings"
			and (actionId == "menu_tab_next" or actionId == "menu_tab_prev")
		then
			tabIndex = (tabIndex - 1 + (if actionId == "menu_tab_next" then 1 else -1)) % #Data.settings.tabs + 1
			showSettings()
		end
	end)
	Hud.menuRequested:Connect(function()
		if isOpen then
			PauseMenu.close()
		else
			PauseMenu.open()
		end
	end)
	player.CharacterAdded:Connect(function()
		PauseMenu.close()
	end)
end

return PauseMenu
