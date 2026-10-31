--!strict
-- The local copy of the player's settings. Starts with the defaults from settings.json, is
-- replaced by the saved settings the server sends on join, and sends changes back (batched).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Net = require(Shared.Net)
local Settings = require(Shared.Rules.Settings)
local Signal = require(Shared.Util.Signal)

local PLATFORM = "roblox"
local SEND_DELAY_S = 0.4

local SettingsController = {}
SettingsController.changed = Signal.new() -- (settingId, value)
SettingsController.defs = Settings.forPlatform(Data.settings.settings, PLATFORM)

local values: { [string]: any } = Settings.defaults(Data.settings.settings, PLATFORM)
local pending: { [string]: any } = {}
local sendScheduled = false

function SettingsController.get(id: string): any
	return values[id]
end

local function flush()
	sendScheduled = false
	if next(pending) == nil then
		return
	end
	Net.event("Settings"):FireServer(pending)
	pending = {}
end

-- Changes a setting now and saves it to the server shortly after.
function SettingsController.set(id: string, raw: any)
	local def = Settings.find(SettingsController.defs, id)
	if def == nil then
		return
	end
	local ok, value = Settings.coerce(def, raw)
	if not ok or values[id] == value then
		return
	end
	values[id] = value
	pending[id] = value
	SettingsController.changed:Fire(id, value)
	if not sendScheduled then
		sendScheduled = true
		task.delay(SEND_DELAY_S, flush)
	end
end

function SettingsController.restoreTab(tab: string)
	for _, def in SettingsController.defs do
		if def.tab == tab then
			SettingsController.set(def.id, def.default)
		end
	end
end

function SettingsController.start()
	Net.event("Settings").OnClientEvent:Connect(function(saved: any)
		if type(saved) ~= "table" then
			return
		end
		local clean = Settings.sanitize(saved, Data.settings.settings, PLATFORM)
		for id, value in clean do
			if values[id] ~= value then
				values[id] = value
				SettingsController.changed:Fire(id, value)
			end
		end
	end)
end

return SettingsController
