--!strict
-- Spawns enemies from the map's spawn zones and runs their behaviour on the server.
--
-- Readability rules:
--   * Every attack sends a "tell" to clients for its whole wind-up (ground marker or glow).
--   * The attack's direction and area lock when the wind-up starts, so sidestepping works.
--   * Wind-ups are scaled by the TARGET's difficulty; boss speed-ups never shorten wind-ups.
--   * Only a few enemies may attack one player at once (attack tokens, set by difficulty).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Scaling = require(Shared.Rules.Scaling)
local Stagger = require(Shared.Rules.Stagger)
local Geometry = require(Shared.Rules.Geometry)
local EnemyBrain = require(Shared.Rules.EnemyBrain)
local DataTypes = require(Shared.Rules.DataTypes)
local Signal = require(Shared.Util.Signal)

local PlaceholderModels = require(script.Parent.Parent.PlaceholderModels)
local CombatService = require(script.Parent.CombatService)
local ProgressionService = require(script.Parent.ProgressionService)
local ItemService = require(script.Parent.ItemService)
local FxService = require(script.Parent.FxService)
local EnemyRegistry = require(script.Parent.EnemyRegistry)

local TAG = "SBE_Enemy"
local AI_TICK_S = 0.1
local PLAYER_RADIUS = 1.5
local MAX_HEIGHT_DIFF = 10
local REWARD_WINDOW_S = 30 -- players who hit the enemy this recently share its rewards
local MOVE_REFRESH_S = 0.25

local C = Data.combat
local GROWTH = Data.progression.stat_scaling.growth_per_level
local BASE = Data.progression.stat_scaling.enemy_base

local EnemyService = {}
EnemyService.damaged = Signal.new() -- (enemy, amount, attacker)
EnemyService.defeated = Signal.new() -- (enemy, { Player })

type Burning = { untilT: number, nextTick: number, interval: number, tickDamage: number, by: Player? }

export type Live = {
	-- shared with EnemyRegistry.Enemy
	def: DataTypes.Enemy,
	model: Model,
	root: BasePart,
	level: number,
	maxHp: number,
	hp: number,
	defense: number,
	radius: number,
	alive: boolean,
	isBoss: boolean,
	takeHit: (hit: EnemyRegistry.Hit) -> boolean,
	stagger: (seconds: number) -> boolean,
	-- server-only
	humanoid: Humanoid,
	height: number,
	attack: number,
	home: Vector3,
	leash: number,
	aggro: number,
	areaMaxLevel: number,
	poise: Stagger.PoiseState,
	stunnedUntil: number,
	busyUntil: number,
	actionToken: number,
	attackReady: { [string]: number },
	allowedAttacks: { string }?,
	speedMult: number,
	invulnerableUntil: number,
	target: Player?,
	tokenHolder: Player?,
	damagers: { [Player]: number },
	burning: Burning?,
	lastMoveAt: number,
}

export type SpawnOptions = { isBoss: boolean?, leash: number?, areaMaxLevel: number?, allowedAttacks: { string }? }

local tokens: { [Player]: number } = {}
local enemyFolder: Folder? = nil
local rng = Random.new()

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.new(0, 0, -1)
end

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- ------------------------------------------------------------------ attack tokens
local function releaseToken(e: Live)
	local holder = e.tokenHolder
	if holder then
		tokens[holder] = math.max(0, (tokens[holder] or 1) - 1)
		e.tokenHolder = nil
	end
end

local function canTakeToken(e: Live, player: Player): boolean
	if e.tokenHolder == player then
		return true
	end
	local limit = CombatService.difficulty(player).max_attackers_per_player
	return (tokens[player] or 0) < limit
end

local function takeToken(e: Live, player: Player)
	if e.tokenHolder ~= player then
		releaseToken(e)
		tokens[player] = (tokens[player] or 0) + 1
		e.tokenHolder = player
	end
end

-- ------------------------------------------------------------------ taking damage
local function staggerEnemy(e: Live, seconds: number, forced: boolean): boolean
	local now = os.clock()
	if forced and not Stagger.force(e.poise, now, seconds, C.poise) then
		return false
	end
	e.stunnedUntil = now + seconds
	e.actionToken += 1 -- cancels a wind-up in progress
	e.busyUntil = 0
	releaseToken(e)
	e.humanoid:MoveTo(e.root.Position)
	FxService.all({ k = "stagger", target = e.model, dur = seconds })
	return true
end

