--!strict
-- Turns shared-data/input_actions.json into fast lookups: (context, device, input name) -> action.
-- Pure. Input names are Roblox KeyCode / UserInputType names (e.g. "Q", "ButtonX", "MouseButton1").

local DataTypes = require(script.Parent.DataTypes)

local InputMap = {}

InputMap.DEVICES = { "keyboard_mouse", "gamepad", "touch" }

-- Composite bindings drive axis actions. Each key contributes a direction.
InputMap.COMPOSITES = {
	["Composite:WASD"] = { W = { 0, 1 }, S = { 0, -1 }, A = { -1, 0 }, D = { 1, 0 } },
	["Composite:Arrows"] = { Up = { 0, 1 }, Down = { 0, -1 }, Left = { -1, 0 }, Right = { 1, 0 } },
	["Composite:DPad"] = { DPadUp = { 0, 1 }, DPadDown = { 0, -1 }, DPadLeft = { -1, 0 }, DPadRight = { 1, 0 } },
} :: { [string]: { [string]: { number } } }

export type Map = {
	-- lookup[context][device][inputName] = actionId
	lookup: { [string]: { [string]: { [string]: string } } },
	-- directions[context][device][inputName] = { actionId, x, y } for composite axis keys
	directions: { [string]: { [string]: { [string]: { any } } } },
	bindings: { [string]: { [string]: { string } } }, -- actionId -> device -> effective inputs
	actions: { [string]: DataTypes.InputAction },
	reserved: { [string]: boolean },
}

-- platform: "roblox" or "pc". presetIds: presets the player has turned on (e.g. right_click_guard).
function InputMap.build(data: DataTypes.InputActions, platform: string, presetIds: { string }): Map
	local bindings: { [string]: { [string]: { string } } } = {}
	local actions: { [string]: DataTypes.InputAction } = {}
	for _, action in data.actions do
		actions[action.id] = action
		local per: { [string]: { string } } = {}
		for _, device in InputMap.DEVICES do
			local base: { string } = action.bindings[device] or {}
			per[device] = table.clone(base)
		end
		local overrides = action.platform_overrides and action.platform_overrides[platform]
		if overrides then
			for device, list in overrides do
				per[device] = table.clone(list)
			end
		end
		bindings[action.id] = per
	end
	for _, preset in data.presets do
		if table.find(presetIds, preset.id) then
			for _, override in preset.overrides do
				if bindings[override.action_id] then
					bindings[override.action_id][override.device] = table.clone(override.bindings)
				end
			end
		end
	end
	local reserved: { [string]: boolean } = {}
	local reservedList: { string } = data.platform_reserved[platform] or {}
	for _, name in reservedList do
		reserved[name] = true
	end

	local lookup: { [string]: { [string]: { [string]: string } } } = {}
	local directions: { [string]: { [string]: { [string]: { any } } } } = {}
	for _, context in { "gameplay", "menu" } do
		lookup[context] = {}
		directions[context] = {}
		for _, device in InputMap.DEVICES do
			lookup[context][device] = {}
			directions[context][device] = {}
		end
	end
	for actionId, perDevice in bindings do
		local action = actions[actionId]
		local contexts: { string } = if action.context == "global" then { "gameplay", "menu" } else { action.context }
		for _, context in contexts do
			for device, inputs in perDevice do
				for _, name in inputs do
					local composite = InputMap.COMPOSITES[name]
					if composite then
						for key, dir in composite do
							if not reserved[key] then
								directions[context][device][key] = { actionId, dir[1], dir[2] }
							end
						end
					elseif not reserved[name] then
						lookup[context][device][name] = actionId
					end
				end
			end
		end
	end
	return { lookup = lookup, directions = directions, bindings = bindings, actions = actions, reserved = reserved }
end

function InputMap.actionFor(map: Map, context: string, device: string, inputName: string): string?
	local byDevice = map.lookup[context]
	return if byDevice then byDevice[device][inputName] else nil
end

-- For composite keys (WASD...): returns (actionId, x, y) or nil.
function InputMap.directionFor(map: Map, context: string, device: string, inputName: string): (string?, number, number)
	local entry = map.directions[context] and map.directions[context][device][inputName]
	if entry then
		return entry[1], entry[2], entry[3]
	end
	return nil, 0, 0
end

-- The inputs shown on screen as hints for an action on a device (reserved ones left out).
function InputMap.hintsFor(map: Map, actionId: string, device: string): { string }
	local out = {}
	local per = map.bindings[actionId]
	if per then
		local inputs: { string } = per[device] or {}
		for _, name in inputs do
			if not map.reserved[name] then
				table.insert(out, name)
			end
		end
	end
	return out
end

return InputMap
