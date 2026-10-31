--!strict
-- Player combat, decided on the server. Clients only send intents ("light attack pressed");
-- this service checks cooldowns, spirit, state and rate limits, finds hits itself, and
-- computes all damage with Rules/DamageMath.
--
-- Fairness built in: dodge invulnerability, parry windows that allow for network lag,
-- stagger immunity, capped crowd control, difficulty multipliers per player, and no new enemy
-- attacks start against a player whose menu is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local Net = require(Shared.Net)
local Protocol = require(Shared.Rules.Protocol)
local RateLimiter = require(Shared.Rules.RateLimiter)
local Cooldowns = require(Shared.Rules.Cooldowns)
local DamageMath = require(Shared.Rules.DamageMath)
local Geometry = require(Shared.Rules.Geometry)
local Stagger = require(Shared.Rules.Stagger)
local DataTypes = require(Shared.Rules.DataTypes)
local Signal = require(Shared.Util.Signal)

local PlayerDataService = require(script.Parent.PlayerDataService)
local SettingsService = require(script.Parent.SettingsService)
local CharacterService = require(script.Parent.CharacterService)
local ItemService = require(script.Parent.ItemService)
local FxService = require(script.Parent.FxService)
local EnemyRegistry = require(script.Parent.EnemyRegistry)

local C = Data.combat
local GROWTH = Data.progression.stat_scaling.growth_per_level
local SPIRIT_MAX = Data.progression.stat_scaling.spirit_max
local DODGE = Data.abilities["abl_flash_step"]
local GUARD = Data.abilities["abl_lantern_guard"]
local TICK_S = 0.25
local MAX_HEIGHT_DIFF = 10 -- studs; hits ignore targets far above or below

local CombatService = {}
CombatService.assistRequested = Signal.new() -- (player, kind)

type Effect = { untilT: number, nextTick: number, tickDamage: number, modifiers: { DataTypes.StatModifier } }

type State = {
	spirit: number,
	busyUntil: number,
	actionToken: number,
	queued: string?,
	combo: { [string]: number },
	comboExpires: { [string]: number },
	cooldowns: Cooldowns.Cooldowns,
	guarding: boolean,
	guardStartedAt: number,
	guardMeter: number,
	iframesUntil: number,
	dodgeStartedAt: number,
	dodgeTimes: { number },
	poise: Stagger.PoiseState,
	cc: Stagger.CcState,
	stunnedUntil: number,
	effects: { [string]: Effect }, -- buffs and debuffs by status/ability id
	passiveReadyAt: number,
	limiter: RateLimiter.Bucket,
	menuOpen: boolean,
	lastDamagedAt: number,
}

local states: { [Player]: State } = {}
local rng = Random.new()

local function newState(): State
	local now = os.clock()
	return {
		spirit = 0,
		busyUntil = 0,
		actionToken = 0,
		queued = nil,
		combo = {},
		comboExpires = {},
		cooldowns = Cooldowns.new(),
		guarding = false,
		guardStartedAt = -math.huge,
		guardMeter = C.guard.guard_meter_max,
		iframesUntil = 0,
		dodgeStartedAt = -math.huge,
		dodgeTimes = {},
		poise = Stagger.newPoise(C.poise.player_poise),
		cc = Stagger.newCc(),
		stunnedUntil = 0,
		effects = {},
		passiveReadyAt = 0,
		limiter = RateLimiter.new(20, 12, now),
		menuOpen = false,
		lastDamagedAt = -math.huge,
	}
end

