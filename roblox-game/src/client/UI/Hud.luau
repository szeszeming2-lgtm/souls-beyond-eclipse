--!strict
-- The HUD: health, spirit, level and XP (always showing the XP still needed), active effects,
-- ability cooldowns, the boss bar, the objective, and a menu button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Net = require(Shared.Net)
local Theme = require(script.Parent.Theme)
local Notifications = require(script.Parent.Parent.Controllers.Notifications)
local InputController = require(script.Parent.Parent.Controllers.InputController)
local SettingsController = require(script.Parent.Parent.Controllers.SettingsController)
local CameraController = require(script.Parent.Parent.Controllers.CameraController)
local Signal = require(Shared.Util.Signal)

local player = Players.LocalPlayer
local UPDATE_S = 0.1

local Hud = {}
Hud.menuRequested = Signal.new()

local cooldowns: { [string]: { readyAt: number, duration: number } } = {}

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	return (string.gsub(out, "^,", ""))
end

local function effectName(id: string): string
	local status = Data.statusEffects[id]
	if status then
		return status.name
	end
	local ability = Data.abilities[id]
	return if ability then ability.name else id
end

function Hud.start()
	local gui = Theme.make("ScreenGui", {
		Name = "SBE_Hud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local scale = Theme.make("UIScale", { Scale = Theme.screenScale(), Parent = gui })

	-- Player panel (top left)
	local panel = Theme.make("Frame", {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(330, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local levelText = Theme.label({
		Size = UDim2.fromOffset(330, 26),
		Font = Theme.fontBold,
		TextSize = 22,
		Text = "Lv 1",
		Parent = panel,
	})
	local _, hpFill, hpText =
		Theme.bar(panel, "Health", UDim2.fromOffset(300, 20), UDim2.fromOffset(0, 30), Theme.colors.hp)
	local _, spiritFill, spiritText =
		Theme.bar(panel, "Spirit", UDim2.fromOffset(300, 14), UDim2.fromOffset(0, 54), Theme.colors.spirit)
	local _, xpFill = Theme.bar(panel, "XP", UDim2.fromOffset(300, 8), UDim2.fromOffset(0, 72), Theme.colors.xp)
	local xpText = Theme.label({
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.fromOffset(330, 20),
		TextSize = 15,
		TextColor3 = Theme.colors.dim,
		Parent = panel,
	})
	local effectsRow = Theme.make("Frame", {
		Position = UDim2.fromOffset(0, 106),
		Size = UDim2.fromOffset(330, 26),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Theme.make(
		"UIListLayout",
		{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = effectsRow }
	)

	local menuButton = Theme.button({
		Position = UDim2.fromOffset(16, 168),
		Size = UDim2.fromOffset(140, 36),
		Text = "Menu",
		TextSize = 17,
		Parent = gui,
	})
	menuButton.Activated:Connect(function()
		Hud.menuRequested:Fire()
	end)

	-- Ability slots (bottom centre)
	local slots = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(300, 84),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		Parent = slots,
	})
	type Slot =
		{ actionId: string, abilityId: string?, cover: Frame, timer: TextLabel, key: TextLabel, locked: boolean }
	local slotList: { Slot } = {}
	local special = Data.weapons["wpn_hearthwick"].special_ability_id
	local specs: { { actionId: string, name: string, abilityId: string?, locked: boolean } } = {
		{ actionId = "ability_1", name = Data.abilities[special].name, abilityId = special, locked = false },
		{ actionId = "dodge_sprint", name = Data.abilities["abl_flash_step"].name, abilityId = nil, locked = false },
		{ actionId = "ultimate", name = Data.abilities["abl_eclipse_form"].name, abilityId = nil, locked = true },
	}
	for _, spec in specs do
		local frame = Theme.make("Frame", {
			Size = UDim2.fromOffset(88, 80),
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = 0.2,
			Parent = slots,
		})
		Theme.corner(frame)
		Theme.label({
			Position = UDim2.fromOffset(4, 30),
			Size = UDim2.new(1, -8, 0, 44),
			Text = spec.name .. (if spec.locked then "\n(later)" else ""),
			TextWrapped = true,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if spec.locked then Theme.colors.dim else Theme.colors.text,
			Parent = frame,
		})
		local key = Theme.label({
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 24),
			Font = Theme.fontBold,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.colors.accent,
			Parent = frame,
		})
		local cover = Theme.make("Frame", {
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.4,
			ZIndex = 4,
			Parent = frame,
		})
		local timer = Theme.label({
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.fontBold,
			TextSize = 24,
			ZIndex = 5,
			Text = "",
			Parent = frame,
		})
		table.insert(slotList, {
			actionId = spec.actionId,
			abilityId = spec.abilityId,
			cover = cover,
			timer = timer,
			key = key,
			locked = spec.locked,
		})
	end

	-- Boss bar (top centre)
	local bossFrame = Theme.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(480, 66),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local bossName = Theme.label({
		Size = UDim2.fromOffset(480, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.fontBold,
		TextSize = 20,
		Parent = bossFrame,
	})
	local _, bossFill, bossText =
		Theme.bar(bossFrame, "BossHealth", UDim2.fromOffset(480, 18), UDim2.fromOffset(0, 28), Theme.colors.boss)
	local bossPhase = Theme.label({
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.fromOffset(480, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		TextColor3 = Theme.colors.dim,
		Parent = bossFrame,
	})

	-- Objective and lock-on (top right, under the minimap) and the honest build note
	local objective = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 236),
		Size = UDim2.fromOffset(240, 60),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = 16,
		Parent = gui,
	})
	local lockText = Theme.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(300, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 220, 150),
		Text = "",
		Parent = gui,
	})
	Theme.label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -10),
		Size = UDim2.fromOffset(420, 18),
		TextSize = 13,
		TextColor3 = Theme.colors.dim,
		Text = "Phase 1 prototype: placeholder art, no sound yet",
		Parent = gui,
	})

	local map = Data.maps["map_akeboshi_harbor"]
	local arena = map and map.boss_arenas[1]
	local boss = arena and Data.enemies[arena.boss_id]
	local function objectiveText(): string
		if boss == nil then
			return ""
		end
		local info = boss.boss
		local title = if info then `, {info.title}` else ""
		local suggested = if info and info.suggested_level then ` (suggested level {info.suggested_level})` else ""
		return `Objective: defeat the {boss.name}{title}{suggested}`
	end
	objective.Text = objectiveText()

	Notifications.on("cooldown", function(m: any)
		if type(m.ability) == "string" and type(m.readyAt) == "number" then
			cooldowns[m.ability] = { readyAt = m.readyAt, duration = math.max(0.01, tonumber(m.duration) or 1) }
		end
	end)
	SettingsController.changed:Connect(function(id: string, value: any)
		if id == "text_scale" and type(value) == "number" then
			scale.Scale = Theme.screenScale() * value
		end
	end)
	CameraController.lockChanged:Connect(function(model: Model?)
		lockText.Text = if model then `Locked on: {model:GetAttribute("DisplayName") or "enemy"}` else ""
	end)

	local function refreshHints()
		for _, slot in slotList do
			slot.key.Text = InputController.hint(slot.actionId)
		end
		menuButton.Text = `Menu  [{InputController.hint("pause")}]`
	end
	refreshHints()
	InputController.deviceChanged:Connect(refreshHints)

	local elapsed = 0
	local effectsKey = ""
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < UPDATE_S then
			return
		end
		elapsed = 0
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local maxHp = math.max(1, humanoid.MaxHealth)
			hpFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / maxHp, 0, 1), 1)
			hpText.Text = `{fmt(humanoid.Health)} / {fmt(maxHp)}`
		end
		local spirit = tonumber(player:GetAttribute("Spirit")) or 0
		local spiritMax = math.max(1, tonumber(player:GetAttribute("SpiritMax")) or 100)
		spiritFill.Size = UDim2.fromScale(math.clamp(spirit / spiritMax, 0, 1), 1)
		spiritText.Text = `Spirit {spirit} / {spiritMax}`

		local level = tonumber(player:GetAttribute("Level")) or 1
		local xp = tonumber(player:GetAttribute("XP")) or 0
		local toNext = tonumber(player:GetAttribute("XPToNext")) or 0
		levelText.Text = `Lv {level}`
		if toNext > 0 then
			xpFill.Size = UDim2.fromScale(math.clamp(xp / toNext, 0, 1), 1)
			xpText.Text = `XP {fmt(xp)} / {fmt(toNext)}  ({fmt(toNext - xp)} to level {level + 1})`
		else
			xpFill.Size = UDim2.fromScale(1, 1)
			xpText.Text = `Highest level in this build ({player:GetAttribute("LevelCap") or level})`
		end

		-- active effects (rebuilt only when the text changes, about once a second)
		local now = Net.now()
		local chips = {}
		for name, expiry in player:GetAttributes() do
			if string.sub(name, 1, 7) == "Effect_" and type(expiry) == "number" and expiry > now then
				table.insert(chips, ` {effectName(string.sub(name, 8))} {math.ceil(expiry - now)}s `)
			end
		end
		table.sort(chips)
		local key = table.concat(chips, "|")
		if key ~= effectsKey then
			effectsKey = key
			for _, child in effectsRow:GetChildren() do
				if child:IsA("TextLabel") then
					child:Destroy()
				end
			end
			for _, text in chips do
				local chip = Theme.label({
					Size = UDim2.fromOffset(0, 24),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 0.3,
					BackgroundColor3 = Theme.colors.panel,
					TextSize = 14,
					Text = text,
					Parent = effectsRow,
				})
				Theme.corner(chip, 6)
			end
		end

		-- cooldowns
		for _, slot in slotList do
			local cd = slot.abilityId and cooldowns[slot.abilityId]
			local remaining = if cd then math.max(0, cd.readyAt - now) else 0
			slot.cover.Size = UDim2.fromScale(
				1,
				if slot.locked then 1 else math.clamp(remaining / (if cd then cd.duration else 1), 0, 1)
			)
			slot.timer.Text = if remaining > 0.05 then string.format("%.0f", math.ceil(remaining)) else ""
		end

		-- boss bar: shown near an active boss
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local shown = false
		local states = ReplicatedStorage:FindFirstChild("BossStates")
		if states and root then
			for _, state in states:GetChildren() do
				local ax, az, radius =
					state:GetAttribute("ArenaX"), state:GetAttribute("ArenaZ"), state:GetAttribute("ArenaRadius")
				if
					state:GetAttribute("Active")
					and type(ax) == "number"
					and type(az) == "number"
					and type(radius) == "number"
				then
					if Vector2.new(root.Position.X - ax, root.Position.Z - az).Magnitude <= radius + 40 then
						shown = true
						local hp = tonumber(state:GetAttribute("HP")) or 0
						local maxHp = math.max(1, tonumber(state:GetAttribute("MaxHP")) or 1)
						bossName.Text = `{state:GetAttribute("Name")}, {state:GetAttribute("Title")}`
						bossFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
						bossText.Text = `{fmt(hp)} / {fmt(maxHp)}`
						bossPhase.Text =
							`Phase {state:GetAttribute("Phase")} of {state:GetAttribute("PhaseCount")}: {state:GetAttribute(
								"PhaseName"
							)}`
					end
				end
			end
		end
		bossFrame.Visible = shown
	end)
end

return Hud
