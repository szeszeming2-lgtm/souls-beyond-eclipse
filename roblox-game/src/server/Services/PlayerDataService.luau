--!strict
-- Loads, repairs, validates and saves each player's data with ProfileStore.
--
-- ProfileStore gives session locking (one server owns a save at a time) and saves periodically,
-- on leave and on shutdown. This service adds the project's own safety rules:
--   * nothing is saved until the profile has loaded and passed repair/validation;
--   * right before every save, a snapshot of the live data is validated, and the save keeps the
--     last good data if validation fails;
--   * a save from a newer game version is never loaded or overwritten.
-- In Studio without API access, ProfileStore automatically uses a temporary in-memory store.
--
-- Other services must never keep a reference to a player's data table: call get() each time,
-- because a dev reset replaces it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local SaveSchema = require(Shared.Rules.SaveSchema)
local Progression = require(Shared.Rules.Progression)
local Signal = require(Shared.Util.Signal)
local ProfileStore = require(ServerScriptService:WaitForChild("ServerPackages"):WaitForChild("ProfileStore")) :: any

type SaveData = SaveSchema.SaveData

-- Changing this name starts every player from scratch. Never change it casually.
local STORE_NAME = "PlayerData_v1"
local KEY_PREFIX = "Player_"

local PlayerDataService = {}
PlayerDataService.ready = Signal.new() -- (player, data, report) after load, and again after a dev reset
PlayerDataService.wasReset = Signal.new() -- (player) after a Studio dev reset only

type Session = { profile: any, data: SaveData }
local sessions: { [Player]: Session } = {}
local store: any = nil

local APPEARANCE_FIELDS = {
	body_type = "body_type",
	face = "face",
	skin_tone = "skin_tone",
	hair_style = "hair_style",
	hair_color = "hair_color",
	eye_color = "eye_color",
	outfit = "outfit",
	aura_color = "aura_color",
}

-- Starter look from the customization data's defaults.
local function defaultAppearance(): { [string]: any }
	local look: { [string]: any } = { accessories = {}, name = "" }
	for _, option in Data.customization.options do
		if option.is_default then
			local field = APPEARANCE_FIELDS[option.category]
			if field then
				look[field] = option.id
			elseif option.category == "accessory" then
				table.insert(look.accessories, option.id)
			end
		end
	end
	return look
end

local function loadContext(): SaveSchema.LoadContext
	return {
		xpToNext = Data.xpToNext,
		cap = Progression.effectiveCap(Data.progression.content_level_cap, Data.xpToNext),
		appearance = defaultAppearance(),
	}
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(KEY_PREFIX .. player.UserId, {
		Cancel = function(): boolean
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("Your save could not be loaded right now. Please rejoin; your progress is safe.")
		end
		return
	end
	profile:AddUserId(player.UserId)

	local data, report = SaveSchema.load(profile.Data, loadContext())
	if data == nil then
		-- Refused (for example a save from a newer version). Leave profile.Data untouched.
		warn(`[SBE] refused save for {player.UserId}: {report.refused}`)
		profile:EndSession()
		if player.Parent == Players then
			player:Kick("This save belongs to a newer version of the game. Please rejoin in a moment.")
		end
		return
	end
	if #report.repaired > 0 then
		warn(`[SBE] repaired save for {player.UserId}: {table.concat(report.repaired, ", ")}`)
	end

	local session: Session = { profile = profile, data = data }
	profile.Data = SaveSchema.snapshot(data)

	profile.OnSave:Connect(function()
		-- Runs right before ProfileStore writes. Only a valid snapshot may replace the saved data.
		local snapshot = SaveSchema.snapshot(session.data)
		local ok, problems = SaveSchema.validate(snapshot, loadContext())
		if ok then
			profile.Data = snapshot
		else
			warn(`[SBE] save skipped for {player.UserId}, keeping last good data: {table.concat(problems, ", ")}`)
		end
	end)

	profile.OnSessionEnd:Connect(function()
		sessions[player] = nil
		if player.Parent == Players then
			player:Kick("Your game session ended (were you playing somewhere else?). Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	sessions[player] = session
	PlayerDataService.ready:Fire(player, data, report)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if session then
		session.profile:EndSession()
	end
end

-- The player's live data, or nil if it has not loaded (yet).
function PlayerDataService.get(player: Player): SaveData?
	local session = sessions[player]
	return if session then session.data else nil
end

-- Runs `callback(data)` once the player's data is ready (now, if it already is).
function PlayerDataService.whenReady(player: Player, callback: (SaveData) -> ())
	local data = PlayerDataService.get(player)
	if data then
		task.spawn(callback, data)
		return
	end
	local connection
	connection = PlayerDataService.ready:Connect(function(readyPlayer: Player, readyData: SaveData)
		if readyPlayer == player then
			connection:Disconnect()
			callback(readyData)
		end
	end)
end

-- Studio-only dev tool (DevService checks the gate). Replaces the data with a fresh save.
function PlayerDataService.devReset(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	local fresh = SaveSchema.default(defaultAppearance())
	session.data = fresh
	session.profile.Data = SaveSchema.snapshot(fresh)
	PlayerDataService.ready:Fire(player, fresh, { isNew = true, filled = {}, repaired = {} })
	PlayerDataService.wasReset:Fire(player)
end

function PlayerDataService.start()
	store = ProfileStore.New(STORE_NAME, {})
end

-- Called last, after every service has connected to `ready`, so no service misses a player.
function PlayerDataService.beginLoading()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	-- Track play time once a minute (saved with everything else).
	task.spawn(function()
		while true do
			task.wait(60)
			for _, session in sessions do
				session.data.stats.play_seconds += 60
			end
		end
	end)
end

return PlayerDataService
