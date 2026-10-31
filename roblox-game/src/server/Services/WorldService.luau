--!strict
-- Builds every map from shared-data/maps as grey-box BLOCKOUT geometry: the ground, buildings
-- and landmarks, plus visible markers for hubs, fast-travel points, the boss arena and secrets.
-- Real environment art replaces this later (asset ast_env_akeboshi_harbor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local DataTypes = require(Shared.Rules.DataTypes)

local WorldService = {}

-- Placeholder colours per blockout role (presentation only).
local PALETTE: { [string]: { color: Color3, material: Enum.Material, transparency: number } } = {
	ground = { color = Color3.fromRGB(70, 72, 80), material = Enum.Material.Concrete, transparency = 0 },
	road = { color = Color3.fromRGB(46, 47, 54), material = Enum.Material.Asphalt, transparency = 0 },
	building = { color = Color3.fromRGB(104, 108, 122), material = Enum.Material.SmoothPlastic, transparency = 0 },
	landmark = { color = Color3.fromRGB(180, 150, 110), material = Enum.Material.SmoothPlastic, transparency = 0 },
	water = { color = Color3.fromRGB(30, 60, 90), material = Enum.Material.Glass, transparency = 0.3 },
	hazard = { color = Color3.fromRGB(150, 50, 50), material = Enum.Material.SmoothPlastic, transparency = 0 },
	prop = { color = Color3.fromRGB(140, 140, 150), material = Enum.Material.SmoothPlastic, transparency = 0 },
	wall = { color = Color3.fromRGB(60, 62, 70), material = Enum.Material.SmoothPlastic, transparency = 0.6 },
	ramp = { color = Color3.fromRGB(110, 110, 120), material = Enum.Material.SmoothPlastic, transparency = 0 },
	platform = { color = Color3.fromRGB(96, 88, 80), material = Enum.Material.WoodPlanks, transparency = 0 },
}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	style: { color: Color3, material: Enum.Material, transparency: number },
	collide: boolean,
	shape: string?
): BasePart
	local p: BasePart
	if shape == "wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if shape == "cylinder" then
			part.Shape = Enum.PartType.Cylinder
		elseif shape == "ball" then
			part.Shape = Enum.PartType.Ball
		end
		p = part
	end
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = style.color
	p.Material = style.material
	p.Transparency = style.transparency
	p.CanCollide = collide
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(adornee: BasePart, text: string, color: Color3, maxDistance: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, adornee.Size.Y / 2 + 3, 0)
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.Text = text
	text_.TextColor3 = color
	text_.TextStrokeTransparency = 0.3
	text_.Font = Enum.Font.GothamBold
	text_.TextSize = 18
	text_.Parent = gui
	gui.Parent = adornee
end

local function marker(parent: Instance, name: string, position: Vector3, color: Color3, height: number): BasePart
	local style = { color = color, material = Enum.Material.Neon, transparency = 0.35 }
	local pillar = block(
		parent,
		name,
		Vector3.new(1.2, height, 1.2),
		CFrame.new(position + Vector3.new(0, height / 2, 0)),
		style,
		false
	)
	pillar.CastShadow = false
	return pillar
end

local function buildMap(map: DataTypes.MapData): Folder
	local folder = Instance.new("Folder")
	folder.Name = map.id .. " [BLOCKOUT]"

	local geometry = Instance.new("Folder")
	geometry.Name = "Blockout"
	geometry.Parent = folder
	for index, piece in map.blockout do
		local style = PALETTE[piece.role] or PALETTE.prop
		local size = v3(piece.size)
		local cframe = CFrame.new(v3(piece.position))
		if piece.rotation_deg then
			local r = piece.rotation_deg
			cframe *= CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
		end
		if piece.shape == "cylinder" then
			-- Data cylinders stand upright: size = [diameter, height, diameter].
			-- Roblox cylinders lie along X, so turn them up and swap the axes.
			size = Vector3.new(size.Y, size.X, size.Z)
			cframe *= CFrame.Angles(0, 0, math.rad(90))
		end
		block(geometry, piece.label or `{piece.role} {index}`, size, cframe, style, piece.collide ~= false, piece.shape)
	end

	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = folder
	for _, hub in map.hubs do
		local m = marker(markers, hub.id, v3(hub.position), Color3.fromRGB(255, 190, 90), 10)
		label(m, hub.name, Color3.fromRGB(255, 220, 160), 250)
	end
	for _, point in map.fast_travel do
		local m = marker(markers, point.id, v3(point.position), Color3.fromRGB(110, 210, 255), 7)
		label(m, "Fast travel: " .. point.name, Color3.fromRGB(170, 230, 255), 200)
	end
	for _, landmark in map.landmarks do
		local anchor = marker(
			markers,
			landmark.id,
			v3(landmark.position) + Vector3.new(0, landmark.size[2], 0),
			Color3.fromRGB(255, 240, 200),
			1
		)
		anchor.Transparency = 1
		label(anchor, landmark.name, Color3.fromRGB(255, 240, 210), 600)
	end
	for _, arena in map.boss_arenas do
		local ring = block(
			markers,
			arena.id,
			Vector3.new(0.4, arena.radius_studs * 2, arena.radius_studs * 2),
			CFrame.new(v3(arena.center) + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			{ color = Color3.fromRGB(200, 60, 80), material = Enum.Material.Neon, transparency = 0.85 },
			false,
			"cylinder"
		)
		ring.CastShadow = false
	end
	for _, secret in map.secrets do
		local sparkle = block(
			markers,
			secret.id,
			Vector3.one * 1.2,
			CFrame.new(v3(secret.position) + Vector3.new(0, 1.5, 0)),
			{ color = Color3.fromRGB(255, 255, 200), material = Enum.Material.Neon, transparency = 0.2 },
			false,
			"ball"
		)
		sparkle.CastShadow = false
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Transparency = 0.5
	spawn.Color = Color3.fromRGB(255, 190, 90)
	spawn.Material = Enum.Material.Neon
	spawn.CFrame = CFrame.new(v3(map.player_spawn.position))
		* CFrame.Angles(0, math.rad(map.player_spawn.facing_deg), 0)
	spawn.Parent = folder

	return folder
end

function WorldService.start()
	workspace.FallenPartsDestroyHeight = -100
	local root = Instance.new("Folder")
	root.Name = "World"
	for _, map in Data.maps do
		buildMap(map).Parent = root
	end
	root.Parent = workspace
	-- Remove the default baseplate/spawn if the place has them (we build our own).
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = workspace:FindFirstChild(name)
		if old and old.Parent == workspace then
			old:Destroy()
		end
	end
end

return WorldService
