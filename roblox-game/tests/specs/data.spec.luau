-- Generated GameData modules run in a real Luau VM and hold exactly the JSON data.

local fs, serde = lune.fs, lune.serde

local function sameData(luauValue: any, jsonValue: any): boolean
	if type(jsonValue) == "table" and type(luauValue) == "table" then
		-- An empty Luau table stands for an empty JSON array or object.
		if next(jsonValue) == nil then
			return next(luauValue) == nil
		end
		for k, v in jsonValue do
			local key = if type(k) == "number" then k else k
			if k ~= "$schema" and not sameData(luauValue[key], v) then
				return false
			end
		end
		for k in luauValue do
			if jsonValue[k] == nil then
				return false
			end
		end
		return true
	end
	return luauValue == jsonValue
end

local function pascal(name: string): string
	local out = ""
	for part in string.gmatch(name, "[^_%-]+") do
		out ..= string.upper(string.sub(part, 1, 1)) .. string.sub(part, 2)
	end
	return out
end

describe("GameData", function()
	local GameData = loader:require(Shared.GameData)

	it("loads through its index like it does in Roblox", function()
		expect(GameData.Items.Weapons.entries[1].id).toBe("wpn_hearthwick")
		expect(#GameData.Progression.XpTable.xp_to_next).toBe(2999)
	end)

	it("is frozen so game code cannot change shared data", function()
		expect(table.isfrozen(GameData.Items.Weapons)).toBe(true)
		expect(table.isfrozen(GameData.Items.Weapons.entries[1].upgrade_tiers[1])).toBe(true)
		expect(function()
			(GameData.Combat :: any).damage = nil
		end).toThrow()
	end)

	it("matches every JSON file exactly", function()
		local checked = 0
		local function walk(dir: string, parts: { string })
			for _, name in fs.readDir(dir) do
				local path = dir .. "/" .. name
				if fs.isDir(path) then
					if name ~= "schemas" then
						local nextParts = table.clone(parts)
						table.insert(nextParts, pascal(name))
						walk(path, nextParts)
					end
				elseif string.match(name, "%.json$") then
					local json = serde.decode("json", fs.readFile(path))
					local node = GameData
					for _, part in parts do
						node = node[part]
					end
					local module = node[pascal(string.gsub(name, "%.json$", ""))]
					expect(module ~= nil).toBe(true)
					if not sameData(module, json) then
						error(`{path} does not match its Luau module`)
					end
					checked += 1
				end
			end
		end
		walk("shared-data", {})
		expect(checked).toBeAtLeast(20)
	end)
end)

describe("Data catalog", function()
	local Data = loader:require(Shared.Data)

	it("indexes entries by id", function()
		expect(Data.weapons["wpn_hearthwick"].name).toBe("Hearthwick")
		expect(Data.enemies["enm_lampeater"].boss ~= nil).toBe(true)
		expect(Data.maps["map_akeboshi_harbor"].region_id).toBe("reg_akeboshi_city")
		expect(Data.difficultyModes["story"].telegraph_time_mult).toBeGreaterThan(1)
	end)

	it("knows which ids are inventory items", function()
		expect(Data.itemKind("wpn_hearthwick")).toBe("weapon")
		expect(Data.itemKind("mat_gloam_dust")).toBe("material")
		expect(Data.itemKind("abl_wickflare")).toBe(nil)
	end)
end)

describe("Shared rules are pure", function()
	it("every Rules module loads with no access to Roblox", function()
		for _, module in Shared.Rules:GetChildren() do
			local ok, err = pcall(function()
				return loader:require(module)
			end)
			if not ok then
				error(`{module.Name} needs Roblox: {err}`)
			end
		end
	end)
end)
