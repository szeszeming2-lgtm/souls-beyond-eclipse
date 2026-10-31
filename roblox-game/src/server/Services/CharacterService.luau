--!strict
-- Player characters: stats from level, placeholder look, the equipped weapon model, and
-- respawning at checkpoints. Players use one uniform PLACEHOLDER body for now (their Roblox
-- avatar items are not loaded); character creation arrives in Phase 2.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Scaling = require(Shared.Rules.Scaling)
local PlaceholderModels = require(script.Parent.Parent.PlaceholderModels)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local ItemService = require(script.Parent.ItemService)

local CharacterService = {}

local P = Data.progression.stat_scaling
local MOVE = Data.combat.movement

export type Stats = { level: number, maxHp: number, attack: number, defense: number }

local checkpoints: { [Player]: Vector3? } = {}

function CharacterService.stats(player: Player): Stats
	local level = ProgressionService.level(player)
	return {
		level = level,
		maxHp = Scaling.round(Scaling.statAt(P.player_base.max_hp, level, P.growth_per_level)),
		attack = Scaling.statAt(P.player_base.attack, level, P.growth_per_level),
		defense = Scaling.statAt(P.player_base.defense, level, P.growth_per_level),
	}
end

local function color(hex: string?): Color3?
	if hex == nil then
		return nil
	end
	return Color3.fromHex(hex)
end

local function applyLook(player: Player, character: Model)
	local data = PlayerDataService.get(player)
	if data == nil then
		return
	end
	local skin = Data.cosmetics[data.appearance.skin_tone]
	local outfit = Data.cosmetics[data.appearance.outfit]
	local aura = Data.cosmetics[data.appearance.aura_color]
	local bodyColors = character:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
	local skinColor = color(skin and skin.color) or Color3.fromRGB(209, 154, 114)
	local outfitColor = color(outfit and outfit.color) or Color3.fromRGB(46, 58, 89)
	bodyColors.HeadColor3 = skinColor
	bodyColors.LeftArmColor3 = skinColor
	bodyColors.RightArmColor3 = skinColor
	bodyColors.LeftLegColor3 = outfitColor
	bodyColors.RightLegColor3 = outfitColor
	bodyColors.TorsoColor3 = outfitColor
	bodyColors.Parent = character
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and aura and aura.color then
		local light = root:FindFirstChild("AuraPlaceholder") :: PointLight? or Instance.new("PointLight")
		light.Name = "AuraPlaceholder"
		light.Color = Color3.fromHex(aura.color)
		light.Range = 9
		light.Brightness = 0.9
		light.Parent = root
	end
end

local function attachWeapon(player: Player, character: Model)
	local old = character:FindFirstChild("EquippedWeapon")
	if old then
		old:Destroy()
	end
	local hand = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if hand == nil then
		return
	end
	local weapon = ItemService.equippedWeapon(player)
	local model = PlaceholderModels.weapon(weapon.presentation.visual)
	model.Name = "EquippedWeapon"
	local grip = model.PrimaryPart :: BasePart
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = grip
	weld.C0 = CFrame.new(0, -0.4, -0.2)
	weld.Parent = grip
	model.Parent = character
end

function CharacterService.refreshStats(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local stats = CharacterService.stats(player)
	local ratio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	humanoid.MaxHealth = stats.maxHp
	humanoid.Health = math.max(1, stats.maxHp * ratio)
end

-- Where the player respawns (a boss arena's checkpoint), or nil for the map's spawn point.
function CharacterService.setCheckpoint(player: Player, position: Vector3?)
	checkpoints[player] = position
end

local function onCharacterAdded(player: Player, character: Model)
	PlayerDataService.whenReady(player, function()
		if player.Character ~= character then
			return
		end
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid == nil then
			return
		end
		humanoid.UseJumpPower = true
		humanoid.JumpPower = MOVE.jump_power
		humanoid.WalkSpeed = MOVE.walk_speed
		local stats = CharacterService.stats(player)
		humanoid.MaxHealth = stats.maxHp
		humanoid.Health = stats.maxHp
		applyLook(player, character)
		attachWeapon(player, character)
		local checkpoint = checkpoints[player]
		if checkpoint then
			task.defer(function()
				character:PivotTo(CFrame.new(checkpoint + Vector3.new(0, 4, 0)))
			end)
		end
		humanoid.Died:Connect(function()
			local data = PlayerDataService.get(player)
			if data then
				data.stats.deaths += 1
			end
		end)
	end)
end

function CharacterService.start()
	Players.RespawnTime = 3
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		checkpoints[player] = nil
	end)
	ProgressionService.leveled:Connect(function(player: Player)
		CharacterService.refreshStats(player)
	end)
	ItemService.equipmentChanged:Connect(function(player: Player)
		if player.Character then
			attachWeapon(player, player.Character)
		end
	end)
	-- A dev reset replaces the data: rebuild the character so stats and look match.
	PlayerDataService.wasReset:Connect(function(player: Player)
		checkpoints[player] = nil
		player:LoadCharacterAsync()
	end)
end

return CharacterService
