--!strict
-- Player settings, checked against the definitions in shared-data/settings.json. Pure.

local DataTypes = require(script.Parent.DataTypes)

local Settings = {}

type SettingDef = DataTypes.SettingDef

local function onPlatform(def: SettingDef, platform: string): boolean
	return table.find(def.platforms, platform) ~= nil
end

-- The definitions that apply on this platform ("roblox" or "pc").
function Settings.forPlatform(defs: { SettingDef }, platform: string): { SettingDef }
	local out = {}
	for _, def in defs do
		if onPlatform(def, platform) then
			table.insert(out, def)
		end
	end
	return out
end

function Settings.defaults(defs: { SettingDef }, platform: string): { [string]: any }
	local out = {}
	for _, def in Settings.forPlatform(defs, platform) do
		out[def.id] = def.default
	end
	return out
end

-- Checks one value. Sliders are clamped and snapped to their step. Returns (ok, cleanValue).
function Settings.coerce(def: SettingDef, raw: any): (boolean, any)
	if def.kind == "toggle" then
		return type(raw) == "boolean", raw
	elseif def.kind == "slider" then
		if type(raw) ~= "number" or raw ~= raw then
			return false, nil
		end
		local lo, hi, step = def.min :: number, def.max :: number, def.step :: number
		local snapped = lo + math.floor((math.clamp(raw, lo, hi) - lo) / step + 0.5) * step
		snapped = math.clamp(math.floor(snapped * 1000 + 0.5) / 1000, lo, hi)
		return true, snapped
	elseif def.kind == "choice" then
		if type(raw) ~= "string" then
			return false, nil
		end
		local options: { { value: string, label: string } } = def.options or {}
		for _, option in options do
			if option.value == raw then
				return true, raw
			end
		end
		return false, nil
	end
	return false, nil
end

-- A complete, valid settings table: valid saved values are kept, everything else is the default.
-- Returns (clean, idsThatWereReset).
function Settings.sanitize(
	saved: { [string]: any }?,
	defs: { SettingDef },
	platform: string
): ({ [string]: any }, { string })
	local clean = {}
	local reset = {}
	for _, def in Settings.forPlatform(defs, platform) do
		local raw = if saved then saved[def.id] else nil
		local ok, value = false, nil
		if raw ~= nil then
			ok, value = Settings.coerce(def, raw)
		end
		if ok then
			clean[def.id] = value
		else
			clean[def.id] = def.default
			if raw ~= nil then
				table.insert(reset, def.id)
			end
		end
	end
	return clean, reset
end

function Settings.find(defs: { SettingDef }, id: string): SettingDef?
	for _, def in defs do
		if def.id == id then
			return def
		end
	end
	return nil
end

return Settings
