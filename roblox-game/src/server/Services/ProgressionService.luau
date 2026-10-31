--!strict
-- XP, levels, skill points, milestones and currency. Server only: no remote can add XP.
--
-- XP comes only from server-side events (an enemy this player damaged was defeated, and so on).
-- Every award goes through level-sync, catch-up, anti-grind and the XP-rate alarm, then
-- Progression.addXp, which can never pass the cap. Level-up rewards use
-- rewards_granted_through, so each level's rewards are granted exactly once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Net = require(Shared.Net)
local Progression = require(Shared.Rules.Progression)
local Scaling = require(Shared.Rules.Scaling)
local RewardGuards = require(Shared.Rules.RewardGuards)
local Signal = require(Shared.Util.Signal)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ProgressionService = {}
ProgressionService.leveled = Signal.new() -- (player, newLevel)

local P = Data.progression
local GROWTH = P.stat_scaling.growth_per_level
local CAP = Progression.effectiveCap(P.content_level_cap, Data.xpToNext)
local MAIN_CURRENCY = P.currencies[1].id

type Guards = { grind: RewardGuards.GrindState, rate: RewardGuards.RateState }
local guards: { [Player]: Guards } = {}

local function notify(player: Player, message: { [string]: any })
	Net.event("Notify"):FireClient(player, message)
end

-- Mirrors progress into attributes; the HUD reads them (attributes replicate automatically).
function ProgressionService.publish(player: Player)
	local data = PlayerDataService.get(player)
	if data == nil then
		return
	end
	player:SetAttribute("Level", data.level)
	player:SetAttribute("XP", data.xp)
	player:SetAttribute("XPToNext", Progression.xpToNext(data.level, Data.xpToNext, CAP) or 0)
	player:SetAttribute("LevelCap", CAP)
	player:SetAttribute("SkillPoints", data.skill_points)
	player:SetAttribute("Marks", data.currency[MAIN_CURRENCY] or 0)
end

function ProgressionService.level(player: Player): number
	local data = PlayerDataService.get(player)
	return if data then data.level else 1
end

local function grantReward(player: Player, reward: any, level: number)
	local data = PlayerDataService.get(player)
	if data == nil or reward == nil then
		return
	end
	if reward.skill_points then
		data.skill_points += reward.skill_points
	end
	for _, entry in reward.currency or {} do
		ProgressionService.addCurrency(player, entry.currency_id, entry.amount, level)
	end
end

local function handleLevelUps(player: Player, oldLevel: number)
	local data = PlayerDataService.get(player)
	if data == nil then
		return
	end
	local milestoneNames = {}
	for _, level in Progression.pendingRewardLevels(data.rewards_granted_through, data.level) do
		data.skill_points += Progression.skillPointsAt(level, P.skill_points.schedule)
		local reward, majorName = Progression.milestoneAt(level, P.milestones)
		if reward then
			grantReward(player, reward, level)
			if not table.find(data.milestones, level) then
				table.insert(data.milestones, level)
			end
			table.insert(milestoneNames, majorName or `Level {level} milestone`)
		end
		data.rewards_granted_through = level
	end
	if data.level > oldLevel then
		notify(
			player,
			{ kind = "level_up", level = data.level, milestones = milestoneNames, atCap = data.level >= CAP }
		)
		ProgressionService.leveled:Fire(player, data.level)
	end
end

-- Adds XP with no scaling or guards. Used by the Studio dev tool and by the scaled award below.
function ProgressionService.addRawXp(player: Player, amount: number): number
	local data = PlayerDataService.get(player)
	if data == nil then
		return 0
	end
	local oldLevel = data.level
	local result =
		Progression.addXp({ level = data.level, xp = data.xp, total_xp = data.total_xp }, amount, Data.xpToNext, CAP)
	data.level, data.xp, data.total_xp = result.progress.level, result.progress.xp, result.progress.total_xp
	handleLevelUps(player, oldLevel)
	ProgressionService.publish(player)
	return result.added
end

export type AwardOptions = { enemyId: string?, areaMaxLevel: number?, recommendedLevel: number? }

-- Awards level-1 `baseXp` for content of level `contentLevel`, with every fairness rule applied.
function ProgressionService.awardXp(
	player: Player,
	baseXp: number,
	contentLevel: number,
	options: AwardOptions?
): number
	local data = PlayerDataService.get(player)
	if data == nil or baseXp <= 0 then
		return 0
	end
	local opts: AwardOptions = options or {}
	local now = os.clock()
	local g = guards[player]
	if g == nil then
		g = { grind = RewardGuards.newGrind(), rate = RewardGuards.newRate() }
		guards[player] = g
	end

	local amount
	local areaMax = opts.areaMaxLevel
	if P.level_sync.enabled and areaMax and data.level > areaMax + P.level_sync.margin_levels then
		-- Old area: XP follows the player's own level, a little reduced.
		amount = Scaling.scaledReward(baseXp, data.level, GROWTH) * P.level_sync.synced_reward_multiplier
	else
		amount = Scaling.scaledReward(baseXp, contentLevel, GROWTH)
	end
	-- Catch-up: well under the recommended level, XP gets a bonus.
	local below = (opts.recommendedLevel or contentLevel) - data.level
	if below >= P.catch_up.below_recommended_by then
		amount *= 1 + math.min(P.catch_up.max_bonus, below * P.catch_up.bonus_per_level_below)
	end
	if opts.enemyId then
		amount *= RewardGuards.grindMultiplier(g.grind, opts.enemyId, now, P.anti_grind)
	end
	local expectedPerMinute = P.xp_curve.reference_xp_per_minute * Scaling.rewardScale(data.level, GROWTH)
	local allowed, alarmed =
		RewardGuards.clampXp(g.rate, math.floor(amount), now, expectedPerMinute, P.anti_exploit.xp_rate_alarm_factor)
	if alarmed then
		warn(`[SBE] XP rate alarm for {player.UserId}: clamped {math.floor(amount)} to {allowed}`)
	end
	return ProgressionService.addRawXp(player, allowed)
end

function ProgressionService.addCurrency(player: Player, currencyId: string, baseAmount: number, contentLevel: number)
	local data = PlayerDataService.get(player)
	if data == nil or baseAmount <= 0 then
		return
	end
	local maxAmount = 1e12
	for _, currency in P.currencies do
		if currency.id == currencyId then
			maxAmount = currency.max
		end
	end
	local amount = Scaling.scaledReward(baseAmount, contentLevel, GROWTH)
	data.currency[currencyId] = math.min(maxAmount, (data.currency[currencyId] or 0) + amount)
	ProgressionService.publish(player)
end

ProgressionService.MAIN_CURRENCY = MAIN_CURRENCY

function ProgressionService.start()
	PlayerDataService.ready:Connect(function(player: Player)
		guards[player] = nil
		ProgressionService.publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		guards[player] = nil
	end)
end

return ProgressionService
