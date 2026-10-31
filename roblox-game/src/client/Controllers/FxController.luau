--!strict
-- Visual feedback from server events: attack tells, damage numbers, hit flashes, parries.
-- All PLACEHOLDER effects (plain neon parts and text). Effects follow the settings for damage
-- numbers, flash intensity, colour-blind palette and effects quality.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local SettingsController = require(script.Parent.SettingsController)
local CameraController = require(script.Parent.CameraController)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local DAMAGE_NUMBER_S = 0.8

local FxController = {}

local fxFolder: Folder? = nil
local numberPool: { BillboardGui } = {}
local activeNumbers = 0

local function folder(): Folder
	if fxFolder == nil or fxFolder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "SBE_Fx"
		f.Parent = Workspace
		fxFolder = f
	end
	return fxFolder :: Folder
end

local function quality(): string
	local setting = SettingsController.get("effects_quality")
	if setting ~= "auto" and type(setting) == "string" then
		return setting
	end
	local ok, level = pcall(function()
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	if not ok or type(level) ~= "number" or level == 0 then
		return "medium"
	end
	return if level <= 3 then "low" elseif level <= 6 then "medium" elseif level <= 8 then "high" else "ultra"
end

local function maxNumbers(): number
	local q = quality()
	return if q == "low" then 6 elseif q == "medium" then 12 else 24
end

local function flashScale(): number
	local v = SettingsController.get("flash_intensity")
	return if type(v) == "number" then v else 1
end

local function tellPalette(): { normal: Color3, unblockable: Color3 }
	return Theme.tellColors[SettingsController.get("colorblind") or "none"] or Theme.tellColors.none
end

local function flatPart(
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	transparency: number,
	shape: Enum.PartType?
): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = size
	part.CFrame = cframe
	if shape then
		part.Shape = shape
	end
	part.Parent = folder()
	return part
end

-- ------------------------------------------------------------------ damage numbers
local function takeNumber(): BillboardGui
	local pooled = table.remove(numberPool)
	if pooled then
		return pooled
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local text = Theme.label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.fontBold,
		TextSize = 26,
		TextStrokeTransparency = 0.2,
	})
	text.Parent = gui
	return gui
end

local function popText(position: Vector3, message: string, color: Color3, big: boolean)
	if activeNumbers >= maxNumbers() then
		return
	end
	activeNumbers += 1
	local gui = takeNumber()
	local anchor = flatPart(Vector3.one * 0.1, CFrame.new(position), color, 1)
	gui.Adornee = anchor
	local text = gui:FindFirstChild("Text") :: TextLabel
	text.Text = message
	text.TextColor3 = color
	text.TextSize = if big then 34 else 26
	text.TextTransparency = 0
	gui.StudsOffset = Vector3.new(math.random() - 0.5, 1, 0)
	gui.Parent = player:WaitForChild("PlayerGui")
	TweenService:Create(gui, TweenInfo.new(DAMAGE_NUMBER_S), { StudsOffset = gui.StudsOffset + Vector3.new(0, 2.5, 0) })
		:Play()
	TweenService:Create(
		text,
		TweenInfo.new(DAMAGE_NUMBER_S, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }
	):Play()
	task.delay(DAMAGE_NUMBER_S, function()
		anchor:Destroy()
		gui.Parent = nil
		gui.Adornee = nil :: any
		table.insert(numberPool, gui)
		activeNumbers -= 1
	end)
end

-- Damage numbers can be turned off in Settings; floating words (PARRY...) always show.
function FxController.damageNumber(position: Vector3, amount: number, color: Color3, big: boolean)
	if SettingsController.get("damage_numbers") ~= false then
		popText(position, tostring(amount), color, big)
	end
end

function FxController.floatingText(position: Vector3, message: string, color: Color3)
	popText(position, message, color, true)
end

-- ------------------------------------------------------------------ hit flash
function FxController.flash(model: Instance?, color: Color3)
	if model == nil or not model:IsA("Model") or quality() == "low" then
		return
	end
	local scale = flashScale()
	if scale <= 0 then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.FillTransparency = 1 - 0.6 * scale
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, 0.12)
end

local function modelPosition(model: any): Vector3?
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return nil
	end
	local primary = model.PrimaryPart
	if primary == nil then
		return nil
	end
	local height = model:GetAttribute("Height")
	return primary.Position + Vector3.new(0, if type(height) == "number" then height * 0.5 else 2, 0)
end

