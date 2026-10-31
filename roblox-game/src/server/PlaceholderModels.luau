--!strict
-- PLACEHOLDER art built from plain parts, one builder per asset id in shared-data/assets.json.
-- Every model is named "[PLACEHOLDER] ..." and tagged with the "Placeholder" attribute. The
-- real models are specified in docs/ASSET_SPECS.md.

local PlaceholderModels = {}

local function part(props: { [string]: any }): BasePart
	local p: BasePart
	if props.Shape == "Ball" or props.Shape == "Cylinder" then
		local round = Instance.new("Part")
		round.Shape = if props.Shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Cylinder
		p = round
	elseif props.Shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
	end
	p.Name = props.Name or "Part"
	p.Size = props.Size or Vector3.one
	p.Color = props.Color or Color3.fromRGB(80, 80, 90)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.CanCollide = props.CanCollide == true
	p.CanQuery = props.CanQuery == true
	p.CanTouch = false
	p.Massless = props.Massless == true
	p.CastShadow = props.CastShadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function attach(model: Model, root: BasePart, child: BasePart, offset: CFrame)
	child.CFrame = root.CFrame * offset
	child.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = child
	weld.Parent = child
end

local function label(model: Model, name: string)
	model.Name = "[PLACEHOLDER] " .. name
	model:SetAttribute("Placeholder", true)
end

-- A weapon model with a "Grip" part to weld to the hand. Blade points along the grip's -Z.
function PlaceholderModels.weapon(assetId: string): Model
	local model = Instance.new("Model")
	local grip =
		part({ Name = "Grip", Size = Vector3.new(0.3, 0.3, 1.2), Color = Color3.fromRGB(45, 30, 25), Massless = true })
	grip.Parent = model
	model.PrimaryPart = grip
	if assetId == "ast_wpn_hearthwick" then
		attach(
			model,
			grip,
			part({
				Name = "Guard",
				Size = Vector3.new(0.9, 0.9, 0.15),
				Color = Color3.fromRGB(196, 150, 70),
				Material = Enum.Material.Metal,
				Massless = true,
			}),
			CFrame.new(0, 0, -0.65)
		)
		attach(
			model,
			grip,
			part({
				Name = "Blade",
				Size = Vector3.new(0.1, 0.32, 4.4),
				Color = Color3.fromRGB(255, 196, 120),
				Material = Enum.Material.Neon,
				Massless = true,
				CastShadow = false,
			}),
			CFrame.new(0, 0, -2.9)
		)
		label(model, "Hearthwick")
	else
		attach(
			model,
			grip,
			part({
				Name = "Blade",
				Size = Vector3.new(0.1, 0.3, 4),
				Color = Color3.fromRGB(200, 200, 210),
				Massless = true,
			}),
			CFrame.new(0, 0, -2.6)
		)
		label(model, assetId)
	end
	return model
end

export type EnemyBuild = { model: Model, root: BasePart, humanoid: Humanoid, radius: number, height: number }

local function enemyBase(
	name: string,
	rootSize: Vector3,
	rootColor: Color3,
	hipHeight: number
): (Model, BasePart, Humanoid)
	local model = Instance.new("Model")
	local root =
		part({ Name = "HumanoidRootPart", Size = rootSize, Color = rootColor, CanCollide = true, CanQuery = true })
	root.Parent = model
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = hipHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	label(model, name)
	return model, root, humanoid
end

function PlaceholderModels.enemy(assetId: string, displayName: string): EnemyBuild
	if assetId == "ast_enm_lampeater" then
		local model, root, humanoid = enemyBase(displayName, Vector3.new(5, 6, 3.5), Color3.fromRGB(30, 26, 38), 7)
		local dark = Color3.fromRGB(24, 20, 30)
		attach(
			model,
			root,
			part({ Name = "LeftLeg", Size = Vector3.new(1.2, 7, 1.2), Color = dark }),
			CFrame.new(-1.4, -6.5, 0)
		)
		attach(
			model,
			root,
			part({ Name = "RightLeg", Size = Vector3.new(1.2, 7, 1.2), Color = dark }),
			CFrame.new(1.4, -6.5, 0)
		)
		attach(
			model,
			root,
			part({ Name = "LeftArm", Size = Vector3.new(1, 8, 1), Color = dark }),
			CFrame.new(-3.2, -1.5, -0.5)
		)
		attach(
			model,
			root,
			part({ Name = "RightArm", Size = Vector3.new(1, 8, 1), Color = dark }),
			CFrame.new(3.2, -1.5, -0.5)
		)
		attach(
			model,
			root,
			part({ Name = "Head", Size = Vector3.new(2.2, 1.8, 2.2), Color = dark }),
			CFrame.new(0, 4, -0.4)
		)
		for i, offset in
			{
				Vector3.new(-1.2, 1.2, -1.6),
				Vector3.new(1.2, 1.2, -1.6),
				Vector3.new(-1, -0.8, -1.6),
				Vector3.new(1, -0.8, -1.6),
			}
		do
			attach(
				model,
				root,
				part({
					Name = "SwallowedLamp" .. i,
					Shape = "Ball",
					Size = Vector3.one * 1.1,
					Color = Color3.fromRGB(255, 214, 130),
					Material = Enum.Material.Neon,
					CastShadow = false,
				}),
				CFrame.new(offset)
			)
		end
		attach(
			model,
			root,
			part({
				Name = "EyeLeft",
				Shape = "Ball",
				Size = Vector3.one * 0.5,
				Color = Color3.fromRGB(255, 120, 60),
				Material = Enum.Material.Neon,
			}),
			CFrame.new(-0.5, 4.2, -1.5)
		)
		attach(
			model,
			root,
			part({
				Name = "EyeRight",
				Shape = "Ball",
				Size = Vector3.one * 0.5,
				Color = Color3.fromRGB(255, 120, 60),
				Material = Enum.Material.Neon,
			}),
			CFrame.new(0.5, 4.2, -1.5)
		)
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 200, 120)
		glow.Range = 14
		glow.Brightness = 1.5
		glow.Parent = root
		return { model = model, root = root, humanoid = humanoid, radius = 3.5, height = 16 }
	end
	-- Gloamling (and the fallback for any enemy without its own builder yet)
	local model, root, humanoid = enemyBase(displayName, Vector3.new(2.6, 2, 4), Color3.fromRGB(43, 43, 51), 1.2)
	attach(
		model,
		root,
		part({ Name = "Head", Size = Vector3.new(1.8, 1.4, 1.6), Color = Color3.fromRGB(36, 36, 44) }),
		CFrame.new(0, 0.6, -2.4)
	)
	attach(
		model,
		root,
		part({
			Name = "EmberEye",
			Shape = "Ball",
			Size = Vector3.one * 0.7,
			Color = Color3.fromRGB(255, 140, 50),
			Material = Enum.Material.Neon,
			CastShadow = false,
		}),
		CFrame.new(0, 0.8, -3.2)
	)
	for i, offset in
		{
			Vector3.new(-0.9, -1.4, -1.3),
			Vector3.new(0.9, -1.4, -1.3),
			Vector3.new(-0.9, -1.4, 1.3),
			Vector3.new(0.9, -1.4, 1.3),
		}
	do
		attach(
			model,
			root,
			part({ Name = "Leg" .. i, Size = Vector3.new(0.5, 1.2, 0.5), Color = Color3.fromRGB(30, 30, 36) }),
			CFrame.new(offset)
		)
	end
	return { model = model, root = root, humanoid = humanoid, radius = 2, height = 4 }
end

return PlaceholderModels
