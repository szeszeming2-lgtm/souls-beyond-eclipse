--!strict
-- Inventory rules. Pure: no Roblox APIs. Only the server changes a player's inventory.
--
-- Shape (saved as-is, so it uses only strings, numbers and arrays without gaps):
--   materials = { [material_id] = count }
--   weapons   = { { uid = "...", id = "wpn_...", tier = 0..5 }, ... }

local Inventory = {}

export type WeaponInstance = { uid: string, id: string, tier: number }
export type Inventory = { materials: { [string]: number }, weapons: { WeaponInstance } }

Inventory.MAX_WEAPONS = 200

function Inventory.new(): Inventory
	return { materials = {}, weapons = {} }
end

function Inventory.count(inv: Inventory, materialId: string): number
	return inv.materials[materialId] or 0
end

-- Adds up to `qty`, never past maxStack. Returns (added, overflow).
function Inventory.addMaterial(inv: Inventory, materialId: string, qty: number, maxStack: number): (number, number)
	qty = math.floor(qty)
	if qty <= 0 then
		return 0, 0
	end
	local have = inv.materials[materialId] or 0
	local added = math.max(0, math.min(qty, maxStack - have))
	if added > 0 then
		inv.materials[materialId] = have + added
	end
	return added, qty - added
end

-- Removes exactly qty, or nothing at all.
function Inventory.removeMaterial(inv: Inventory, materialId: string, qty: number): boolean
	qty = math.floor(qty)
	local have = inv.materials[materialId] or 0
	if qty <= 0 or have < qty then
		return false
	end
	local left = have - qty
	if left > 0 then
		inv.materials[materialId] = left
	else
		inv.materials[materialId] = nil
	end
	return true
end

function Inventory.hasMaterials(inv: Inventory, costs: { { material_id: string, qty: number } }): boolean
	local needed: { [string]: number } = {}
	for _, cost in costs do
		needed[cost.material_id] = (needed[cost.material_id] or 0) + cost.qty
	end
	for materialId, qty in needed do
		if Inventory.count(inv, materialId) < qty then
			return false
		end
	end
	return true
end

-- Spends every cost, or nothing if anything is missing.
function Inventory.spendMaterials(inv: Inventory, costs: { { material_id: string, qty: number } }): boolean
	if not Inventory.hasMaterials(inv, costs) then
		return false
	end
	for _, cost in costs do
		Inventory.removeMaterial(inv, cost.material_id, cost.qty)
	end
	return true
end

function Inventory.findWeapon(inv: Inventory, uid: string): WeaponInstance?
	for _, weapon in inv.weapons do
		if weapon.uid == uid then
			return weapon
		end
	end
	return nil
end

function Inventory.hasWeaponId(inv: Inventory, weaponId: string): boolean
	for _, weapon in inv.weapons do
		if weapon.id == weaponId then
			return true
		end
	end
	return false
end

-- Adds a weapon with a server-made unique id. Returns (ok, reason).
function Inventory.addWeapon(inv: Inventory, uid: string, weaponId: string): (boolean, string?)
	if uid == "" then
		return false, "missing_uid"
	end
	if Inventory.findWeapon(inv, uid) then
		return false, "duplicate_uid"
	end
	if #inv.weapons >= Inventory.MAX_WEAPONS then
		return false, "inventory_full"
	end
	table.insert(inv.weapons, { uid = uid, id = weaponId, tier = 0 })
	return true, nil
end

return Inventory