local function body(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil or humanoid.Health <= 0 then
		return nil, nil
	end
	return humanoid, root
end

local function notify(player: Player, message: { [string]: any })
	Net.event("Notify"):FireClient(player, message)
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.new(0, 0, -1)
end

function CombatService.difficulty(player: Player): DataTypes.DifficultyMode
	local id = SettingsService.get(player, "difficulty")
	return Data.difficultyModes[id] or Data.difficultyModes[Data.difficulty.default_mode]
end

local function allModifiers(state: State): { DataTypes.StatModifier }
	local out = {}
	for _, effect in state.effects do
		for _, modifier in effect.modifiers do
			table.insert(out, modifier)
		end
	end
	return out
end

local function publishSpirit(player: Player, state: State)
	player:SetAttribute("Spirit", math.floor(state.spirit))
	player:SetAttribute("SpiritMax", SPIRIT_MAX)
end

local function gainSpirit(player: Player, state: State, amount: number)
	state.spirit = math.clamp(state.spirit + amount, 0, SPIRIT_MAX)
	publishSpirit(player, state)
end

-- Effects are shown on the HUD through "Effect_<id>" attributes holding the server-time expiry.
local function setEffect(
	player: Player,
	state: State,
	id: string,
	seconds: number,
	modifiers: { DataTypes.StatModifier },
	tickDamage: number
)
	local now = os.clock()
	state.effects[id] = { untilT = now + seconds, nextTick = now + 1, tickDamage = tickDamage, modifiers = modifiers }
	player:SetAttribute("Effect_" .. id, Net.now() + seconds)
end

local function clearEffect(player: Player, state: State, id: string)
	state.effects[id] = nil
	player:SetAttribute("Effect_" .. id, nil)
end

function CombatService.addBuff(player: Player, statusId: string)
	local state = states[player]
	local status = Data.statusEffects[statusId]
	if state and status then
		setEffect(player, state, statusId, status.duration_s, status.stat_modifiers, 0)
	end
end

local function cancelActions(state: State)
	state.actionToken += 1
	state.queued = nil
end

local function staggerPlayer(player: Player, state: State, baseSeconds: number)
	local now = os.clock()
	local seconds = Stagger.ccDuration(state.cc, baseSeconds, now, C.crowd_control)
	if seconds <= 0 then
		return
	end
	state.stunnedUntil = math.max(state.stunnedUntil, now + seconds)
	state.guarding = false
	cancelActions(state)
	player:SetAttribute("Effect_sts_staggered", Net.now() + seconds)
	task.delay(seconds, function()
		if os.clock() >= state.stunnedUntil then
			player:SetAttribute("Effect_sts_staggered", nil)
		end
	end)
end

-- ------------------------------------------------------------------ hitting enemies
local function dealToEnemy(
	player: Player,
	state: State,
	enemy: EnemyRegistry.Enemy,
	power: number,
	damageType: string,
	poiseDamage: number,
	knockback: number,
	statuses: { DataTypes.StatusApplication }?
)
	local _, root = body(player)
	if root == nil then
		return
	end
	local stats = CharacterService.stats(player)
	local weapon, instance = ItemService.equippedWeapon(player)
	local tierBonus = if instance and instance.tier > 0 then weapon.upgrade_tiers[instance.tier].damage_bonus_pct else 0
	local mode = CombatService.difficulty(player)
	local isCrit = DamageMath.isCrit(C.damage.crit_chance_base, rng:NextNumber())
	local resistances = enemy.def.resistances
	local amount = DamageMath.compute({
		attack = stats.attack,
		power = power,
		defense = enemy.defense,
		attackerLevel = stats.level,
		targetLevel = enemy.level,
		growthPerLevel = GROWTH,
		weaponDamage = weapon.base_stats.damage,
		weaponBonusPct = tierBonus,
		resistance = if resistances then resistances[damageType] else nil,
		isCrit = isCrit,
		-- Difficulty changes enemy toughness per player by scaling that player's damage.
		bonusMult = DamageMath.percentMultiplier(allModifiers(state), "attack") / mode.enemy_hp_mult,
	}, C.damage)
	local landed = enemy.takeHit({
		amount = amount,
		poiseDamage = poiseDamage,
		knockback = knockback,
		direction = flat(enemy.root.Position - root.Position),
		attacker = player,
		isCrit = isCrit,
		statusEffects = statuses,
		sourceAttack = stats.attack,
	})
	if landed then
		gainSpirit(player, state, C.spirit.gain_on_hit)
		FxService.all({ k = "hit", target = enemy.model, n = amount, crit = isCrit, by = player.UserId })
	end
end

local function targetsInArea(
	area: DataTypes.Area,
	range: number,
	origin: Vector3,
	look: Vector3
): { EnemyRegistry.Enemy }
	local out = {}
	local reach = math.max(range, area.radius_studs or 0, area.length_studs or 0) + 4
	for _, enemy in EnemyRegistry.near(origin, reach) do
		local p = enemy.root.Position
		if
			math.abs(p.Y - origin.Y) <= MAX_HEIGHT_DIFF + enemy.radius
			and Geometry.hitsArea(area, range, origin.X, origin.Z, look.X, look.Z, p.X, p.Z, enemy.radius)
		then
			table.insert(out, enemy)
		end
	end
	return out
end

local function melee(player: Player, state: State, chainName: string)
	local now = os.clock()
	if now < state.busyUntil or now < state.stunnedUntil or state.guarding or state.menuOpen then
		return
	end
	if body(player) == nil then
		return
	end
	local weapon = ItemService.equippedWeapon(player)
	local moveset = Data.movesets[weapon.moveset_id]
	local chain = if chainName == "heavy" then moveset.heavy_chain else moveset.light_chain
	local other = if chainName == "heavy" then "light" else "heavy"
	local index = 1
	if now <= (state.comboExpires[chainName] or 0) then
		index = (state.combo[chainName] or 0) % #chain + 1
	end
	local step = chain[index]
	local speed = weapon.base_stats.attack_speed
	local windup = step.timing.windup_s / speed
	local total = (step.timing.windup_s + step.timing.active_s + step.timing.recovery_s) / speed
	state.combo[chainName] = index
	state.comboExpires[chainName] = now + total + moveset.combo_reset_s
	state.combo[other] = 0
	state.busyUntil = now + total
	cancelActions(state)
	local token = state.actionToken
	FxService.all({ k = "swing", p = player, chain = chainName, step = index })
	task.delay(windup, function()
		if state.actionToken ~= token or os.clock() < state.stunnedUntil then
			return -- interrupted by a dodge, guard or stagger
		end
		local _, root = body(player)
		if root == nil then
			return
		end
		local area: DataTypes.Area = { shape = "cone", radius_studs = step.range_studs, angle_deg = step.arc_deg }
		for _, enemy in targetsInArea(area, step.range_studs, root.Position, root.CFrame.LookVector) do
			dealToEnemy(
				player,
				state,
				enemy,
				step.power * (step.hit_count or 1),
				step.damage_type,
				step.poise_damage,
				step.knockback_studs,
				nil
			)
		end
	end)
end

-- Attacks pressed just before the previous one ends are queued, so fast clicking never drops inputs.
local function tryMelee(player: Player, state: State, chainName: string)
	local wait = state.busyUntil - os.clock()
	if wait > 0 then
		if wait <= C.recovery.input_buffer_s and state.queued == nil then
			state.queued = chainName
			local token = state.actionToken
			task.delay(wait, function()
				local queued = state.queued
				state.queued = nil
				if queued and state.actionToken == token then
					melee(player, state, queued)
				end
			end)
		end
		return
	end
	melee(player, state, chainName)
end

local function special(player: Player, state: State)
	local now = os.clock()
	if now < state.busyUntil or now < state.stunnedUntil or state.guarding or state.menuOpen then
		return
	end
	local _, root = body(player)
	if root == nil then
		return
	end
	local weapon = ItemService.equippedWeapon(player)
	local ability = Data.abilities[weapon.special_ability_id]
	if ability == nil or not Cooldowns.isReady(state.cooldowns, ability.id, now) then
		return
	end
	local cost = if ability.cost.resource == "spirit" then ability.cost.amount else 0
	if state.spirit < cost then
		notify(player, { kind = "no_spirit", need = cost })
		return
	end
	gainSpirit(player, state, -cost)
	Cooldowns.start(state.cooldowns, ability.id, now, ability.cooldown_s)
	notify(player, {
		kind = "cooldown",
		ability = ability.id,
		readyAt = Net.now() + ability.cooldown_s,
		duration = ability.cooldown_s,
	})
	local t = ability.timing
	state.busyUntil = now + t.windup_s + t.active_s + t.recovery_s
	cancelActions(state)
	local token = state.actionToken
	FxService.all({ k = "cast", p = player, ability = ability.id, windup = t.windup_s, active = t.active_s })
	task.delay(t.windup_s, function()
		if state.actionToken ~= token then
			-- Interrupted before release: give the spirit and the cooldown back.
			gainSpirit(player, state, cost)
			state.cooldowns[ability.id] = nil
			notify(player, { kind = "cooldown", ability = ability.id, readyAt = 0, duration = 0 })
			return
		end
		local _, r = body(player)
		if r == nil then
			return
		end
		for _, enemy in targetsInArea(ability.area, ability.range_studs, r.Position, r.CFrame.LookVector) do
			dealToEnemy(player, state, enemy, ability.power, ability.damage_type, 0, 0, ability.status_effects)
		end
	end)
end

local function dodge(player: Player, state: State)
	local now = os.clock()
	if now < state.stunnedUntil or state.menuOpen or body(player) == nil then
		return
	end
	if not Cooldowns.isReady(state.cooldowns, DODGE.id, now) then
		return
	end
	local window = C.dodge.chain_cooldown_s + DODGE.cooldown_s * C.dodge.chain_limit
	local recent = {}
	for _, t in state.dodgeTimes do
		if now - t < window then
			table.insert(recent, t)
		end
	end
	if #recent >= C.dodge.chain_limit then
		return
	end
	table.insert(recent, now)
	state.dodgeTimes = recent
	state.guarding = false
	cancelActions(state)
	local mode = CombatService.difficulty(player)
	state.iframesUntil = now + (DODGE.iframes_s or 0) * mode.dodge_window_mult
	state.dodgeStartedAt = now
	Cooldowns.start(state.cooldowns, DODGE.id, now, DODGE.cooldown_s)
	local movement = DODGE.movement
	state.busyUntil = now + (if movement then movement.duration_s else 0.2)
end

-- ------------------------------------------------------------------ being hit
export type IncomingHit = {
	attack: number,
	power: number,
	attackerLevel: number,
	damageType: string,
	poiseDamage: number,
	knockback: number,
	sourcePosition: Vector3,
	unblockable: boolean,
	statusEffects: { DataTypes.StatusApplication }?,
	onParried: (() -> ())?,
}

local function latencyAllowance(player: Player): number
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	return if ok and type(ping) == "number" then math.clamp(ping, 0, 0.15) else 0.05
end

local function applyStatusToPlayer(player: Player, state: State, app: DataTypes.StatusApplication, sourceAttack: number)
	local status = Data.statusEffects[app.status_id]
	if status == nil or rng:NextNumber() >= app.chance then
		return
	end
	local seconds = app.duration_s or status.duration_s
	local tickDamage = if status.tick_power then sourceAttack * status.tick_power else 0
	setEffect(player, state, status.id, seconds, status.stat_modifiers, tickDamage)
end

local function hurt(player: Player, state: State, humanoid: Humanoid, amount: number)
	humanoid.Health = math.max(0, humanoid.Health - amount)
	state.lastDamagedAt = os.clock()
	FxService.to(player, { k = "hurt", n = amount })
end

-- Called by EnemyService when an enemy attack lands on a player. Returns what happened:
-- "dodged", "parried", "guarded", "hit" or "none".
function CombatService.damagePlayer(player: Player, hit: IncomingHit): string
	local state = states[player]
	local humanoid, root = body(player)
	if state == nil or humanoid == nil or root == nil then
		return "none"
	end
	local now = os.clock()
	local mode = CombatService.difficulty(player)
	if now < state.iframesUntil then
		if now - state.dodgeStartedAt <= C.dodge.perfect_window_s * mode.dodge_window_mult then
			gainSpirit(player, state, C.spirit.gain_on_perfect_dodge)
			FxService.to(player, { k = "perfect" })
		end
		return "dodged"
	end

	local stats = CharacterService.stats(player)
	local toSource = flat(hit.sourcePosition - root.Position)
	local inFront = root.CFrame.LookVector:Dot(toSource) > -0.2
	local base: DamageMath.DamageInput = {
		attack = hit.attack,
		power = hit.power,
		defense = stats.defense,
		attackerLevel = hit.attackerLevel,
		targetLevel = stats.level,
		growthPerLevel = GROWTH,
		difficultyMult = mode.enemy_damage_mult,
		bonusMult = DamageMath.percentMultiplier(allModifiers(state), "damage_taken"),
	}

	if state.guarding and not hit.unblockable and inFront and GUARD.guard then
		local window = GUARD.guard.parry_window_s * mode.parry_window_mult + latencyAllowance(player)
		if now - state.guardStartedAt <= window then
			gainSpirit(player, state, C.spirit.gain_on_parry)
			local weapon = ItemService.equippedWeapon(player)
			local passive = Data.abilities[weapon.passive_ability_id]
			if
				passive
				and passive.passive
				and passive.passive.trigger == "on_parry"
				and now >= state.passiveReadyAt
			then
				state.passiveReadyAt = now + (passive.passive.internal_cooldown_s or 0)
				gainSpirit(player, state, passive.passive.spirit_gain or 0)
				setEffect(player, state, passive.id, passive.passive.duration_s or 5, passive.passive.effects, 0)
			end
			if hit.onParried then
				hit.onParried()
			end
			FxService.all({ k = "parry", p = player })
			return "parried"
		end
		base.guardReduction = GUARD.guard.damage_reduction
		local amount = DamageMath.compute(base, C.damage)
		hurt(player, state, humanoid, amount)
		state.guardMeter -= hit.poiseDamage
		if state.guardMeter <= 0 then
			state.guardMeter = C.guard.guard_meter_max
			staggerPlayer(player, state, C.guard.guard_break_stagger_s)
			FxService.to(player, { k = "guard_break" })
		else
			FxService.to(player, { k = "blocked" })
		end
		return "guarded"
	end

	local amount = DamageMath.compute(base, C.damage)
	hurt(player, state, humanoid, amount)
	gainSpirit(player, state, C.spirit.gain_on_hit_taken)
	if Stagger.hit(state.poise, hit.poiseDamage, now, C.poise) then
		staggerPlayer(player, state, C.poise.stagger_s)
	end
	if hit.knockback > 0 then
		local push = flat(root.Position - hit.sourcePosition)
		notify(player, {
			kind = "knockback",
			x = push.X,
			z = push.Z,
			studs = math.min(hit.knockback, C.readability.max_knockback_studs),
		})
	end
	local statuses: { DataTypes.StatusApplication } = hit.statusEffects or {}
	for _, app in statuses do
		applyStatusToPlayer(player, state, app, hit.attack)
	end
	return "hit"
end

-- Enemies may start an attack on this player only if this is true.
function CombatService.canBeAttacked(player: Player): boolean
	local state = states[player]
	return state ~= nil and not state.menuOpen and body(player) ~= nil
end

-- ------------------------------------------------------------------ upkeep
local function tick(dt: number)
	local now = os.clock()
	for player, state in states do
		local humanoid = body(player)
		if state.spirit < SPIRIT_MAX then
			gainSpirit(player, state, C.spirit.regen_per_s * dt)
		end
		if not state.guarding and state.guardMeter < C.guard.guard_meter_max then
			state.guardMeter =
				math.min(C.guard.guard_meter_max, state.guardMeter + C.guard.guard_meter_regen_per_s * dt)
		end
		for id, effect in state.effects do
			if now >= effect.untilT then
				clearEffect(player, state, id)
			elseif effect.tickDamage > 0 and now >= effect.nextTick and humanoid then
				effect.nextTick += 1
				local mode = CombatService.difficulty(player)
				hurt(player, state, humanoid, math.max(1, math.floor(effect.tickDamage * mode.enemy_damage_mult + 0.5)))
			end
		end
		if
			humanoid
			and humanoid.Health < humanoid.MaxHealth
			and now - state.lastDamagedAt >= C.recovery.out_of_combat_delay_s
		then
			humanoid.Health = math.min(
				humanoid.MaxHealth,
				humanoid.Health + humanoid.MaxHealth * C.recovery.regen_fraction_per_s * dt
			)
		end
	end
end

function CombatService.start()
	local remote = Net.event("Action")
	remote.OnServerEvent:Connect(function(player: Player, payload: any)
		local state = states[player]
		if state == nil or not RateLimiter.allow(state.limiter, os.clock()) then
			return
		end
		local action = Protocol.parseAction(payload)
		if action == nil then
			return
		end
		local name = action.a
		if name == "light" or name == "heavy" then
			tryMelee(player, state, name)
		elseif name == "special" then
			special(player, state)
		elseif name == "dodge" then
			dodge(player, state)
		elseif name == "guard_start" then
			if os.clock() >= state.stunnedUntil and not state.menuOpen then
				cancelActions(state)
				state.guarding = true
				state.guardStartedAt = os.clock()
			end
		elseif name == "guard_end" then
			state.guarding = false
		elseif name == "menu_open" then
			state.menuOpen = true
			state.guarding = false
			cancelActions(state)
		elseif name == "menu_close" then
			state.menuOpen = false
		elseif name == "assist_accept" then
			CombatService.assistRequested:Fire(player, action.kind)
		end
	end)

	local function reset(player: Player)
		local old = states[player]
		local state = newState()
		if old then
			for id in old.effects do
				player:SetAttribute("Effect_" .. id, nil)
			end
		end
		states[player] = state
		publishSpirit(player, state)
	end
	PlayerDataService.ready:Connect(reset)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			if states[player] then
				reset(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)

	task.spawn(function()
		while true do
			tick(task.wait(TICK_S))
		end
	end)
end

return CombatService
