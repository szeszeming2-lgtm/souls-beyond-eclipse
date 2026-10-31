--!strict
-- North-up minimap drawn from the map data: buildings, water, landmarks, hub, fast travel and
-- the boss arena, plus an arrow for the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local SIZE = 190
local SHOWN_ROLES = { building = true, landmark = true, water = true, platform = true, road = true }

local Minimap = {}

function Minimap.start()
	local map = Data.maps["map_akeboshi_harbor"]
	if map == nil then
		return
	end
	local gui = Theme.make(
		"ScreenGui",
		{ Name = "SBE_Minimap", ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") }
	)
	Theme.make("UIScale", { Scale = Theme.screenScale(), Parent = gui })
	local frame = Theme.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 34),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = 0.25,
		ClipsDescendants = true,
		Parent = gui,
	})
	Theme.corner(frame)
	Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 10),
		Size = UDim2.fromOffset(SIZE, 22),
		Text = map.name,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 16,
		Font = Theme.fontBold,
		Parent = gui,
	})

	local minX, minZ = map.bounds.min[1], map.bounds.min[3]
	local spanX, spanZ = map.bounds.max[1] - minX, map.bounds.max[3] - minZ
	local function toMap(x: number, z: number): UDim2
		return UDim2.fromScale((x - minX) / spanX, (z - minZ) / spanZ)
	end

	local colors = {
		building = Color3.fromRGB(120, 124, 140),
		landmark = Color3.fromRGB(210, 180, 130),
		water = Color3.fromRGB(40, 80, 120),
		platform = Color3.fromRGB(110, 100, 90),
		road = Color3.fromRGB(60, 60, 70),
	}
	for _, piece in map.blockout do
		if SHOWN_ROLES[piece.role] then
			Theme.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = toMap(piece.position[1], piece.position[3]),
				Size = UDim2.fromScale(piece.size[1] / spanX, piece.size[3] / spanZ),
				Rotation = if piece.rotation_deg then -piece.rotation_deg[2] else 0,
				BackgroundColor3 = colors[piece.role],
				BorderSizePixel = 0,
				Parent = frame,
			})
		end
	end
	local function dot(position: { number }, color: Color3, size: number)
		local d = Theme.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = toMap(position[1], position[3]),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = frame,
		})
		Theme.corner(d, size)
	end
	for _, hub in map.hubs do
		dot(hub.position, Color3.fromRGB(255, 190, 90), 10)
	end
	for _, point in map.fast_travel do
		dot(point.position, Color3.fromRGB(110, 210, 255), 8)
	end
	for _, arena in map.boss_arenas do
		local ring = Theme.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = toMap(arena.center[1], arena.center[3]),
			Size = UDim2.fromScale(arena.radius_studs * 2 / spanX, arena.radius_studs * 2 / spanZ),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = frame,
		})
		Theme.corner(ring, 200)
		Theme.make("UIStroke", { Color = Theme.colors.boss, Thickness = 2, Parent = ring })
	end

	local arrow = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		Text = "▲",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 5,
		Parent = frame,
	})
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = Workspace.CurrentCamera
		if root and camera then
			arrow.Position = toMap(root.Position.X, root.Position.Z)
			local look = camera.CFrame.LookVector
			arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
		end
	end)
end

return Minimap