-- ------------------------------------------------------------------ attack tells
local function showTell(event: any)
	local duration = tonumber(event.dur) or 0.5
	local palette = tellPalette()
	local color = if event.unblockable then palette.unblockable else palette.normal
	local center = if typeof(event.center) == "Vector3" then event.center else Vector3.zero
	local dir = if typeof(event.dir) == "Vector3" then event.dir else Vector3.new(0, 0, -1)
	local groundY = tonumber(event.ground) or center.Y
	local base = Vector3.new(center.X, groundY + 0.15, center.Z)
	local facing = CFrame.lookAt(base, base + Vector3.new(dir.X, 0, dir.Z))
	local parts: { BasePart } = {}
	local shape = event.shape
	local r = tonumber(event.r) or 6
	if shape == "circle" then
		table.insert(
			parts,
			flatPart(
				Vector3.new(0.2, r * 2, r * 2),
				CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)),
				color,
				0.75,
				Enum.PartType.Cylinder
			)
		)
	elseif shape == "ring" then
		local width = tonumber(event.w) or 4
		local segments = if quality() == "low" then 16 else 28
		for i = 1, segments do
			local angle = (i / segments) * math.pi * 2
			local p = base + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
			local length = 2 * math.pi * r / segments + 0.4
			table.insert(
				parts,
				flatPart(
					Vector3.new(width, 0.2, length),
					CFrame.lookAt(p, base) * CFrame.Angles(0, math.rad(90), 0),
					color,
					0.6
				)
			)
		end
	elseif shape == "line" or shape == "box" then
		local length = tonumber(event.len) or r
		local width = tonumber(event.w) or 4
		table.insert(
			parts,
			flatPart(Vector3.new(width, 0.2, length), facing * CFrame.new(0, 0, -length / 2), color, 0.65)
		)
	else
		-- cone: a fan of thin slices
		local angle = math.rad(tonumber(event.ang) or 90)
		local slices = if quality() == "low" then 3 else 7
		for i = 0, slices - 1 do
			local a = -angle / 2 + angle * (i + 0.5) / slices
			local width = 2 * r * math.tan(angle / slices / 2) + 0.3
			table.insert(
				parts,
				flatPart(
					Vector3.new(width, 0.2, r),
					facing * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, -r / 2),
					color,
					0.7
				)
			)
		end
	end
	for _, part in parts do
		TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Transparency = 0.25 }):Play()
		Debris:AddItem(part, duration + 0.1)
	end

	local model = event.target
	if typeof(model) == "Instance" and model:IsA("Model") then
		if event.visual == "body_glow" or event.visual == "weapon_flash" then
			local glow = Instance.new("Highlight")
			glow.FillColor = color
			glow.FillTransparency = 0.55
			glow.OutlineColor = color
			glow.Parent = model
			Debris:AddItem(glow, duration)
		end
		if event.unblockable then
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(44, 44)
			gui.AlwaysOnTop = true
			gui.StudsOffsetWorldSpace = Vector3.new(0, (tonumber(model:GetAttribute("Height")) or 4) + 1.5, 0)
			gui.Adornee = model.PrimaryPart :: any
			local mark = Theme.label({
				Size = UDim2.fromScale(1, 1),
				Text = "!",
				TextScaled = true,
				Font = Theme.fontBold,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextStrokeTransparency = 0,
			})
			mark.Parent = gui
			gui.Parent = player:WaitForChild("PlayerGui")
			Debris:AddItem(gui, duration)
		end
	end
end

-- Placeholder swing arc in front of a character.
function FxController.swing(character: Model?, heavy: boolean)
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local arc = flatPart(
		Vector3.new(if heavy then 9 else 6, 0.2, 2.5),
		root.CFrame * CFrame.new(0, 0.5, -3.5),
		Theme.colors.accent,
		0.5
	)
	TweenService:Create(arc, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	Debris:AddItem(arc, 0.2)
end

-- Placeholder Wickflare: a flame wedge that rolls forward along the attack line.
function FxController.wickflare(character: Model?, windup: number, active: number)
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	task.delay(windup, function()
		local start = root.CFrame * CFrame.new(0, 0, -2)
		local wave = flatPart(Vector3.new(6, 2.5, 1.2), start, Color3.fromRGB(255, 170, 70), 0.2)
		TweenService:Create(
			wave,
			TweenInfo.new(math.max(active, 0.2), Enum.EasingStyle.Linear),
			{ CFrame = start * CFrame.new(0, 0, -38), Transparency = 0.8 }
		):Play()
		Debris:AddItem(wave, math.max(active, 0.2) + 0.05)
	end)
end

local function characterOf(p: any): Model?
	if typeof(p) == "Instance" and p:IsA("Player") then
		return p.Character
	end
	return nil
end

function FxController.start()
	Net.fx().OnClientEvent:Connect(function(event: any)
		if type(event) ~= "table" then
			return
		end
		local kind = event.k
		if kind == "tell" then
			showTell(event)
		elseif kind == "hit" then
			local position = modelPosition(event.target)
			if position then
				local mine = event.by == player.UserId
				local color = if event.crit
					then Color3.fromRGB(255, 230, 120)
					elseif event.dot then Color3.fromRGB(255, 150, 80)
					else Color3.fromRGB(255, 255, 255)
				if mine or event.dot then
					FxController.damageNumber(position, tonumber(event.n) or 0, color, event.crit == true)
				end
				FxController.flash(event.target, Color3.fromRGB(255, 255, 255))
				if mine and not event.dot then
					CameraController.shake(if event.crit then 0.35 else 0.15)
				end
			end
		elseif kind == "hurt" then
			CameraController.shake(0.4)
			FxController.flash(player.Character, Color3.fromRGB(255, 60, 60))
		elseif kind == "swing" then
			if event.p ~= player then
				FxController.swing(characterOf(event.p), event.chain == "heavy")
			end
		elseif kind == "cast" then
			if event.p ~= player then
				FxController.wickflare(characterOf(event.p), tonumber(event.windup) or 0, tonumber(event.active) or 0.3)
			end
		elseif kind == "parry" then
			local character = characterOf(event.p)
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				FxController.floatingText(root.Position + Vector3.new(0, 3, 0), "PARRY", Color3.fromRGB(255, 220, 120))
				if event.p == player then
					CameraController.shake(0.3)
				end
			end
		elseif kind == "perfect" then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				FxController.floatingText(
					root.Position + Vector3.new(0, 3, 0),
					"Perfect dodge",
					Color3.fromRGB(140, 220, 255)
				)
			end
		elseif kind == "stagger" then
			local position = modelPosition(event.target)
			if position then
				FxController.floatingText(position + Vector3.new(0, 1, 0), "Staggered", Color3.fromRGB(255, 200, 120))
			end
		elseif kind == "guard_break" then
			CameraController.shake(0.5)
		end
	end)
end

return FxController
