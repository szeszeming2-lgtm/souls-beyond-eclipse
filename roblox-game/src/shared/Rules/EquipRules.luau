--!strict
-- Can this player equip this weapon? Pure: no Roblox APIs. The server is the only one that asks.

local EquipRules = {}

export type EquipCheck = {
	level: number,
	weapon: { uid: string, id: string, tier: number }?, -- the owned copy, nil if not owned
	weaponDef: { level_req: number, weapon_class: string }?, -- nil if the id is unknown
	archetypeWeaponClasses: { string },
}

-- Returns (true, nil) or (false, reason). Reasons: not_owned, unknown_weapon,
-- level_too_low, wrong_weapon_class.
function EquipRules.canEquipWeapon(check: EquipCheck): (boolean, string?)
	if check.weapon == nil then
		return false, "not_owned"
	end
	local def = check.weaponDef
	if def == nil then
		return false, "unknown_weapon"
	end
	if check.level < def.level_req then
		return false, "level_too_low"
	end
	if not table.find(check.archetypeWeaponClasses, def.weapon_class) then
		return false, "wrong_weapon_class"
	end
	return true, nil
end

return EquipRules
