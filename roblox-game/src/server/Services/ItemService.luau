--!strict
-- Inventory changes on the server: starter kit, drops, equipping. Uses Rules/Inventory and
-- Rules/EquipRules, which are tested in Lune.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Net = require(Shared.Net)
local Inventory = require(Shared.Rules.Inventory)
local EquipRules = require(Shared.Rules.EquipRules)
local DataTypes = require(Shared.Rules.DataTypes)
local Signal = require(Shared.Util.Signal)
local PlayerDataService = require(script.Parent.PlayerDataService)

-- Phase 1 has no quests yet, so new players get the opening quest's weapon right away.
local STARTER_WEAPON = "wpn_hearthwick"

local ItemService = {}
ItemService.equipmentChanged = Signal.new() -- (player)

local rng = Random.new()

function ItemService.equippedWeapon(player: Player): (DataTypes.Weapon, Inventory.WeaponInstance?)
	local data = PlayerDataService.get(player)
	if data then
		local instance = Inventory.findWeapon(data.inventory, data.equipment.weapon_uid)
		if instance and Data.weapons[instance.id] then
			return Data.weapons[instance.id], instance
		end
	end
	return Data.weapons[STARTER_WEAPON], nil
end

function ItemService.equip(player: Player, uid: string): (boolean, string?)
	local data = PlayerDataService.get(player)
	if data == nil then
		return false, "not_loaded"
	end
	local instance = Inventory.findWeapon(data.inventory, uid)
	local archetype = Data.archetypes[data.archetype_id]
	local ok, reason = EquipRules.canEquipWeapon({
		level = data.level,
		weapon = instance,
		weaponDef = if instance then Data.weapons[instance.id] else nil,
		archetypeWeaponClasses = if archetype then archetype.weapon_classes else {},
	})
	if ok then
		data.equipment.weapon_uid = uid
		ItemService.equipmentChanged:Fire(player)
	end
	return ok, reason
end

function ItemService.giveWeapon(player: Player, weaponId: string): string?
	local data = PlayerDataService.get(player)
	if data == nil or Data.weapons[weaponId] == nil then
		return nil
	end
	local uid = HttpService:GenerateGUID(false)
	local ok = Inventory.addWeapon(data.inventory, uid, weaponId)
	return if ok then uid else nil
end

-- Rolls an enemy's drop table and puts the loot straight into the inventory.
function ItemService.grantDrops(player: Player, drops: { DataTypes.Drop })
	local data = PlayerDataService.get(player)
	if data == nil then
		return
	end
	local gained = {}
	for _, drop in drops do
		if rng:NextNumber() < drop.chance then
			local qty = rng:NextInteger(drop.qty_min, drop.qty_max)
			local kind = Data.itemKind(drop.item_id)
			if kind == "material" then
				local added =
					Inventory.addMaterial(data.inventory, drop.item_id, qty, Data.materials[drop.item_id].max_stack)
				if added > 0 then
					table.insert(gained, { id = drop.item_id, name = Data.materials[drop.item_id].name, qty = added })
				end
			elseif kind == "weapon" then
				for _ = 1, qty do
					if ItemService.giveWeapon(player, drop.item_id) then
						table.insert(gained, { id = drop.item_id, name = Data.weapons[drop.item_id].name, qty = 1 })
					end
				end
			end
		end
	end
	if #gained > 0 then
		Net.event("Notify"):FireClient(player, { kind = "loot", items = gained })
	end
end

function ItemService.start()
	PlayerDataService.ready:Connect(function(player: Player, data)
		if not data.flags.starter_kit_given then
			local uid = ItemService.giveWeapon(player, STARTER_WEAPON)
			if uid then
				data.equipment.weapon_uid = uid
				data.flags.starter_kit_given = true
			end
		end
		ItemService.equipmentChanged:Fire(player)
	end)
end

return ItemService