local function die(e: Live)
	e.alive = false
	EnemyRegistry.remove(e)
	releaseToken(e)
	local now = os.clock()
	local rewarded = {}
	for player, hitAt in e.damagers do
		if player.Parent == Players and now - hitAt <= REWARD_WINDOW_S then
			table.insert(rewarded, player)
			ProgressionService.awardXp(player, e.def.rewards.xp_base, e.level, {
				enemyId = e.def.id,
				areaMaxLevel = e.areaMaxLevel,
				recommendedLevel = e.level,
			})
			ProgressionService.addCurrency(
				player,
				ProgressionService.MAIN_CURRENCY,
				e.def.rewards.currency_base,
				e.level
			)
			ItemService.grantDrops(player, e.def.rewards.drops)
		end
	end
	e.humanoid:MoveTo(e.root.Position)
	FxService.all({ k = "defeat", target = e.model })
	EnemyService.defeated:Fire(e, rewarded)
	task.delay(1.2, function()
		e.model:Destroy()
	end)
end

local function applyStatus(e: Live, app: DataTypes.StatusApplication, hit: EnemyRegistry.Hit)
	local status = Data.statusEffects[app.status_id]
	if status == nil or rng:NextNumber() >= app.chance then
		return
	end
	if status.category == "damage_over_time" and status.tick_power and status.tick_interval_s then
		local now = os.clock()
		e.burning = {
			untilT = now + (app.duration_s or status.duration_s),
			nextTick = now + status.tick_interval_s,
			interval = status.tick_interval_s,
			tickDamage = math.max(1, Scaling.round(hit.sourceAttack * status.tick_power)),
			by = hit.attacker,
		}
		e.model:SetAttribute("Effect_" .. status.id, true)
	end
end

local function takeHit(e: Live, hit: EnemyRegistry.Hit): boolean
	local now = os.clock()
	if not e.alive or now < e.invulnerableUntil then
		return false
	end
	e.hp = math.max(0, e.hp - hit.amount)
	e.model:SetAttribute("HP", e.hp)
	if hit.attacker then
		e.damagers[hit.attacker] = now
		if e.target == nil then
			e.target = hit.attacker
		end
	end
	if hit.poiseDamage > 0 and Stagger.hit(e.poise, hit.poiseDamage, now, C.poise) then
		staggerEnemy(e, C.poise.stagger_s, false)
	end
	if hit.knockback > 0 and not e.isBoss then
		e.root:ApplyImpulse(hit.direction * hit.knockback * e.root.AssemblyMass * 8)
	end
	local statuses: { DataTypes.StatusApplication } = hit.statusEffects or {}
	for _, app in statuses do
		applyStatus(e, app, hit)
	end
	EnemyService.damaged:Fire(e, hit.amount, hit.attacker)
	if e.hp <= 0 then
		die(e)
	end
	return true
end

-- ------------------------------------------------------------------ attacking
local function attackDef(e: Live, attackId: string): DataTypes.EnemyAttack?
	for _, attack in e.def.attacks do
		if attack.id == attackId then
			return attack
		end
	end
	return nil
end

local function startAttack(e: Live, target: Player, attack: DataTypes.EnemyAttack)
	local targetRoot = playerRoot(target)
	if targetRoot == nil then
		return
	end
	local now = os.clock()
	local mode = CombatService.difficulty(target)
	local windup = attack.timing.windup_s * mode.telegraph_time_mult
	local recovery = attack.timing.recovery_s / e.speedMult
	takeToken(e, target)
	e.attackReady[attack.id] = now + windup + attack.cooldown_s
	e.busyUntil = now + windup + attack.timing.active_s + recovery
	e.actionToken += 1
	local token = e.actionToken

	-- Lock direction and area now, so the player can read the tell and step out of it.
	local origin = e.root.Position
	local targetPos = targetRoot.Position
	local facing = flat(targetPos - origin)
	e.humanoid:MoveTo(origin)
	e.root.CFrame = CFrame.lookAt(origin, origin + facing)
	local center = origin
	if Geometry.areaCenterDistance(attack.area, attack.range_studs) > 0 then
		local offset = Vector3.new(targetPos.X - origin.X, 0, targetPos.Z - origin.Z)
		if offset.Magnitude > attack.range_studs then
			offset = offset.Unit * attack.range_studs
		end
		center = origin + offset
	end
	local unblockable = table.find(attack.avoidable_by, "guard") == nil
	FxService.all({
		k = "tell",
		target = e.model,
		name = attack.name,
		shape = attack.area.shape,
		r = attack.area.radius_studs or attack.range_studs,
		len = attack.area.length_studs or attack.range_studs,
		w = attack.area.width_studs or 4,
		ang = attack.area.angle_deg or 90,
		center = center,
		dir = facing,
		ground = e.root.Position.Y - e.root.Size.Y / 2 - e.humanoid.HipHeight,
		dur = windup,
		visual = attack.tell.visual,
		unblockable = unblockable,
	})

	task.delay(windup, function()
		if e.actionToken ~= token or not e.alive then
			return -- interrupted (staggered or parried)
		end
		local targetRadius = if attack.area.shape == "cone" then PLAYER_RADIUS + e.radius else PLAYER_RADIUS
		for _, player in Players:GetPlayers() do
			local root = playerRoot(player)
			if root and math.abs(root.Position.Y - origin.Y) <= MAX_HEIGHT_DIFF + e.height / 2 then
				local p = root.Position
				if
					Geometry.hitsArea(
						attack.area,
						attack.range_studs,
						center.X,
						center.Z,
						facing.X,
						facing.Z,
						p.X,
						p.Z,
						targetRadius
					)
				then
					CombatService.damagePlayer(player, {
						attack = e.attack,
						power = attack.power,
						attackerLevel = e.level,
						damageType = attack.damage_type,
						poiseDamage = attack.poise_damage,
						knockback = attack.knockback_studs,
						sourcePosition = origin,
						unblockable = unblockable,
						statusEffects = attack.status_effects,
						onParried = function()
							staggerEnemy(e, C.poise.stagger_s, true)
						end,
					})
				end
			end
		end
		task.delay(attack.timing.active_s, function()
			if e.actionToken == token then
				releaseToken(e)
			end
		end)
	end)
