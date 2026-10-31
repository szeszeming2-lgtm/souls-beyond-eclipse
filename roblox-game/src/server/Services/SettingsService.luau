--!strict
-- Stores each player's settings in their save. Every change from a client is checked against
-- shared-data/settings.json before it is kept.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Net = require(Shared.Net)
local Settings = require(Shared.Rules.Settings)
local Protocol = require(Shared.Rules.Protocol)
local RateLimiter = require(Shared.Rules.RateLimiter)
local Signal = require(Shared.Util.Signal)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PLATFORM = "roblox"

local SettingsService = {}
SettingsService.changed = Signal.new() -- (player, settingId, value)

local limiters: { [Player]: RateLimiter.Bucket } = {}

function SettingsService.get(player: Player, settingId: string): any
	local data = PlayerDataService.get(player)
	local value = if data then data.settings[settingId] else nil
	if value == nil then
		local def = Settings.find(Data.settings.settings, settingId)
		return if def then def.default else nil
	end
	return value
end

local function applyAttributes(player: Player)
	player:SetAttribute("Difficulty", SettingsService.get(player, "difficulty"))
end

function SettingsService.start()
	local remote = Net.event("Settings")

	PlayerDataService.ready:Connect(function(player: Player, data)
		local clean, reset = Settings.sanitize(data.settings, Data.settings.settings, PLATFORM)
		if #reset > 0 then
			warn(`[SBE] reset invalid settings for {player.UserId}: {table.concat(reset, ", ")}`)
		end
		data.settings = clean
		applyAttributes(player)
		remote:FireClient(player, clean)
	end)

	remote.OnServerEvent:Connect(function(player: Player, payload: any)
		local now = os.clock()
		local bucket = limiters[player]
		if bucket == nil then
			bucket = RateLimiter.new(10, 4, now)
			limiters[player] = bucket
		end
		if not RateLimiter.allow(bucket, now) then
			return
		end
		local changes = Protocol.parseSettings(payload, 30)
		local data = PlayerDataService.get(player)
		if changes == nil or data == nil then
			return
		end
		local defs = Settings.forPlatform(Data.settings.settings, PLATFORM)
		for id, raw in changes do
			local def = Settings.find(defs, id)
			if def then
				local ok, value = Settings.coerce(def, raw)
				if ok and data.settings[id] ~= value then
					data.settings[id] = value
					SettingsService.changed:Fire(player, id, value)
				end
			end
		end
		applyAttributes(player)
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		limiters[player] = nil
	end)
end

return SettingsService
