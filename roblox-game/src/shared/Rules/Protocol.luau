--!strict
-- What a client is allowed to ask the server. Pure, so the rejection rules are tested in Lune.
--
-- Clients send INTENTS only ("I pressed light attack"). There is no message that carries XP,
-- currency, damage, items or rewards, and any payload with fields not listed here is rejected.

local Protocol = {}

-- action name -> allowed extra fields and how to check them
local ACTIONS: { [string]: { [string]: string } } = {
	light = {},
	heavy = {},
	special = {},
	dodge = { dir = "direction" },
	guard_start = {},
	guard_end = {},
	assist_accept = { kind = "assist_kind" },
	menu_open = {},
	menu_close = {},
}

local ASSIST_KINDS = { support_buff = true }

local function checkField(kind: string, v: any): boolean
	if kind == "direction" then
		-- A flat direction {x, z}: finite numbers, length at most ~1.
		if type(v) ~= "table" or type(v.x) ~= "number" or type(v.z) ~= "number" then
			return false
		end
		if v.x ~= v.x or v.z ~= v.z then
			return false
		end
		local length = math.sqrt(v.x * v.x + v.z * v.z)
		return length <= 1.01
	elseif kind == "assist_kind" then
		return type(v) == "string" and ASSIST_KINDS[v] == true
	end
	return false
end

export type Action = { a: string, dir: { x: number, z: number }?, kind: string? }

-- Returns the action, or nil and a reason. Never errors on bad input.
function Protocol.parseAction(payload: any): (Action?, string?)
	if type(payload) ~= "table" then
		return nil, "not_a_table"
	end
	local name = payload.a
	if type(name) ~= "string" then
		return nil, "missing_action"
	end
	local allowed = ACTIONS[name]
	if allowed == nil then
		return nil, "unknown_action"
	end
	for key, v in payload do
		if key ~= "a" then
			local kind = if type(key) == "string" then allowed[key] else nil
			if kind == nil then
				return nil, "unexpected_field"
			end
			if not checkField(kind, v) then
				return nil, "bad_field"
			end
		end
	end
	return payload :: Action, nil
end

-- Settings changes: { [settingId] = value }. Shape only; values are checked against settings.json.
function Protocol.parseSettings(payload: any, maxEntries: number): ({ [string]: any }?, string?)
	if type(payload) ~= "table" then
		return nil, "not_a_table"
	end
	local count = 0
	for key, v in payload do
		count += 1
		if count > maxEntries then
			return nil, "too_many"
		end
		if type(key) ~= "string" or #key > 48 then
			return nil, "bad_key"
		end
		local t = type(v)
		if t ~= "boolean" and t ~= "number" and t ~= "string" then
			return nil, "bad_value"
		end
		if t == "string" and #v > 32 then
			return nil, "bad_value"
		end
	end
	return payload, nil
end

return Protocol