end

-- ------------------------------------------------------------------ thinking
local function chooseTarget(e: Live): (Player?, BasePart?)
	local current = e.target
	if current and current.Parent == Players and CombatService.canBeAttacked(current) then
		local root = playerRoot(current)
		if root and (root.Position - e.home).Magnitude <= e.leash + e.aggro then
			return current, root
		end
	end
	e.target = nil
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = e.aggro
	for _, player in Players:GetPlayers() do
		if CombatService.canBeAttacked(player) then
			local root = playerRoot(player)
			if root then
				local distance = (root.Position - e.root.Position).Magnitude
				if distance <= bestDistance then
					best, bestRoot, bestDistance = player, root, distance
				end
			end
		end
	end
	e.target = best
	return best, bestRoot
end

local function moveTo(e: Live, position: Vector3, now: number)
	if now - e.lastMoveAt >= MOVE_REFRESH_S then
		e.lastMoveAt = now
		e.humanoid.WalkSpeed = e.def.stats.move_speed_studs * e.speedMult
		e.humanoid:MoveTo(position)
	end
end

local function tickBurning(e: Live, now: number)
	local burning = e.burning
	if burning == nil then
		return
	end
	if now >= burning.untilT then
		e.burning = nil
		for key in e.model:GetAttributes() do
			if string.sub(key, 1, 7) == "Effect_" then
				e.model:SetAttribute(key, nil)
			end
		end
	elseif now >= burning.nextTick then
		burning.nextTick += burning.interval
		takeHit(e, {
			amount = burning.tickDamage,
			poiseDamage = 0,
			knockback = 0,
			direction = Vector3.zero,
			attacker = burning.by,
			isCrit = false,
			sourceAttack = 0,
		})
		FxService.all({ k = "hit", target = e.model, n = burning.tickDamage, crit = false, dot = true })
	end
end

local function think(e: Live, now: number)
	if not e.alive then
		return
	end
	tickBurning(e, now)
	if not e.alive or now < e.stunnedUntil then
		return
	end
	local target, targetRoot = chooseTarget(e)
	local distance: number? = nil
	if targetRoot then
		distance = (Vector3.new(targetRoot.Position.X, 0, targetRoot.Position.Z) - Vector3.new(
			e.root.Position.X,
			0,
			e.root.Position.Z
		)).Magnitude
	end
	local options = {}
	for _, attack in e.def.attacks do
		if e.allowedAttacks == nil or table.find(e.allowedAttacks, attack.id) then
			local reach = attack.range_studs + (if attack.area.shape == "cone" then e.radius else 0)
			table.insert(options, { id = attack.id, range = reach, readyAt = e.attackReady[attack.id] or 0 })
		end
	end
	local fromHome = (Vector3.new(e.root.Position.X, 0, e.root.Position.Z) - Vector3.new(e.home.X, 0, e.home.Z)).Magnitude
	local decision = EnemyBrain.decide({
		now = now,
		distanceToTarget = distance,
		distanceFromHome = fromHome,
		leashRange = e.leash,
		attacks = options,
		hasAttackToken = target ~= nil and canTakeToken(e, target),
		busy = now < e.busyUntil,
	})
	if decision.kind == "attack" and target and decision.attackId then
		local attack = attackDef(e, decision.attackId)
		if attack then
			startAttack(e, target, attack)
		end
	elseif decision.kind == "chase" and targetRoot then
		moveTo(e, targetRoot.Position, now)
	elseif decision.kind == "return" then
		e.target = nil
		releaseToken(e)
		moveTo(e, e.home, now)
		if fromHome < 6 and e.hp < e.maxHp then
			e.hp = e.maxHp
			e.model:SetAttribute("HP", e.hp)
		end
	elseif decision.kind == "wait" and targetRoot then
		local look = flat(targetRoot.Position - e.root.Position)
		e.humanoid:MoveTo(e.root.Position)
		e.root.CFrame = CFrame.lookAt(e.root.Position, e.root.Position + look)
	end
