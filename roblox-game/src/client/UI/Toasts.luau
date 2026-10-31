--!strict
-- Short messages near the top of the screen (level up, loot, boss phases), plus the optional
-- help prompt after repeated boss defeats.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Theme = require(script.Parent.Theme)
local Notifications = require(script.Parent.Parent.Controllers.Notifications)
local InputController = require(script.Parent.Parent.Controllers.InputController)
local CombatController = require(script.Parent.Parent.Controllers.CombatController)
local SettingsController = require(script.Parent.Parent.Controllers.SettingsController)

local player = Players.LocalPlayer

local Toasts = {}

local list: Frame
local scale: UIScale
local order = 0

function Toasts.show(text: string, color: Color3?, seconds: number?)
	order += 1
	local toast = Theme.make("Frame", {
		Size = UDim2.fromOffset(460, 40),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.2,
		LayoutOrder = order,
		Parent = list,
	})
	Theme.corner(toast)
	Theme.label({
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		Text = text,
		TextColor3 = color or Theme.colors.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.fontBold,
		TextSize = 20,
		TextWrapped = true,
		Parent = toast,
	})
	task.delay(seconds or 3, function()
		TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.wait(0.3)
		toast:Destroy()
	end)
end

-- A message with buttons. Each button runs its callback and closes the prompt.
function Toasts.prompt(text: string, buttons: { { label: string, callback: () -> () } })
	order += 1
	local box = Theme.make("Frame", {
		Size = UDim2.fromOffset(460, 150),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.05,
		LayoutOrder = order,
		Parent = list,
	})
	Theme.corner(box)
	Theme.label({
		Size = UDim2.new(1, -24, 0, 80),
		Position = UDim2.fromOffset(12, 8),
		Text = text,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 18,
		Parent = box,
	})
	local first: GuiObject? = nil
	for i, spec in buttons do
		local button = Theme.button({
			Size = UDim2.fromOffset(200, 44),
			Position = UDim2.fromOffset(12 + (i - 1) * 224, 96),
			Text = spec.label,
			Parent = box,
		})
		first = first or button
		button.Activated:Connect(function()
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(box) then
				GuiService.SelectedObject = nil
			end
			box:Destroy()
			spec.callback()
		end)
	end
	if first and InputController.device() == "gamepad" then
		GuiService.SelectedObject = first
	end
	task.delay(30, function()
		if box.Parent then
			box:Destroy()
		end
	end)
end

function Toasts.start()
	local gui = Theme.make("ScreenGui", {
		Name = "SBE_Toasts",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	scale = Theme.make("UIScale", { Scale = Theme.screenScale(), Parent = gui })
	list = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(460, 400),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.make("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = list,
	})
	SettingsController.changed:Connect(function(id: string, value: any)
		if id == "text_scale" and type(value) == "number" then
			scale.Scale = Theme.screenScale() * value
		end
	end)

	Notifications.on("level_up", function(m: any)
		local text = `Level {m.level}!`
		if m.atCap then
			text ..= "  (highest level in this build)"
		end
		Toasts.show(text, Theme.colors.accent, 3.5)
		for _, name in m.milestones or {} do
			Toasts.show(`Milestone: {name}`, Theme.colors.spirit, 4)
		end
	end)
	Notifications.on("loot", function(m: any)
		local parts = {}
		for _, item in m.items or {} do
			table.insert(parts, `+{item.qty} {item.name}`)
		end
		Toasts.show(table.concat(parts, ", "), Theme.colors.good, 2.5)
	end)
	Notifications.on("no_spirit", function(m: any)
		Toasts.show(`Not enough spirit ({m.need} needed). Parry or land hits to fill it.`, Theme.colors.spirit, 2.5)
	end)
	Notifications.on("boss_defeated", function(m: any)
		Toasts.show(`{m.boss} defeated!`, Theme.colors.accent, 5)
	end)
	Notifications.on("assist", function(m: any)
		local text = `Tip: {m.tip}`
		if table.find(m.offers, "suggested_level") and m.suggestedLevel then
			text ..= `\nSuggested level: {m.suggestedLevel}`
		end
		if table.find(m.offers, "support_buff") then
			Toasts.prompt(text .. `\nWould you like the {m.buffName} buff for this fight? (optional)`, {
				{
					label = "Yes, help me",
					callback = function()
						Net.event("Action"):FireServer({ a = "assist_accept", kind = "support_buff" })
						Toasts.show(`{m.buffName}: you take less damage and hit a bit harder.`, Theme.colors.good, 4)
					end,
				},
				{ label = "No thanks", callback = function() end },
			})
		else
			Toasts.show(text, Theme.colors.text, 8)
		end
	end)
	CombatController.notAvailable:Connect(function(label: string)
		Toasts.show(`{label}: not in this build yet`, Theme.colors.dim, 2)
	end)
	Net.fx().OnClientEvent:Connect(function(event: any)
		if type(event) == "table" and event.k == "phase" then
			Toasts.show(`{event.boss}: {event.name}`, Theme.colors.boss, 3)
		end
	end)
end

return Toasts
