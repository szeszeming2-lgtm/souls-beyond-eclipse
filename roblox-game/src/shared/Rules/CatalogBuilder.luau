--!strict
-- Builds typed id lookups from the generated GameData modules. Pure: the game passes in the
-- real GameData, the Lune tests pass in the same modules loaded from disk.

local DataTypes = require(script.Parent.DataTypes)

export type Catalog = {
	weapons: { [string]: DataTypes.Weapon },
	materials: { [string]: DataTypes.Material },
	abilities: { [string]: DataTypes.Ability },
	movesets: { [string]: DataTypes.Moveset },
	enemies: { [string]: DataTypes.Enemy },
	statusEffects: { [string]: DataTypes.StatusEffect },
	archetypes: { [string]: DataTypes.Archetype },
	regions: { [string]: DataTypes.Region },
	maps: { [string]: DataTypes.MapData },
	cosmetics: { [string]: DataTypes.CosmeticOption },
	difficultyModes: { [string]: DataTypes.DifficultyMode },
	progression: DataTypes.Progression,
	xpToNext: { number },
	combat: DataTypes.Combat,
	difficulty: DataTypes.Difficulty,
	inputActions: DataTypes.InputActions,
	settings: DataTypes.Settings,
	customization: DataTypes.Customization,
	itemKind: (id: string) -> "weapon" | "material" | nil,
}

local function index<T>(entries: { any }): { [string]: T }
	local out: { [string]: T } = {}
	for _, entry in entries do
		out[entry.id] = entry :: T
	end
	return out
end

local CatalogBuilder = {}

function CatalogBuilder.build(gameData: any): Catalog
	local maps: { [string]: DataTypes.MapData } = {}
	for _, mapModule in gameData.Maps do
		maps[mapModule.id] = mapModule :: DataTypes.MapData
	end
	local weapons = index(gameData.Items.Weapons.entries) :: { [string]: DataTypes.Weapon }
	local materials = index(gameData.Items.Materials.entries) :: { [string]: DataTypes.Material }

	local catalog: Catalog = {
		weapons = weapons,
		materials = materials,
		abilities = index(gameData.Abilities.entries),
		movesets = index(gameData.Movesets.entries),
		enemies = index(gameData.Enemies.entries),
		statusEffects = index(gameData.StatusEffects.entries),
		archetypes = index(gameData.Archetypes.entries),
		regions = index(gameData.Regions.entries),
		maps = maps,
		cosmetics = index(gameData.Customization.options),
		difficultyModes = index(gameData.Difficulty.modes),
		progression = gameData.Progression.Progression :: DataTypes.Progression,
		xpToNext = gameData.Progression.XpTable.xp_to_next :: { number },
		combat = gameData.Combat :: DataTypes.Combat,
		difficulty = gameData.Difficulty :: DataTypes.Difficulty,
		inputActions = gameData.InputActions :: DataTypes.InputActions,
		settings = gameData.Settings :: DataTypes.Settings,
		customization = gameData.Customization :: DataTypes.Customization,
		itemKind = function(id: string): "weapon" | "material" | nil
			if weapons[id] then
				return "weapon"
			elseif materials[id] then
				return "material"
			end
			return nil
		end,
	}
	return catalog
end

return CatalogBuilder