end

-- ------------------------------------------------------------------ spawning
function EnemyService.spawn(def: DataTypes.Enemy, level: number, position: Vector3, options: SpawnOptions?): Live
	local opts: SpawnOptions = options or {}
	local build = PlaceholderModels.enemy(def.presentation.visual, def.name)
	local maxHp = Scaling.round(Scaling.statAt(BASE.max_hp, level, GROWTH) * def.stats.hp_mult)
	local model = build.model
	model:PivotTo(CFrame.new(position + Vector3.new(0, build.humanoid.HipHeight + build.root.Size.Y / 2 + 0.5, 0)))
	model:SetAttribute("EnemyId", def.id)
	model:SetAttribute("DisplayName", def.name)
	model:SetAttribute("Level", level)
	model:SetAttribute("HP", maxHp)
	model:SetAttribute("MaxHP", maxHp)
	model:SetAttribute("Rank", def.rank)
	model:SetAttribute("Height", build.height)
	build.humanoid.WalkSpeed = def.stats.move_speed_studs
	CollectionService:AddTag(model, TAG)
	model.Parent = enemyFolder
	pcall(function()
		build.root:SetNetworkOwner(nil) -- the server simulates enemies
	end)

	local e: Live = {
		def = def,
		model = model,
		root = build.root,
		level = level,
		maxHp = maxHp,
		hp = maxHp,
		defense = Scaling.statAt(BASE.defense, level, GROWTH) * def.stats.defense_mult,
		radius = build.radius,
		alive = true,
		isBoss = opts.isBoss == true,
		takeHit = nil :: any,
		stagger = nil :: any,
		humanoid = build.humanoid,
		height = build.height,
		attack = Scaling.statAt(BASE.attack, level, GROWTH) * def.stats.attack_mult,
		home = position,
		leash = opts.leash or def.stats.leash_range_studs,
		aggro = def.stats.aggro_range_studs,
		areaMaxLevel = opts.areaMaxLevel or level,
		poise = Stagger.newPoise(def.stats.poise),
		stunnedUntil = 0,
		busyUntil = 0,
		actionToken = 0,
		attackReady = {},
		allowedAttacks = opts.allowedAttacks,
		speedMult = 1,
		invulnerableUntil = 0,
		target = nil,
		tokenHolder = nil,
		damagers = {},
		burning = nil,
		lastMoveAt = 0,
	}
	e.takeHit = function(hit: EnemyRegistry.Hit): boolean
		return takeHit(e, hit)
	end
	e.stagger = function(seconds: number): boolean
		return staggerEnemy(e, seconds, true)
	end
	EnemyRegistry.add(e :: any)
	return e
end

-- Each slot keeps one enemy alive, waiting respawn_s after a defeat.
local function runSlot(zone: any, areaMaxLevel: number)
	while true do
		local id = zone.enemy_ids[rng:NextInteger(1, #zone.enemy_ids)]
		local def = Data.enemies[id]
		local angle = rng:NextNumber() * math.pi * 2
		local distance = rng:NextNumber() * zone.radius_studs * 0.8
		local position = Vector3.new(
			zone.center[1] + math.cos(angle) * distance,
			zone.center[2],
			zone.center[3] + math.sin(angle) * distance
		)
		local level = rng:NextInteger(zone.level_range.min, zone.level_range.max)
		local e = EnemyService.spawn(def, level, position, { areaMaxLevel = areaMaxLevel })
		while e.alive do
			task.wait(1)
		end
		task.wait(zone.respawn_s)
	end
end

function EnemyService.start()
	local folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
	enemyFolder = folder

	for _, map in Data.maps do
		local region = Data.regions[map.region_id]
		local areaMax = if region then region.level_range.max else 1
		for _, zone in map.spawn_zones do
			for _ = 1, zone.max_alive do
				task.spawn(runSlot, zone, areaMax)
				task.wait(0.05)
			end
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		tokens[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AI_TICK_S)
			local now = os.clock()
			for _, enemy in EnemyRegistry.all() do
				think(enemy :: any, now)
			end
		end
	end)
end

return EnemyService
